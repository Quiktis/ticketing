// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/QuiktisToken.sol";

contract DeployToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy token
        QuiktisToken token = new QuiktisToken();
        
        // Log the token address
        console.log("QTK Token deployed to:", address(token));
        
        vm.stopBroadcast();
    }
}