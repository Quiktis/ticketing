// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MockERC721Receiver
 * @dev Implementation of the {IERC721Receiver} interface for testing.
 * This mock can be configured to either accept or reject NFT transfers.
 */
contract MockERC721Receiver is IERC721Receiver {
    bool private _acceptTokens;
    event TokenReceived(address operator, address from, uint256 tokenId, bytes data);

    constructor(bool acceptTokens) {
        _acceptTokens = acceptTokens;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Emit event for testing purposes
        emit TokenReceived(operator, from, tokenId, data);

        if (_acceptTokens) {
            return IERC721Receiver.onERC721Received.selector;
        }
        return 0x00000000;
    }

    // Function to change acceptance status - useful for testing different scenarios
    function setAcceptTokens(bool acceptTokens) external {
        _acceptTokens = acceptTokens;
    }

    // View function to check current acceptance status
    function acceptsTokens() external view returns (bool) {
        return _acceptTokens;
    }
}