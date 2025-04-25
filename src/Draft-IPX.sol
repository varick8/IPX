// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract IPX is ERC721 {

    uint256 public nextTokenId;

    constructor() ERC721("IPX", "IPX") {}

    // IP struct
    struct IP {
        address owner;
        string title;
        string description;
        uint256 category;
        string tag;
        string fileUpload;
        uint8 licenseopt;
        uint256 basePrice;
        uint256 royaltyPercentage;
        uint256 timestamps;
    }

    // Mapping dari tokenId ke IP metadata
    mapping(uint256 => IP) public ips;

    // Mapping dari user address ke tokenId
    mapping(address => uint256[]) public ownerToTokenIds;


    // Daftarkan IP dan mint NFT
    function registerIP(
        string memory _title,
        string memory _description,
        uint256 _category,
        string memory _tag,
        string memory _fileUpload,
        uint8 _licenseopt,
        uint256 _basePrice,
        uint256 _royaltyPercentage
    ) public returns (uint256) {
        uint256 tokenId = nextTokenId++;

        IP memory newIP = IP({
            owner: msg.sender,
            title: _title,
            description: _description,
            category: _category,
            tag: _tag,
            fileUpload: _fileUpload,
            licenseopt: _licenseopt,
            basePrice: _basePrice,
            royaltyPercentage: _royaltyPercentage,
            timestamps: block.timestamp
        });

        ips[tokenId] = newIP;
        _safeMint(msg.sender, tokenId);

        return tokenId;
    }
    // nanti returnnya address pemilik token
    function getIP(uint256 tokenId) public view returns (IP memory) {
        if (tokenId < nextTokenId) revert InvalidTokenId();
        return ips[tokenId];
    }

    // nanti returnnya list IP nya
    function getIPsByOwner(address _owner) public view returns (IP[] memory) {
        uint256[] memory tokenIds = ownerToTokenIds[_owner];
        IP[] memory result = new IP[](tokenIds.length);

        for (uint i = 0; i < tokenIds.length; i++) {
            result[i] = ips[tokenIds[i]];
        }

        return result;
    }
}
