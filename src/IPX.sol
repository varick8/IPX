// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract IPX is ERC721 {

  error InsufficientFunds();
  error InvalidTokenId();

  struct IP {
    string title;
    string description;
    string category;
  }

  struct Rent {
    uint256 expiresAt;
  }

    uint256 public nextTokenId;

    // id IP => ipData
    mapping(uint256 => IP) public ipData;

    // id IP => user => data rent
    mapping(uint256 => mapping(address => Rent)) public rents;
    

    constructor() ERC721("IPX", "IPX") {}

    function registerIP(string memory title, string memory description, string memory category) public returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ipData[tokenId] = IP(title, description, category);
        return tokenId;
    }

    function buyIP(uint256 tokenId) public payable {
        uint256 price = 1000;
        if (msg.value < price) revert InsufficientFunds();
        _transfer(address(this), msg.sender, tokenId);
    }


    function rentIP(uint256 tokenId) public payable {
      if (tokenId > nextTokenId) revert InvalidTokenId();
      uint256 price = 1000;
      uint256 duration = 30 days;
      if (msg.value < price) revert InsufficientFunds();
      rents[tokenId][msg.sender] = Rent({expiresAt: block.timestamp + duration} );
    }
}