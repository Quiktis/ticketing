// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Ticket is ERC721 {
    address public eventOrganizer;
    uint256 public ticketIdCounter;

    constructor() ERC721("EventTicket", "ETKT") {
        eventOrganizer = msg.sender;
        ticketIdCounter = 1; // Start ticket IDs from 1 for convenience
    }

    // Modifier to ensure only the event organizer can call certain functions
    modifier onlyOrganizer() {
        require(msg.sender == eventOrganizer, "Not authorized");
        _;
    }

    // Mint a new ticket
    function mintTicket(address to) external onlyOrganizer {
        _safeMint(to, ticketIdCounter);
        ticketIdCounter++;
    }

    // Verify if an address holds a valid ticket
    function isValidTicket(address holder) external view returns (bool) {
        return balanceOf(holder) > 0;
    }

    // Optional resale with capped pricing (could be added as needed)
    function transferTicket(address from, address to, uint256 tokenId) external {
        require(ownerOf(tokenId) == from, "Not ticket owner");
        safeTransferFrom(from, to, tokenId);
    }
}
