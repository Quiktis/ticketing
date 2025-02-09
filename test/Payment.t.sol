// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Payment.sol";

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
    
    function setUp() public {
        vm.startPrank(admin);
        payment = new Payment();
        payment.grantRole(payment.TICKET_CONTRACT_ROLE(), ticketContract);
        vm.stopPrank();
        
        // Fund accounts
        vm.deal(buyer, 100 ether);
        vm.deal(ticketContract, 100 ether);
    }
    
    function testPrimaryPurchase() public {
        uint256 initialOrganizerBalance = organizer.balance;
        uint256 expectedFee = (PRICE * payment.getPlatformFee()) / 1000;
        uint256 expectedPayment = PRICE - expectedFee;
        
        vm.prank(ticketContract);
        bool success = payment.processPrimaryPurchase{value: PRICE}(
            organizer,
            PRICE
        );
        
        assertTrue(success);
        assertEq(
            organizer.balance - initialOrganizerBalance,
            expectedPayment
        );
        assertEq(
            address(payment).balance,
            expectedFee
        );
    }
    
    function testSecondaryPurchase() public {
        uint256 initialSellerBalance = organizer.balance;
        uint256 expectedFee = (PRICE * payment.getPlatformFee()) / 1000;
        uint256 expectedPayment = PRICE - expectedFee;
        
        vm.prank(ticketContract);
        bool success = payment.processSecondaryPurchase{value: PRICE}(
            organizer,
            PRICE
        );
        
        assertTrue(success);
        assertEq(
            organizer.balance - initialSellerBalance,
            expectedPayment
        );
        assertEq(
            address(payment).balance,
            expectedFee
        );
    }
    
    function testFeeWithdrawal() public {
        // First process a payment to accumulate some fees
        vm.prank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE}(
            organizer,
            PRICE
        );
        
        uint256 initialAdminBalance = admin.balance;
        uint256 contractBalance = address(payment).balance;
        
        vm.prank(admin);
        payment.withdrawFees();
        
        assertEq(
            admin.balance - initialAdminBalance,
            contractBalance
        );
        assertEq(address(payment).balance, 0);
    }
    
    function testSetPlatformFee() public {
        uint256 newFee = 30; // 3%
        
        vm.prank(admin);
        payment.setPlatformFee(newFee);
        
        assertEq(payment.getPlatformFee(), newFee);
    }
    
    function testFailSetPlatformFeeTooHigh() public {
        uint256 newFee = 101; // 10.1%
        
        vm.prank(admin);
        payment.setPlatformFee(newFee);
    }
    
    function testRefundProcess() public {
        uint256 refundAmount = 0.5 ether;
        
        vm.prank(ticketContract);
        bool success = payment.processRefund(buyer, refundAmount);
        
        assertTrue(success);
        assertEq(payment.getPendingRefund(buyer), refundAmount);
    }
    
    function testPauseUnpause() public {
        vm.startPrank(admin);
        
        payment.pause();
        assertTrue(payment.paused());
        
        // Try to process payment while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(ticketContract);
        payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
        
        // Unpause and verify payment works
        payment.unpause();
        assertFalse(payment.paused());
        
        vm.prank(ticketContract);
        bool success = payment.processPrimaryPurchase{value: PRICE}(
            organizer,
            PRICE
        );
        assertTrue(success);
        
        vm.stopPrank();
    }
    
    function testAccessControl() public {
        // Test non-admin trying to withdraw fees
        vm.prank(buyer);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000000004 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        payment.withdrawFees();
        
        // Test non-ticket-contract trying to process payment
        vm.prank(buyer);
        vm.expectRevert("Caller is not ticket contract");
        payment.processPrimaryPurchase{value: PRICE}(organizer, PRICE);
    }
}