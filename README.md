# Quiktis - Decentralized Event Ticketing System

## Overview

Quiktis is a decentralized event ticketing system built on Ethereum that enables secure, transparent, and efficient management of event tickets using blockchain technology. The system implements NFT-based tickets with support for both primary sales and a controlled secondary market.

## Key Features

- NFT-based ticket implementation (ERC721)
- Primary market ticket sales
- Controlled secondary market with configurable resale rules
- Event management system
- Role-based access control
- Flexible payment processing
- Seat management capabilities
- Usage tracking
- Pausable functionality for emergency situations

## Smart Contracts

### Core Contracts

1. **Ticket.sol**
   - Handles ticket NFT minting and management
   - Implements event creation and management
   - Controls ticket transfers and resales
   - Manages seat allocation
   - Tracks ticket usage

2. **Payment.sol**
   - Processes all payment operations
   - Handles fee calculations and distributions
   - Manages platform fees
   - Supports refund processing

### Interfaces

- **IPayment.sol**: Defines the payment processing interface

## Technical Details

### Roles

- `DEFAULT_ADMIN_ROLE`: Can manage other roles and emergency functions
- `ORGANIZER_ROLE`: Can create and manage events
- `VALIDATOR_ROLE`: Can validate tickets
- `TICKET_CONTRACT_ROLE`: Authorized to process payments
- `FEE_MANAGER_ROLE`: Can update platform fees

### Structs

#### Event Information
```solidity
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
```

#### Ticket Information
```solidity
struct TicketInfo {
    uint256 tokenId;
    uint256 eventId;
    uint256 seatNumber;
    bool isUsed;
    uint256 purchasePrice;
    uint256 resalePrice;
    TicketStatus status;
}
```

### Key Functions

#### Event Management
- `createEvent`: Create a new event with configurable parameters
- `_validateEventForMinting`: Validate event status for ticket minting

#### Ticket Operations
- `mintTickets`: Mint new tickets for an event
- `listTicketForResale`: List a ticket on the secondary market
- `buyResaleTicket`: Purchase a ticket from the secondary market
- `useTicket`: Mark a ticket as used

#### Payment Processing
- `processPrimaryPurchase`: Handle primary market sales
- `processSecondaryPurchase`: Handle secondary market sales
- `processRefund`: Process ticket refunds

## Security Features

1. **Access Control**
   - Role-based access management
   - Function-level permission checks

2. **Reentrancy Protection**
   - ReentrancyGuard implementation
   - Secure payment handling

3. **Pausable Functionality**
   - Emergency pause capability
   - Controlled by admin role

4. **Price Controls**
   - Maximum resale price limits
   - Platform fee controls

## Testing

Comprehensive test suite covering:
- Event creation and management
- Ticket minting and transfers
- Payment processing
- Access control
- Error cases
- Secondary market functionality

To run tests:
```bash
forge test -vvv
```

## Development Setup

### Prerequisites
- Foundry
- Solidity ^0.8.24
- OpenZeppelin Contracts

### Installation
1. Clone the repository
```bash
git clone <repository-url>
```

2. Install dependencies
```bash
forge install
```

3. Compile contracts
```bash
forge build
```

### Deployment
1. Set up environment variables
```bash
cp .env.example .env
# Add your private key and RPC URL
```

2. Deploy contracts
```bash
forge script script/DeployQuiktis.s.sol --rpc-url <your-rpc-url> --broadcast
```

## Architecture

### Contract Interactions
```
┌────────────┐     ┌────────────┐
│   Ticket   │◄────┤   Payment  │
└────────────┘     └────────────┘
       ▲                  ▲
       │                  │
       │         ┌────────────┐
       └─────────┤ Interfaces │
                 └────────────┘
```

## License

MIT