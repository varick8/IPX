// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";
// import {IPX} from "../src/IPX.sol";
// import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// contract IPXTest is Test, IERC721Receiver {
//     IPX public ipX;

//     function setUp() public {
//         ipX = new IPX();
//     }

//     function test_registerIP() public {
//         ipX.registerIP("test", "test", "test");
//         assertEq(ipX.nextTokenId(), 1);
//     }

//     function test_rentIP() public {
//         deal(address(this), 1000 ether);
//         ipX.registerIP("test", "test", "test");
//         ipX.rentIP{value: 1000}(1);
//         (uint256 expiredAt) = ipX.rents(1, address(this));
//         assertEq(expiredAt, block.timestamp + 30 days);
//     }

//     function test_buyIP() public {
//         deal(address(this), 1000 ether);
//         ipX.registerIP("test", "test", "test");
//         ipX.buyIP{value: 1000}(1);
//         assertEq(ipX.ownerOf(1), address(this));
//     }

//     function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
//         return this.onERC721Received.selector;
//     }
// }