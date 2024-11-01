// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Ticket.sol";  // Adjust the path as necessary
import "../test/MockERC721Receiver.t.sol";  // Adjust the path as necessary



contract TicketTest is Test {
    Ticket ticket;
    MockERC721Receiver receiver;
    address organizer = address(this);
    address attendee = address(0x1234);

    function setUp() public {
        ticket = new Ticket();
        receiver = new MockERC721Receiver();  // Deploy the mock receiver
    }

    function testTransferTicketToReceiver() public {
        ticket.mintTicket(organizer);
        ticket.transferTicket(organizer, address(receiver), 1);  // Transfer to mock receiver
        assertEq(ticket.ownerOf(1), address(receiver));
    }



    function testMinting() public {
        // Organizer mints a ticket to an attendee
        ticket.mintTicket(attendee);
        assertEq(ticket.balanceOf(attendee), 1);
    }

    function testMintingOnlyByOrganizer() public {
        // Attempt to mint from non-organizer address
        vm.prank(attendee);
        vm.expectRevert("Not authorized");
        ticket.mintTicket(attendee);
    }
        function testIsValidTicket() public {
        ticket.mintTicket(attendee);
        assertTrue(ticket.isValidTicket(attendee));
    }

    function testInvalidTicket() public view {
        assertFalse(ticket.isValidTicket(attendee));
    }

    function testTransferTicket() public {
        ticket.mintTicket(organizer);
        ticket.transferTicket(organizer, attendee, 1);
        assertEq(ticket.ownerOf(1), attendee);
    }

    function testTransferOnlyByOwner() public {
        ticket.mintTicket(organizer);

        // Attempt transfer from non-owner address
        vm.prank(attendee);
        vm.expectRevert("Not ticket owner");
        ticket.transferTicket(organizer, attendee, 1);
    }
}

