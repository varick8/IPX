// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IPX} from "../src/Draft-IPX.sol";
import {RoyaltyToken} from "../src/RoyaltyToken.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {RoyaltyTokenFactory} from "../src/RoyaltyTokenFactory.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

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

        uint256 tokenId1 = ipX.registerIP("Title", "Description", 1, "Tag", "ipfs://hash", 1, 1, 0, 10);

        uint256 tokenId2 =
            ipX.registerIP("Title again", "Description again", 2, "Tag again", "ipfs://hash again", 2, 2, 0, 20);

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
        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 0, 5);

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
        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 1 ether, 5);

        address renter = vm.addr(2);
        vm.deal(renter, 10 ether);
        vm.prank(renter);

        vm.expectRevert(IPX.InsufficientFunds.selector);
        ipX.rentIP{value: 0.5 ether}(tokenId);
    }

    function test_remixIP() public {
        address owner = address(this);

        uint256 tokenId = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 0, 5);

        ipX.remixIP("My Remix IP", "Desc", 1, "Remix Tag", "ipfs://file", 5, tokenId);

        assertEq(ipX.ownerOf(0), owner);

        address parentRoyaltyToken = ipX.royaltyTokens(0);
        address childRoyaltyToken = ipX.royaltyTokens(1);

        // console.log(parentRoyaltyToken, childRoyaltyToken);
        // console.log(IERC20(childRoyaltyToken).balanceOf(parentRoyaltyToken));
        // console.log(IERC20(childRoyaltyToken).balanceOf(owner));

        // parent should have 20% of the child royalty token
        // assertEq(IERC20(childRoyaltyToken).balanceOf(parentRoyaltyToken), 20_000_000e18);

        // creator should have 80% of the child royalty token
        // assertEq(IERC20(childRoyaltyToken).balanceOf(owner), 80_000_000e18);
    }

    function test_deposit_claim_royalty() public {
        // royalty reward token is USDC
        mockUSDC.mint(address(this), 1000e6);
        uint256 tokenIp = ipX.registerIP("My IP", "Desc", 1, "Tag", "ipfs://file", 0, 1 ether, 0, 5);

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

    function test_getIPsNotOwnedBy() public {
        address owner = address(this);

        ipX.registerIP("IP1", "Desc1", 1, "Tag1", "ipfs://1", 1, 1 ether, 0, 10);
        ipX.registerIP("IP2", "Desc2", 1, "Tag2", "ipfs://2", 1, 1 ether, 0, 10);

        address otherUser = vm.addr(2);
        vm.startPrank(otherUser);
        ipX.registerIP("IP3", "Desc3", 1, "Tag3", "ipfs://3", 1, 1 ether, 0, 10);
        vm.stopPrank();

        IPX.IP[] memory ips = ipX.getIPsNotOwnedBy(owner);

        assertEq(ips.length, 1);
        assertEq(ips[0].title, "IP3");
    }

    function test_getListRent() public {
        address renter = vm.addr(3);

        uint256 tokenId = ipX.registerIP("IP Rent", "Desc Rent", 1, "TagRent", "ipfs://rent", 1, 1 ether, 0, 10);
        vm.deal(renter, 10 ether);
        vm.prank(renter);
        ipX.rentIP{value: 1 ether}(tokenId);

        IPX.Rent[] memory rents = ipX.getListRent(renter);
        for (uint256 i = 0; i < rents.length; i++) {
            console.log("Renter:", rents[i].renter);
            console.log("Expires At:", rents[i].expiresAt);
        }

        assertEq(rents.length, 1);
        assertEq(rents[0].renter, renter);
        assertEq(rents[0].expiresAt > block.timestamp, true);
    }

    // Test getMyRemix() function
    function test_getMyRemix() public {
        address owner = address(this);
        console.log("Owner address:", owner);

        // Daftar IP biasa
        uint256 originalTokenId =
            ipX.registerIP("Original IP", "Original Description", 1, "Original Tag", "ipfs://original", 0, 1 ether, 0, 5);
        console.log("Original token ID:", originalTokenId);

        // Buat remix IP
        uint256 remixTokenId =
            ipX.remixIP("Remix IP", "Remix Description", 1, "Remix Tag", "ipfs://remix", 5, originalTokenId);
        uint256 remixTokenId2 =
            ipX.remixIP("Remix IP", "Remix Description", 1, "Remix Tag", "ipfs://remix", 5, originalTokenId);
        console.log("Remix token ID:", remixTokenId);
        console.log("Remix token ID:", remixTokenId2);

        // Cek data remix
        IPX.IP memory remixIP = ipX.getIP(remixTokenId);
        console.log("Remix license option:", remixIP.licenseopt);
        console.log("Remix parent ID:", ipX.parentIds(remixTokenId));

        // Panggil getMyRemix
        IPX.RemixInfo[] memory myRemixes = ipX.getMyRemix(owner);
        console.log("Number of remixes:", myRemixes.length);

        assertEq(myRemixes.length, 2);
        assertEq(myRemixes[0].ip.title, "Remix IP");
        assertEq(myRemixes[0].parentId, originalTokenId);
    }

    function test_getMyRemix_empty() public {
        address owner = address(this);

        // Daftar IP biasa tanpa remix
        ipX.registerIP("Regular IP", "Some Description", 1, "Tag", "ipfs://something", 0, 1 ether, 0, 5);

        // Harusnya tidak ada remix
        IPX.RemixInfo[] memory myRemixes = ipX.getMyRemix(owner);
        assertEq(myRemixes.length, 0);
    }

    function test_getMyIPsRemix() public {
        address owner = address(1);
        address user1 = address(2);
        address user2 = address(3);

        vm.prank(owner);
        uint256 originalTokenId =
            ipX.registerIP("Original IP", "Original Description", 1, "Original Tag", "ipfs://original", 0, 1 ether, 0, 5);

        vm.prank(user1);
        uint256 remixTokenId =
            ipX.remixIP("Remix IP 1", "Remix 1 Description", 1, "Remix Tag", "ipfs://remix1", 5, originalTokenId);

        vm.prank(user2);
        uint256 remixTokenId2 =
            ipX.remixIP("Remix IP 2", "Remix 2 Description", 1, "Remix Tag", "ipfs://remix2", 5, originalTokenId);
        console.log("Remix token ID:", remixTokenId);
        console.log("Remix token ID:", remixTokenId2);

        IPX.RemixInfo[] memory remixes = ipX.getMyIPsRemix(originalTokenId);

        console.log("Remix 1 title:", remixes[0].ip.title);
        console.log("Remix 1 description:", remixes[0].ip.description);
        console.log("Remix 2 title:", remixes[1].ip.title);
        console.log("Remix 2 description:", remixes[1].ip.description);

        assertEq(remixes.length, 2);

        // cek apakah parent id nya cocok
        assertEq(remixes[0].parentId, originalTokenId);
        assertEq(remixes[1].parentId, originalTokenId);

        // cek data asli dari remix
        assertEq(remixes[0].ip.fileUpload, "ipfs://remix1");
        assertEq(remixes[1].ip.fileUpload, "ipfs://remix2");
        assertEq(remixes[0].ip.title, "Remix IP 1");
        assertEq(remixes[1].ip.title, "Remix IP 2");
    }

    // GetIp: tambahin yang bukan kategori remix (Alex)
    function test_get_non_remix_remix() public {
        address owner = address(this);

        // Step 1: Register dua IP
        ipX.registerIP("Title", "Description", 1, "Tag", "ipfs://hash", 1, 1, 0, 10);

        ipX.registerIP("Title again", "Description again", 2, "Tag again", "ipfs://hash again", 4, 5, 0, 20);

        ipX.remixIP("Remix Title", "Remix Description", 0, "Remix Tag", "ipfs://remixhash", 15, 0);

        IPX.IP[] memory remixIps = ipX.get_non_remix(owner);

        for (uint256 i = 0; i < remixIps.length; i++) {
            assertNotEq(remixIps[i].licenseopt, 5);
            console.log(remixIps[i].title);
        }
    }

    function test_getListRentFromMyIp_PreventsDuplicates() public {
        // Register two IPs owned by the test contract
        uint256 tokenId1 = ipX.registerIP("IP One", "First IP for rent", 1, "Test", "ipfs://file1", 0, 1 ether, 0, 5);
        uint256 tokenId2 = ipX.registerIP("IP Two", "Second IP for rent", 2, "Test", "ipfs://file2", 0, 2 ether, 0, 7);

        // Create test renter addresses
        address renter1 = vm.addr(101);
        address renter2 = vm.addr(102);

        // Fund the renters
        vm.deal(renter1, 10 ether);
        vm.deal(renter2, 10 ether);

        // Initially, there should be no renters
        address[] memory initialRenters = ipX.getListRentFromMyIp();
        assertEq(initialRenters.length, 0, "Should start with no renters");

        // Renter1 rents both IPs
        vm.prank(renter1);
        ipX.rentIP{value: 1 ether}(tokenId1);

        vm.prank(renter1); // Same renter rents another IP
        ipX.rentIP{value: 2 ether}(tokenId2);

        // Renter2 rents the first IP
        vm.prank(renter2);
        ipX.rentIP{value: 1 ether}(tokenId1);

        // Check that we have only 2 unique renters despite 3 rental transactions
        address[] memory uniqueRenters = ipX.getListRentFromMyIp();

        // Log the results
        console.log("Number of unique renters:", uniqueRenters.length);
        for (uint256 i = 0; i < uniqueRenters.length; i++) {
            console.log("Unique renter", i, ":", uniqueRenters[i]);
        }

        // The result should contain exactly 2 unique addresses
        assertEq(uniqueRenters.length, 2, "Should have exactly 2 unique renters");

        // Verify both renters are included (order may vary)
        bool foundRenter1 = false;
        bool foundRenter2 = false;

        for (uint256 i = 0; i < uniqueRenters.length; i++) {
            if (uniqueRenters[i] == renter1) foundRenter1 = true;
            if (uniqueRenters[i] == renter2) foundRenter2 = true;
        }

        assertTrue(foundRenter1, "Should include renter1");
        assertTrue(foundRenter2, "Should include renter2");
    }

    function test_getListRentFromMyIp_General_Part1() public {
        // Register IPs owned by the test contract
        uint256 tokenId1 = ipX.registerIP("IP One", "First IP for rent", 1, "Test", "ipfs://file1", 0, 1 ether, 0, 5);
        uint256 tokenId2 = ipX.registerIP("IP Two", "Second IP for rent", 2, "Test", "ipfs://file2", 0, 2 ether, 0, 7);

        // Create test renter addresses
        address renter1 = vm.addr(101);
        address renter2 = vm.addr(102);

        // Fund the renters
        vm.deal(renter1, 10 ether);
        vm.deal(renter2, 10 ether);

        // Test 1: Initially, there should be no renters
        address[] memory initialRenters = ipX.getListRentFromMyIp();
        assertEq(initialRenters.length, 0, "Should start with no renters");

        // Test 2: Add one renter to one IP
        vm.prank(renter1);
        ipX.rentIP{value: 1 ether}(tokenId1);

        address[] memory oneRenter = ipX.getListRentFromMyIp();
        assertEq(oneRenter.length, 1, "Should have one renter");
        assertEq(oneRenter[0], renter1, "Should be renter1");

        // Test 3: Add another renter to a different IP
        vm.prank(renter2);
        ipX.rentIP{value: 2 ether}(tokenId2);

        address[] memory multipleRenters = ipX.getListRentFromMyIp();
        assertEq(multipleRenters.length, 2, "Should have two renters");
    }

    function test_getListRentFromMyIp_General_Part2() public {
        // Register IPs owned by the test contract
        uint256 tokenId1 = ipX.registerIP("IP One", "First IP for rent", 1, "Test", "ipfs://file1", 0, 1 ether, 0, 5);

        // Create test renter and owner addresses
        address renter1 = vm.addr(101);
        address otherOwner = vm.addr(200);

        // Fund accounts
        vm.deal(renter1, 10 ether);
        vm.deal(otherOwner, 10 ether);

        // Add a renter to our IP
        vm.prank(renter1);
        ipX.rentIP{value: 1 ether}(tokenId1);

        // Test 4: Test with another owner's perspective
        vm.startPrank(otherOwner);
        uint256 otherTokenId = ipX.registerIP("Other IP", "Other owner's IP", 4, "Test", "ipfs://other", 0, 1 ether, 0, 5);
        address[] memory otherOwnerInitialRenters = ipX.getListRentFromMyIp();
        assertEq(otherOwnerInitialRenters.length, 0, "Other owner should have no renters initially");
        vm.stopPrank();

        // Original owner should still see their renter
        address[] memory originalRenters = ipX.getListRentFromMyIp();
        assertEq(originalRenters.length, 1, "Original owner should have one renter");
        assertEq(originalRenters[0], renter1, "Should be renter1");
    }

    function test_getListRentFromMyIp_General_Part3() public {
        // Register IP owned by the test contract
        uint256 tokenId1 = ipX.registerIP("IP One", "First IP for rent", 1, "Test", "ipfs://file1", 0, 1 ether, 0, 5);

        // Create test renter and new owner addresses
        address renter1 = vm.addr(101);
        address newOwner = vm.addr(300);

        // Fund accounts
        vm.deal(renter1, 10 ether);
        vm.deal(newOwner, 10 ether);

        // Add a renter to our IP
        vm.prank(renter1);
        ipX.rentIP{value: 1 ether}(tokenId1);

        // Verify the renter is correctly tracked before transfer
        address[] memory beforeTransferRenters = ipX.getListRentFromMyIp();
        assertEq(beforeTransferRenters.length, 1, "Original owner should see one renter before transfer");

        // Check token ownership before transfer
        console.log("Token owner before transfer:", ipX.ownerOf(tokenId1));

        // Transfer tokenId1 to newOwner
        ipX.transferFrom(address(this), newOwner, tokenId1);

        // Verify token ownership after transfer
        console.log("Token owner after transfer:", ipX.ownerOf(tokenId1));

        // Check renters for original owner
        address[] memory afterTransferRenters = ipX.getListRentFromMyIp();
        console.log("Original owner renters after transfer:", afterTransferRenters.length);

        // Check renters for new owner
        vm.prank(newOwner);
        address[] memory newOwnerRenters = ipX.getListRentFromMyIp();
        console.log("New owner renters after transfer:", newOwnerRenters.length);

        // Let's also get the rent data directly to see what's happening
        IPX.Rent[] memory rents = ipX.getListRent(renter1);
        console.log("Renter's active rentals:", rents.length);

        // Print any available fields from the Rent struct
        if (rents.length > 0) {
            console.log("Rental renter:", rents[0].renter);
            console.log("Rental expires at:", rents[0].expiresAt);
            // Add other fields that actually exist in the Rent struct
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
