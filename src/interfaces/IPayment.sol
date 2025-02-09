// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPayment {
    // Structs
    struct PaymentDetails {
        uint256 amount;
        uint256 fee;
        address recipient;
        PaymentType paymentType;
    }

    // Enums
    enum PaymentType { PRIMARY, SECONDARY, REFUND }

    // Events
    event PaymentProcessed(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee,
        PaymentType paymentType
    );
    event FeeUpdated(uint256 newFee);
    event FeeWithdrawn(address indexed admin, uint256 amount);
    event RefundIssued(address indexed to, uint256 amount);

    // Main functions
    function processPrimaryPurchase(address organizer, uint256 price) external payable returns (bool);
    function processSecondaryPurchase(address seller, uint256 price) external payable returns (bool);
    function processRefund(address to, uint256 amount) external returns (bool);
    
    // Admin functions
    function setPlatformFee(uint256 newFee) external;
    function withdrawFees() external;
    
    // View functions
    function getPlatformFee() external view returns (uint256);
    function getAccumulatedFees() external view returns (uint256);
}