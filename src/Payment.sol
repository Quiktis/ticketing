// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IPayment} from "./interfaces/IPayment.sol";

/**
 * @title Payment
 * @dev Handles all payment processing for the ticketing system
 */
contract Payment is IPayment, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant TICKET_CONTRACT_ROLE = keccak256("TICKET_CONTRACT_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    uint256 private platformFee = 25; // 2.5%
    uint256 private constant FEE_DENOMINATOR = 1000;
    uint256 private constant MAX_FEE = 100; // 10%

    mapping(address => uint256) private pendingRefunds;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }

    // Modifiers
    modifier onlyTicketContract() {
        require(hasRole(TICKET_CONTRACT_ROLE, msg.sender), "Caller is not ticket contract");
        _;
    }

    modifier validFee(uint256 fee) {
        require(fee <= MAX_FEE, "Fee exceeds maximum allowed");
        _;
    }

    // Main payment functions
    function processPrimaryPurchase(address organizer, uint256 price)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        onlyTicketContract
        returns (bool)
    {
        require(msg.value >= price, "Insufficient payment");
        require(organizer != address(0), "Invalid organizer address");

        PaymentDetails memory details = _calculatePaymentDetails(price, PaymentType.PRIMARY);

        _processFee(details.fee);
        _transferAmount(organizer, details.amount);

        emit PaymentProcessed(msg.sender, organizer, details.amount, details.fee, PaymentType.PRIMARY);

        // Return excess payment if any
        if (msg.value > price) {
            _transferAmount(msg.sender, msg.value - price);
        }

        return true;
    }

    function processSecondaryPurchase(address seller, uint256 price)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        onlyTicketContract
        returns (bool)
    {
        require(msg.value >= price, "Insufficient payment");
        require(seller != address(0), "Invalid seller address");

        PaymentDetails memory details = _calculatePaymentDetails(price, PaymentType.SECONDARY);

        _processFee(details.fee);
        _transferAmount(seller, details.amount);

        emit PaymentProcessed(msg.sender, seller, details.amount, details.fee, PaymentType.SECONDARY);

        if (msg.value > price) {
            _transferAmount(msg.sender, msg.value - price);
        }

        return true;
    }

    function processRefund(address to, uint256 amount)
        external
        override
        nonReentrant
        onlyTicketContract
        returns (bool)
    {
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Invalid refund amount");

        pendingRefunds[to] += amount;

        emit RefundIssued(to, amount);
        return true;
    }

    // Admin functions
    function setPlatformFee(uint256 newFee) external override onlyRole(FEE_MANAGER_ROLE) validFee(newFee) {
        platformFee = newFee;
        emit FeeUpdated(newFee);
    }

    function withdrawFees() external override nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        _transferAmount(msg.sender, balance);
        emit FeeWithdrawn(msg.sender, balance);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // View functions
    function getPlatformFee() external view override returns (uint256) {
        return platformFee;
    }

    function getAccumulatedFees() external view override returns (uint256) {
        return address(this).balance;
    }

    function getPendingRefund(address user) external view returns (uint256) {
        return pendingRefunds[user];
    }

    // Internal functions
    function _calculatePaymentDetails(uint256 amount, PaymentType paymentType)
        internal
        view
        returns (PaymentDetails memory)
    {
        uint256 fee = (amount * platformFee) / FEE_DENOMINATOR;
        return PaymentDetails({amount: amount - fee, fee: fee, recipient: address(0), paymentType: paymentType});
    }

    function _processFee(uint256 fee) internal {
        // Fees are automatically accumulated in the contract
        require(address(this).balance >= fee, "Insufficient contract balance");
    }

    function _transferAmount(address to, uint256 amount) internal {
        (bool success,) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
    }

    // Fallback and receive functions
    receive() external payable {}
    fallback() external payable {}
}
