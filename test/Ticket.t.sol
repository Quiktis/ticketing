// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ticket} from "../src/Ticket.sol";
import {Payment} from "../src/Payment.sol";
import {MockERC721Receiver} from "./MockERC721Receiver.sol";

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

    function testCreateEvent() public {
        vm.startPrank(organizer);

        string memory eventName = "Test Event";
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 7 days;

        vm.expectEmit(true, true, false, true);
        emit EventCreated(1, organizer, eventName);

        uint256 eventId = ticket.createEvent(
            eventName,
            "Test Description",
            "Test Venue",
            startTime,
            endTime,
            TICKET_PRICE,
            100, // maxTickets
            true, // isSeated
            true, // allowResale
            2 ether // maxResalePrice
        );

        assertEq(eventId, 1);

        // Get event info
        (
            string memory name,
            string memory description,
            string memory venue,
            address org
        ) = ticket.getEventBasicInfo(eventId);

        (
            uint256 startTime_,
            uint256 endTime_,
            uint256 basePrice,
            uint256 maxTickets,
            uint256 ticketsSold
        ) = ticket.getEventTimingAndCapacity(eventId);

        (
            bool isSeated,
            bool allowResale,
            uint256 maxResalePrice,
            Ticket.EventStatus status
        ) = ticket.getEventRules(eventId);

        assertEq(name, eventName);
        assertEq(org, organizer);
        assertEq(basePrice, TICKET_PRICE);
        assertEq(uint256(status), uint256(Ticket.EventStatus.PUBLISHED));

        vm.stopPrank();
    }

    function testCreateEventValidation() public {
        vm.startPrank(organizer);

        // Test invalid start time
        vm.expectRevert("Invalid start time");
        ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp - 1, // Past time
            block.timestamp + 7 days,
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );

        // Test invalid end time
        vm.expectRevert("Invalid end time");
        ticket.createEvent(
            "Test Event",
            "Test Description",
            "Test Venue",
            block.timestamp + 7 days,
            block.timestamp + 1 days, // End before start
            TICKET_PRICE,
            100,
            true,
            true,
            2 ether
        );

        vm.stopPrank();
    }

    function testMintTickets() public {
        // First create an event
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

        // Prepare batch minting data
        address[] memory recipients = new address[](2);
        recipients[0] = buyer;
        recipients[1] = buyer2;

        uint256[] memory seatNumbers = new uint256[](2);
        seatNumbers[0] = 1;
        seatNumbers[1] = 2;

        // Mint tickets
        vm.prank(buyer);
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE * 2}(eventId, recipients, seatNumbers);

        // Verify minting results
        assertEq(tokenIds.length, 2);
        assertEq(ticket.ownerOf(tokenIds[0]), buyer);
        assertEq(ticket.ownerOf(tokenIds[1]), buyer2);

        // Check ticket details
        (
            uint256 eventId_,
            uint256 seatNumber,
            bool isUsed,
            uint256 purchasePrice,
            uint256 resalePrice,
            Ticket.TicketStatus status
        ) = ticket.getTicketInfo(tokenIds[0]);

        assertEq(eventId_, eventId);
        assertEq(seatNumber, 1);
        assertEq(purchasePrice, TICKET_PRICE);
        assertEq(uint256(status), uint256(Ticket.TicketStatus.ACTIVE));
    }

    function testTicketResale() public {
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
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(eventId, recipients, seatNumbers);
        uint256 tokenId = tokenIds[0];

        // List ticket for resale
        uint256 resalePrice = TICKET_PRICE * 2;
        vm.prank(buyer);
        ticket.listTicketForResale(tokenId, resalePrice);

        // Verify listed ticket
        (
            ,
            ,
            ,
            ,
            uint256 resalePrice_,
            Ticket.TicketStatus status
        ) = ticket.getTicketInfo(tokenId);

        assertEq(resalePrice_, resalePrice);
        assertEq(uint256(status), uint256(Ticket.TicketStatus.LISTED));

        // Buy resale ticket
        vm.prank(buyer2);
        ticket.buyResaleTicket{value: resalePrice}(tokenId);

        assertEq(ticket.ownerOf(tokenId), buyer2);

        // Verify bought ticket
        (
            ,
            ,
            ,
            ,
            resalePrice_,
            status
        ) = ticket.getTicketInfo(tokenId);

        assertEq(resalePrice_, 0);
        assertEq(uint256(status), uint256(Ticket.TicketStatus.ACTIVE));
    }

    function testUseTicket() public {
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
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(eventId, recipients, seatNumbers);

        // Fast forward to event time
        vm.warp(block.timestamp + 2 days);

        // Use ticket
        vm.prank(buyer);
        ticket.useTicket(tokenIds[0]);

        // Verify used ticket
        (
            ,
            ,
            bool isUsed,
            ,
            ,
            Ticket.TicketStatus status
        ) = ticket.getTicketInfo(tokenIds[0]);

        assertTrue(isUsed);
        assertEq(uint256(status), uint256(Ticket.TicketStatus.USED));
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
        uint256[] memory tokenIds = ticket.mintTickets{value: TICKET_PRICE}(eventId, recipients, seatNumbers);
        uint256 tokenId = tokenIds[0];

        // Verify initial ownership
        assertEq(ticket.ownerOf(tokenId), buyer);

        // Test transfer to receiver contract
        vm.prank(buyer);
        ticket.safeTransferFrom(buyer, address(receiver), tokenId);

        // Verify transfer succeeded
        assertEq(ticket.ownerOf(tokenId), address(receiver));

        // Verify ticket data is maintained
        (
            uint256 eventId_,
            uint256 seatNumber,
            ,
            ,
            ,
            Ticket.TicketStatus status
        ) = ticket.getTicketInfo(tokenId);

        assertEq(eventId_, eventId);
        assertEq(seatNumber, 1);
        assertEq(uint256(status), uint256(Ticket.TicketStatus.ACTIVE));
    }
}