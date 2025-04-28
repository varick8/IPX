// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IPX} from "../src/Draft-IPX.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {RoyaltyToken} from "../src/RoyaltyToken.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {RoyaltyTokenFactory} from "../src/RoyaltyTokenFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IPXTest is Test, IERC721Receiver {
    IPX public ipX;
    RoyaltyTokenFactory public royaltyTokenFactory;
    MockUSDC public mockUSDC;

    function setUp() public {
        mockUSDC = new MockUSDC();
        royaltyTokenFactory = new RoyaltyTokenFactory(address(mockUSDC));
        ipX = new IPX(address(royaltyTokenFactory));
    }

    // tambahin biar bisa simulai payable
    receive() external payable {}

    function test_registerIP() public {
        address owner = address(this);

        uint256 tokenId1 = ipX.registerIP(
            "Title",
            "Description",
            1,
            "Tag",
            "ipfs://hash",
            1,
            1,
            10
        );

        uint256 tokenId2 = ipX.registerIP(
            "Title again",
            "Description again",
            2,
            "Tag again",
            "ipfs://hash again",
            2,
            2,
            20
        );

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
        uint256 tokenId = ipX.registerIP(
            "My IP",
            "Desc",
            1,
            "Tag",
            "ipfs://file",
            0,
            1 ether,
            5
        );

        // masih punya yang lama
        assertEq(ipX.ownerOf(tokenId), owner);

        address buyer = vm.addr(1);
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        ipX.buyIP{value: 2 ether}(tokenId);

        // pindah kepemilikan
        assertEq(ipX.ownerOf(tokenId), buyer);
    }

    function test_rent_ip_revert_invalid_token_id() public {
        vm.expectRevert(IPX.InvalidTokenId.selector);
        ipX.rentIP{value: 1 ether}(999); // token id yang belum pernah didaftarkan
    }

    function test_rent_ip_revert_insufficient_funds() public {
        uint256 tokenId = ipX.registerIP(
            "My IP",
            "Desc",
            1,
            "Tag",
            "ipfs://file",
            0,
            1 ether,
            5
        );

        address renter = vm.addr(2);
        vm.deal(renter, 10 ether);
        vm.prank(renter);

        vm.expectRevert(IPX.InsufficientFunds.selector);
        ipX.rentIP{value: 0.5 ether}(tokenId);
    }

    function test_remixIP() public {
        address owner = address(this);

        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 5);

        ipX.remixIP("My Remix IP", "Desc", 1, "Remix Tag", "ipfs://file", 0, 1 ether, 5, tokenId);

        assertEq(ipX.ownerOf(0), owner);

        address parentRoyaltyToken = ipX.royaltyTokens(0);
        address childRoyaltyToken = ipX.royaltyTokens(1);

        // console.log(parentRoyaltyToken, childRoyaltyToken);
        // console.log(IERC20(childRoyaltyToken).balanceOf(parentRoyaltyToken));
        // console.log(IERC20(childRoyaltyToken).balanceOf(owner));

        // parent should have 20% of the child royalty token
        assertEq(IERC20(childRoyaltyToken).balanceOf(parentRoyaltyToken), 20_000_000e18);

        // creator should have 80% of the child royalty token
        assertEq(IERC20(childRoyaltyToken).balanceOf(owner), 80_000_000e18);
    }

    function test_deposit_claim_royalty() public {
        // royalty reward token is USDC
        mockUSDC.mint(address(this), 1000e6);
        uint256 tokenIp = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 5);

        // deposit royalty
        address rt = ipX.royaltyTokens(tokenIp);
        IERC20(mockUSDC).approve(rt, 1000e6);
        uint256 blockNumber = RoyaltyToken(rt).depositRoyalty(1000e6);

        // advance 1 block
        vm.roll(block.number + 1);
        RoyaltyToken(rt).claimRoyalty(blockNumber);
    }

    // function test_buyOwnIP() public {
    //     uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 10 ether, 5);

    //     vm.expectRevert("Cannot buy your own IP");
    //     ipX.buyIP{value: 10 ether}(tokenId);
    // }

    // function test_getIPsNotOwnedBy() public {
    //     address owner = address(this);

    //     ipX.registerIP("IP1", "Desc1", 1, "Tag1", "ipfs://1", 1, 1 ether, 10);
    //     ipX.registerIP("IP2", "Desc2", 1, "Tag2", "ipfs://2", 1, 1 ether, 10);

    //     address otherUser = vm.addr(2);
    //     vm.startPrank(otherUser);
    //     ipX.registerIP("IP3", "Desc3", 1, "Tag3", "ipfs://3", 1, 1 ether, 10);
    //     vm.stopPrank();

    //     IPX.IP[] memory ips = ipX.getIPsNotOwnedBy(owner);

    //     assertEq(ips.length, 1);
    //     assertEq(ips[0].title, "IP3");
    // }

    // function test_getListRentFromMyIPs() public {
    //     address owner = address(this);
    //     uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 5);

    //     ipX._setRent({
    //         tokenId: tokenId,
    //         renter: vm.addr(3),
    //         expiresAt: block.timestamp + 1 days,
    //         rentPrice: 0.5 ether,
    //         stillValid: true,
    //         timestamps: block.timestamp
    //     });

    //     IPX.Rent[] memory rents = ipX.getListRentFromMyIPs(owner);

    //     assertEq(rents.length, 1);
    //     assertEq(rents[0].tokenId, tokenId);
    // }

    // function test_getListRent() public {
    //     address renter = vm.addr(3);

    //     uint256 tokenId = ipX.registerIP("IP Rent", "Desc Rent", 1, "TagRent", "ipfs://rent", 1, 1 ether, 10);
    //     ipX._setRent({
    //         tokenId: tokenId,
    //         renter: renter,
    //         expiresAt: block.timestamp + 2 days,
    //         rentPrice: 0.7 ether,
    //         stillValid: true,
    //         timestamps: block.timestamp
    //     });

    //     IPX.Rent[] memory rents = ipX.getListRent(renter);

    //     assertEq(rents.length, 1);
    //     assertEq(rents[0].renter, renter);
    //     assertEq(rents[0].tokenId, tokenId);
    // }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
