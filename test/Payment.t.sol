// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Payment} from "../src/Payment.sol";
import {IPayment} from "../src/interfaces/IPayment.sol";

contract PaymentTest is Test {
    Payment public payment;
    
    address public admin = address(1);
    address public ticketContract = address(2);
    address public organizer = address(3);
    address public buyer = address(4);
    
    uint256 public constant PRICE = 1 ether;
    
    event PaymentProcessed(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee,
        IPayment.PaymentType paymentType
    );
    event FeeUpdated(uint256 newFee);
    event FeeWithdrawn(address indexed admin, uint256 amount);
    event RefundIssued(address indexed to, uint256 amount);
    
    function setUp() public {
        vm.startPrank(admin);
        payment = new Payment();
        payment.grantRole(payment.TICKET_CONTRACT_ROLE(), ticketContract);
        vm.stopPrank();
        
        // Fund accounts
        vm.deal(ticketContract, 100 ether);
        vm.deal(buyer, 100 ether);
    }
    
    function testSetup() public view {
        assertTrue(payment.hasRole(payment.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(payment.hasRole(payment.TICKET_CONTRACT_ROLE(), ticketContract));
        assertEq(payment.getPlatformFee(), 25); // 2.5%
    }
    
    function testPrimaryPurchase() public {
        uint256 initialOrgBalance = organizer.balance;
        uint256 initialContractBalance = address(payment).balance;
        uint256 amount = PRICE;
        uint256 fee = (amount * payment.getPlatformFee()) / 1000;
        uint256 expectedPayment = amount - fee;
        
        vm.prank(ticketContract);
        bool success = payment.processPrimaryPurchase{value: amount}(organizer, amount);
        
        assertTrue(success);
        assertEq(organizer.balance - initialOrgBalance, expectedPayment);
        assertEq(address(payment).balance - initialContractBalance, fee);
    }
    
    function testSecondaryPurchase() public {
        uint256 initialSellerBalance = address(5).balance;
        uint256 initialContractBalance = address(payment).balance;
        uint256 amount = PRICE;
        uint256 fee = (amount * payment.getPlatformFee()) / 1000;
        uint256 expectedPayment = amount - fee;
        
        vm.prank(ticketContract);
        bool success = payment.processSecondaryPurchase{value: amount}(address(5), amount);
        
        assertTrue(success);
        assertEq(address(5).balance - initialSellerBalance, expectedPayment);
        assertEq(address(payment).balance - initialContractBalance, fee);
    }
    
    function testRefundProcess() public {
        uint256 refundAmount = 0.5 ether;
        
        vm.prank(ticketContract);
        bool success = payment.processRefund(buyer, refundAmount);
        
        assertTrue(success);
        assertEq(payment.getPendingRefund(buyer), refundAmount);
    }
    
    function testWithdrawFees() public {
        // First process a payment to accumulate fees
        vm.startPrank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
        vm.stopPrank();
        
        uint256 initialAdminBalance = admin.balance;
        uint256 contractBalance = address(payment).balance;
        
        vm.prank(admin);
        payment.withdrawFees();
        
        assertEq(admin.balance - initialAdminBalance, contractBalance);
        assertEq(address(payment).balance, 0);
    }
    
    function testSetPlatformFee() public {
        uint256 newFee = 30; // 3%
        
        vm.prank(admin);
        payment.setPlatformFee(newFee);
        
        assertEq(payment.getPlatformFee(), newFee);
    }
    
    function test_RevertWhen_SettingFeeTooHigh() public {
        uint256 newFee = 101; // 10.1%
        
        vm.expectRevert("Fee exceeds maximum allowed");
        vm.prank(admin);
        payment.setPlatformFee(newFee);
    }
    
    function testPauseUnpause() public {
    // Pause contract
    vm.prank(admin);
    payment.pause();
    assertTrue(payment.paused());
    
    // Try to process payment while paused
    vm.expectRevert();  // Just expect any revert without specifying the message
    vm.prank(ticketContract);
    payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
    
    // Unpause and verify payment works
    vm.prank(admin);
    payment.unpause();
    assertFalse(payment.paused());
    
    vm.prank(ticketContract);
    bool success = payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
    assertTrue(success);
}
    function test_RevertWhen_UnauthorizedWithdraw() public {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", buyer, 0x0000000000000000000000000000000000000000000000000000000000000000));
        vm.prank(buyer);
        payment.withdrawFees();
    }
    
    function test_RevertWhen_UnauthorizedSetFee() public {
        bytes32 roleHash = payment.FEE_MANAGER_ROLE();
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", buyer, roleHash));
        vm.prank(buyer);
        payment.setPlatformFee(30);
    }
    
    function test_RevertWhen_UnauthorizedPurchaseProcess() public {
        vm.expectRevert("Caller is not ticket contract");
        vm.prank(buyer);
        payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
    }
    
    function test_RevertWhen_PaymentIsInsufficient() public {
        vm.expectRevert("Insufficient payment");
        vm.prank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE - 0.1 ether}(organizer, PRICE);
    }
    
    function test_RevertWhen_OrganizerIsInvalid() public {
        vm.expectRevert("Invalid organizer address");
        vm.prank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE}(address(0), PRICE);
    }
    
    function testExcessPaymentRefund() public {
        uint256 excess = 0.5 ether;
        uint256 initialTicketContractBalance = ticketContract.balance;
        
        vm.prank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE + excess}(organizer, PRICE);
        
        // The ticketContract balance should decrease by PRICE + excess
        // But the excess is returned, so effectively it only decreases by PRICE
        assertEq(
            ticketContract.balance,
            initialTicketContractBalance - PRICE
        );
    }
}