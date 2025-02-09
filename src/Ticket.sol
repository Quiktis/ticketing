// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from  "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReetrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from  "@openzeppelin/contracts/utils/Pausable.sol";
import {IPayment} from "./interfaces/IPayment.sol";

/**
 * @title Ticket
 * @dev NFT-based ticketing system with primary and secondary market functionality
 */
contract Ticket is ERC721, ReentrancyGuard, AccessControl, Pausable {
    using Counters for Counters.Counter;
    
    // Roles
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    // Counters
    Counters.Counter private _tokenIds;
    Counters.Counter private _eventIds;
    
    // State variables
    IPayment public paymentContract;
    uint256 public constant MAX_TICKET_BATCH = 50;
    
    // Structs
    struct Event {
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
    
    struct Ticket {
        uint256 tokenId;
        uint256 eventId;
        uint256 seatNumber;
        bool isUsed;
        uint256 purchasePrice;
        uint256 resalePrice;
        TicketStatus status;
    }
    
    // Enums
    enum EventStatus { DRAFT, PUBLISHED, CANCELLED, ENDED }
    enum TicketStatus { ACTIVE, LISTED, USED, REFUNDED }
    
    // Mappings
    mapping(uint256 => Event) public events;
    mapping(uint256 => Ticket) public tickets;
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
    
    // Event Management Functions
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
        
        events[eventId] = Event({
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
    
    function mintTickets(
        uint256 eventId,
        address[] calldata to,
        uint256[] calldata seatNumbers
    ) external payable nonReentrant whenNotPaused returns (uint256[] memory) {
        require(to.length > 0 && to.length <= MAX_TICKET_BATCH, "Invalid batch size");
        require(to.length == seatNumbers.length, "Arrays length mismatch");
        
        Event storage event_ = events[eventId];
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
            
            tickets[tokenId] = Ticket({
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
        
        event_.ticketsSold += to.