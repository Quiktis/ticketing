// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IPayment} from "./interfaces/IPayment.sol";
import {Counter} from "./libraries/Counter.sol";

/**
 * @author Anjitech
 * @title Ticket
 * @dev Handles all ticketing operations for the ticketing system
 */

contract Ticket is ERC721, ReentrancyGuard, AccessControl, Pausable {
    using Counter for Counter.CounterStorage;

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Roles
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    // Counters
    Counter.CounterStorage private _tokenIds;
    Counter.CounterStorage private _eventIds;

    // State variables
    IPayment public paymentContract;
    uint256 public constant MAX_TICKET_BATCH = 50;

    // Structs
    struct EventInfo {
        uint256 eventId;
        address organizer;
        string name;
        string description;
        string venue;
        uint256 startTime;
        uint256 endTime;
        uint256 basePrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        bool isSeated;
        bool allowResale;
        uint256 maxResalePrice;
        EventStatus status;
    }

    struct TicketInfo {
        uint256 tokenId;
        uint256 eventId;
        uint256 seatNumber;
        bool isUsed;
        uint256 purchasePrice;
        uint256 resalePrice;
        TicketStatus status;
    }
  
    // Enums
    enum EventStatus {
        DRAFT,
        PUBLISHED,
        CANCELLED,
        ENDED
    }
    enum TicketStatus {
        ACTIVE,
        LISTED,
        USED,
        REFUNDED
    }

    // Mappings
    mapping(uint256 => EventInfo) internal _events;
    mapping(uint256 => TicketInfo) internal _tickets;
    mapping(uint256 => mapping(uint256 => bool)) private _seatTaken;
    mapping(address => uint256[]) private _userTickets;

    // Events
    event EventCreated(uint256 indexed eventId, address indexed organizer, string name);
    event EventUpdated(uint256 indexed eventId);
    event EventCancelled(uint256 indexed eventId);
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address indexed buyer);
    event TicketListed(uint256 indexed tokenId, uint256 price);
    event TicketUnlisted(uint256 indexed tokenId);
    event TicketUsed(uint256 indexed tokenId, uint256 indexed eventId);
    event TicketRefunded(uint256 indexed tokenId, address indexed owner);

    constructor(address paymentContractAddress) ERC721("Event Ticket", "TCKT") {
        require(paymentContractAddress != address(0), "Invalid payment contract");
        paymentContract = IPayment(paymentContractAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createEvent(
        string memory name,
        string memory description,
        string memory venue,
        uint256 startTime,
        uint256 endTime,
        uint256 basePrice,
        uint256 maxTickets,
        bool isSeated,
        bool allowResale,
        uint256 maxResalePrice
    ) external onlyRole(ORGANIZER_ROLE) whenNotPaused returns (uint256) {
        require(startTime > block.timestamp, "Invalid start time");
        require(endTime > startTime, "Invalid end time");
        require(maxTickets > 0, "Invalid max tickets");
        require(basePrice > 0, "Invalid base price");

        _eventIds.increment();
        uint256 eventId = _eventIds.current();

        _events[eventId] = EventInfo({
            eventId: eventId,
            organizer: msg.sender,
            name: name,
            description: description,
            venue: venue,
            startTime: startTime,
            endTime: endTime,
            basePrice: basePrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            isSeated: isSeated,
            allowResale: allowResale,
            maxResalePrice: maxResalePrice,
            status: EventStatus.PUBLISHED
        });

        emit EventCreated(eventId, msg.sender, name);
        return eventId;
    }

    function mintTickets(uint256 eventId, address[] calldata to, uint256[] calldata seatNumbers)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256[] memory)
    {
        require(to.length > 0 && to.length <= MAX_TICKET_BATCH, "Invalid batch size");
        require(to.length == seatNumbers.length, "Arrays length mismatch");

        EventInfo storage event_ = _events[eventId];
        _validateEventForMinting(event_);

        uint256 totalCost = event_.basePrice * to.length;
        require(msg.value >= totalCost, "Insufficient payment");

        uint256[] memory tokenIds = new uint256[](to.length);

        for (uint256 i = 0; i < to.length; i++) {
            require(to[i] != address(0), "Invalid recipient");

            if (event_.isSeated) {
                require(!_seatTaken[eventId][seatNumbers[i]], "Seat taken");
                _seatTaken[eventId][seatNumbers[i]] = true;
            }

            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            tokenIds[i] = tokenId;

            _tickets[tokenId] = TicketInfo({
                tokenId: tokenId,
                eventId: eventId,
                seatNumber: seatNumbers[i],
                isUsed: false,
                purchasePrice: event_.basePrice,
                resalePrice: 0,
                status: TicketStatus.ACTIVE
            });

            _userTickets[to[i]].push(tokenId);
            _safeMint(to[i], tokenId);

            emit TicketMinted(tokenId, eventId, to[i]);
        }

        event_.ticketsSold += to.length;

        // Process payment
        bool success = paymentContract.processPrimaryPurchase{value: msg.value}(event_.organizer, totalCost);
        require(success, "Payment failed");

        return tokenIds;
    }

    function _validateEventForMinting(EventInfo storage event_) internal view {
        require(event_.status == EventStatus.PUBLISHED, "Event not active");
        require(block.timestamp < event_.endTime, "Event ended");
        require(event_.ticketsSold < event_.maxTickets, "Event sold out");
    }

    function listTicketForResale(uint256 tokenId, uint256 price) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not ticket owner");
        require(!_tickets[tokenId].isUsed, "Ticket used");

        EventInfo storage event_ = _events[_tickets[tokenId].eventId];
        require(event_.allowResale, "Resale not allowed");
        require(block.timestamp < event_.endTime, "Event ended");

        if (event_.maxResalePrice > 0) {
            require(price <= event_.maxResalePrice, "Price exceeds max");
        }

        _tickets[tokenId].resalePrice = price;
        _tickets[tokenId].status = TicketStatus.LISTED;

        emit TicketListed(tokenId, price);
    }

    function buyResaleTicket(uint256 tokenId) external payable nonReentrant whenNotPaused {
        TicketInfo storage ticket = _tickets[tokenId];
        require(ticket.status == TicketStatus.LISTED, "Ticket not for sale");
        require(msg.value >= ticket.resalePrice, "Insufficient payment");
        require(!ticket.isUsed, "Ticket used");

        EventInfo storage event_ = _events[ticket.eventId];
        require(block.timestamp < event_.endTime, "Event ended");

        address seller = ownerOf(tokenId);

        // Process payment
        bool success = paymentContract.processSecondaryPurchase{value: msg.value}(seller, ticket.resalePrice);
        require(success, "Payment failed");

        // Update ticket state
        ticket.resalePrice = 0;
        ticket.status = TicketStatus.ACTIVE;

        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);

        emit TicketUnlisted(tokenId);
    }

    function useTicket(uint256 tokenId) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not ticket owner");
        require(!_tickets[tokenId].isUsed, "Ticket already used");

        EventInfo storage event_ = _events[_tickets[tokenId].eventId];
        require(block.timestamp >= event_.startTime, "Event not started");
        require(block.timestamp <= event_.endTime, "Event ended");

        _tickets[tokenId].isUsed = true;
        _tickets[tokenId].status = TicketStatus.USED;

        emit TicketUsed(tokenId, _tickets[tokenId].eventId);
    }

    // View Functions
    function getUserTickets(address user) external view returns (uint256[] memory) {
        return _userTickets[user];
    }

    function getEventBasicInfo(uint256 eventId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            string memory venue,
            address organizer
        ) 
    {
        EventInfo storage event_ = _events[eventId];
        return (
            event_.name,
            event_.description,
            event_.venue,
            event_.organizer
        );
    }

    function getEventTimingAndCapacity(uint256 eventId)
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 basePrice,
            uint256 maxTickets,
            uint256 ticketsSold
        )
    {
        EventInfo storage event_ = _events[eventId];
        return (
            event_.startTime,
            event_.endTime,
            event_.basePrice,
            event_.maxTickets,
            event_.ticketsSold
        );
    }

    function getEventRules(uint256 eventId)
        external
        view
        returns (
            bool isSeated,
            bool allowResale,
            uint256 maxResalePrice,
            EventStatus status
        )
    {
        EventInfo storage event_ = _events[eventId];
        return (
            event_.isSeated,
            event_.allowResale,
            event_.maxResalePrice,
            event_.status
        );
    }

    function getTicketInfo(uint256 tokenId)
        external
        view
        returns (
            uint256 eventId,
            uint256 seatNumber,
            bool isUsed,
            uint256 purchasePrice,
            uint256 resalePrice,
            TicketStatus status
        )
    {
        TicketInfo storage ticket = _tickets[tokenId];
        return (
            ticket.eventId,
            ticket.seatNumber,
            ticket.isUsed,
            ticket.purchasePrice,
            ticket.resalePrice,
            ticket.status
        );
    }
}