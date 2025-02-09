// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Ticket} from "../src/Ticket.sol";
import {Payment} from "../src/Payment.sol";

contract DeployQuiktis is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Payment contract first
        Payment payment = new Payment();

        // Deploy Ticket contract with Payment contract address
        Ticket ticket = new Ticket(address(payment));

        // Grant TICKET_CONTRACT_ROLE to the Ticket contract
        payment.grantRole(payment.TICKET_CONTRACT_ROLE(), address(ticket));

        vm.stopBroadcast();

        console.log("Deployment successful!");
        console.log("Payment contract deployed at:", address(payment));
        console.log("Ticket contract deployed at:", address(ticket));
    }
}
