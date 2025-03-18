// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QuiktisToken is ERC20, Ownable {
    constructor() ERC20("Quiktis Token", "QTK") Ownable(msg.sender) {
        // Mint the entire 1 billion supply to the deployer
        _mint(msg.sender, 1_000_000_000 * 10**18);
    }
    
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}