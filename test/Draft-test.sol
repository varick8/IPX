// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IPX} from "../src/Draft-IPX.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract IPXTest is Test, IERC721Receiver {
    IPX public ipX;

    function setUp() public {
        ipX = new IPX();
    }

    // tambahin biar bisa simulai payable
    receive() external payable {}

    function test_registerIP() public {
        address owner = address(this);

        uint256 tokenId1 = ipX.registerIP("Title", "Description", 1, "Tag", "ipfs://hash", 1, 1, 10);

        uint256 tokenId2 =
            ipX.registerIP("Title again", "Description again", 2, "Tag again", "ipfs://hash again", 2, 2, 20);

        assertEq(ipX.ownerOf(tokenId1), owner);
        IPX.IP memory ip = ipX.getIP(tokenId1);

        IPX.IP memory otherip = ipX.getIP(tokenId2);

        // all equals
        assertEq(ip.owner, owner);
        assertEq(ip.title, "Title");
        assertEq(ip.description, "Description");
        assertEq(ip.category, 1);
        assertEq(ip.tag, "Tag");
        assertEq(ip.fileUpload, "ipfs://hash");
        assertEq(ip.licenseopt, 1);
        assertEq(ip.basePrice, 1);
        assertEq(ip.royaltyPercentage, 10);

        // all not equals
        assertNotEq(otherip.title, "Title");
        assertNotEq(otherip.description, "Description");
        assertNotEq(otherip.category, 1);
        assertNotEq(otherip.tag, "Tag");
        assertNotEq(otherip.fileUpload, "ipfs://hash");
        assertNotEq(otherip.licenseopt, 1);
        assertNotEq(otherip.basePrice, 1 ether);
        assertNotEq(otherip.royaltyPercentage, 10);
    }

    function test_buyIP() public {
        address owner = address(this);
        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 5);

        // masih punya yang lama
        assertEq(ipX.ownerOf(tokenId), owner);

        address buyer = vm.addr(1);
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        ipX.buyIP{value: 2 ether}(tokenId);

        // pindah kepemilikan
        assertEq(ipX.ownerOf(tokenId), buyer);
    }

    function test_buyOwnIP() public {
        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 10 ether, 5);

        vm.expectRevert("Cannot buy your own IP");
        ipX.buyIP{value: 10 ether}(tokenId);
    }

    function test_getIPsNotOwnedBy() public {
        address owner = address(this);

        uint256 tokenId1 = ipX.registerIP("IP1", "Desc1", 1, "Tag1", "ipfs://1", 1, 1 ether, 10);
        uint256 tokenId2 = ipX.registerIP("IP2", "Desc2", 1, "Tag2", "ipfs://2", 1, 1 ether, 10);

        address otherUser = vm.addr(2);
        vm.startPrank(otherUser);
        uint256 tokenId3 = ipx.registerIP("IP3", "Desc3", 1, "Tag3", "ipfs://3", 1, 1 ether, 10);
        vm.stopPrank();

        IPX.IP[] memory ips = ipX.getIPsNotOwnedBy(owner);

        assertEq(ips.length, 1);
        assertEq(ips[0].title, "IP3");
    }

    function test_getListRentFromMyIPs() public {
        address owner = address(this);
        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 5);

        ipX.rents(0) = IPX.Rent({
            tokenId: tokenId,
            renter: vm.addr(3),
            expiresAt: block.timestamp + 1 days,
            rentPrice: 0.5 ether,
            stillValid: true,
            timestamps: block.timestamp
        });

        Rent[] memory rents = ipX.getListRentFromMyIPs(owner);

        assertEq(rents.length, 1);
        assertEq(rents[0].tokenId, tokenId);
    }

    function test_getListRent() public {
        address renter = vm.addr(3);

        uint256 tokenId = ipX.registerIP("IP Rent", "Desc Rent", 1, "TagRent", "ipfs://rent", 1, 1 ether, 10);
        ipX.rents(0) = IPX.Rent({
            tokenId: tokenId,
            renter: renter,
            expiresAt: block.timestamp + 2 days,
            rentPrice: 0.7 ether,
            stillValid: true,
            timestamps: block.timestamp
        });

        Rent[] memory rents = ipX.getListRent(renter);

        assertEq(rents.length, 1);
        assertEq(rents[0].renter, renter);
        assertEq(rents[0].tokenId,tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
