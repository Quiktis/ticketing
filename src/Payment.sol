// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Payment {
    address payable public organizer;
    uint256 public ticketPrice;

    event TicketPurchased(address indexed buyer, uint256 amount);

    constructor(address payable _organizer, uint256 _ticketPrice) {
        organizer = _organizer;
        ticketPrice = _ticketPrice;
    }

    function buyTicket() external payable {
        require(msg.value == ticketPrice, "Incorrect amount sent");

        (bool success, ) = organizer.call{value: msg.value}("");
        require(success, "Payment failed");

        emit TicketPurchased(msg.sender, msg.value);
    }
}
