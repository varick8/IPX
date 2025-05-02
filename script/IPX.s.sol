pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RoyaltyTokenFactory} from "../src/RoyaltyTokenFactory.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {IPX} from "../src/IPX.sol";

contract IPXScript is Script {
    function run() public {
        vm.startBroadcast();
        address mockUSDC = address(new MockUSDC());
        address royaltyTokenFactory = address(new RoyaltyTokenFactory(address(mockUSDC)));
        address ipX = address(new IPX(address(royaltyTokenFactory)));

        console.log("mockUSDC deployed to:", mockUSDC);
        console.log("royaltyTokenFactory deployed to:", royaltyTokenFactory);
        console.log("ipX deployed to:", ipX);

        vm.stopBroadcast();
    }
}
