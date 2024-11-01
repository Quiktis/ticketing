// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Ticket.sol";
import "../src/Payment.sol";

contract DeployQuiktis is Script {
    function run() external {
        vm.startBroadcast();
        
        new Ticket();
        new Payment(payable(msg.sender), 0.1 ether);

        vm.stopBroadcast();
    }
}
