// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ticket} from  "../src/Ticket.sol";
import {Payment} from "../src/Payment.sol";
import {MockERC721Receiver} from "../test/MockERC721Receiver.sol";

contract TicketTest is Test {
    Ticket public ticket;
    Payment public payment;
    
    address public admin = address(1);
    address public organizer = address(2);
    address public buyer = address(3);
    address public buyer2 = address(4);
    
    uint256 public constant TICKET_PRICE = 1 ether;
    
    event EventCreated(uint256 indexed eventId, address indexed organizer, string name);
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address indexed buyer);
    event TicketListed(uint256 indexed tokenId, uint256 price);

    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        payment = new Payment();
        ticket = new Ticket(address(payment));
        
        // Setup roles
        payment.grantRole(payment.TICKET_CONTRACT_ROLE(), address(ticket));
        ticket.grantRole(ticket.ORGANIZER_ROLE(), organizer);
        vm.stopPrank();
        
        // Fund accounts
        vm.deal(buyer, 100 ether);
        vm.deal(buyer2, 100 ether);
        vm.deal(organizer, 1 ether);
    }

    // ... [Previous test functions remain the same] ...

    function testSafeTransfer() public {
        // Deploy mock receiver that accepts tokens
        MockERC721Receiver receiver = new MockERC721Receiver(true);
        
        // Create event
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        // Mint ticket
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        uint256 tokenId = tokenIds[0];
        
        // Test transfer to contract
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId);
        
        // Verify transfer
        assertEq(ticket.ownerOf(tokenId), address(receiver));
    }

    function testFailTransferToNonReceiver() public {
        // Deploy mock receiver that rejects tokens
        MockERC721Receiver receiver = new MockERC721Receiver(false);
        
        // Create event
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        // Mint ticket
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        uint256 tokenId = tokenIds[0];
        
        // This should fail
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId);
    }

    function testSafeTransfer() public {
        // Deploy mock receiver that accepts tokens
        MockERC721Receiver receiver = new MockERC721Receiver(true);
        
        // Create event first
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        // Mint ticket to buyer
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        uint256 tokenId = tokenIds[0];
        
        // Verify initial ownership
        assertEq(ticket.ownerOf(tokenId), buyer);
        
        // Test transfer to receiver contract
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId);
        
        // Verify transfer succeeded
        assertEq(ticket.ownerOf(tokenId), address(receiver));
        
        // Verify ticket data is maintained
        Ticket.Ticket memory ticketData = ticket.tickets(tokenId);
        assertEq(ticketData.eventId, eventId);
        assertEq(ticketData.seatNumber, 1);
        assertEq(uint256(ticketData.status), uint256(Ticket.TicketStatus.ACTIVE));
    }

    function testFailTransferToNonReceiver() public {
        // Deploy mock receiver that rejects tokens
        MockERC721Receiver receiver = new MockERC721Receiver(false);
        
        // Create event first
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        // Mint ticket to buyer
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        uint256 tokenId = tokenIds[0];
        
        // Verify initial ownership
        assertEq(ticket.ownerOf(tokenId), buyer);
        
        // This should fail because receiver rejects tokens
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId);
    }

    function testSafeTransferData() public {
        // Deploy mock receiver that accepts tokens
        MockERC721Receiver receiver = new MockERC721Receiver(true);
        
        // Create event first
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        // Mint ticket to buyer
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        uint256 tokenId = tokenIds[0];
        
        // Test transfer with additional data
        bytes memory data = abi.encode("Additional transfer data");
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId, data);
        
        // Verify transfer succeeded
        assertEq(ticket.ownerOf(tokenId), address(receiver));
    }

    function testFailTransferFromUnauthorized() public {
        // Deploy mock receiver
        MockERC721Receiver receiver = new MockERC721Receiver(true);
        
        // Create event and mint ticket
        vm.prank(organizer);
        uint256 eventId = ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );
        
        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory seatNumbers = new uint256[](1);
        seatNumbers[0] = 1;
        
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(
            eventId,
            recipients,
            seatNumbers
        );
        
        // Attempt unauthorized transfer (from buyer2 who doesn't own the ticket)
        vm.prank(buyer2);
        ticket.safeTransferFrom(buyer, address(receiver), tokenIds[0]);
    }
}