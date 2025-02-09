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

    constructor(bool acceptTokens) {
        _acceptTokens = acceptTokens;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function setAcceptTokens(bool acceptTokens) external {
        _acceptTokens = acceptTokens;
    }

    function acceptsTokens() external view returns (bool) {
        return _acceptTokens;
    }
}