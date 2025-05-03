// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {RoyaltyTokenFactory} from "./RoyaltyTokenFactory.sol";
import "forge-std/console.sol"; // Foundry

contract IPX is ERC721 {
    error InsufficientFunds();
    error InvalidTokenId();

//    uint256 public rentId;
    uint256 public nextTokenId = 0;
    RoyaltyTokenFactory public royaltyTokenFactory;

    constructor(address _royaltyTokenFactory) ERC721("IPX", "IPX") {
        royaltyTokenFactory = RoyaltyTokenFactory(_royaltyTokenFactory);
    }

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
        uint256 rentPrice;
        uint256 royaltyPercentage;
    }

    function logAllIps(uint256 totaldata) public view {
        for (uint256 i = 0; i < totaldata; i++) {
            IP memory ip = ips[i];
            console.log("IP", i);
            console.log("Owner:", ip.owner);
            console.log("Title:", ip.title);
            console.log("Description:", ip.description);
            console.log("Category:", ip.category);
            console.log("Tag:", ip.tag);
            console.log("FileUpload:", ip.fileUpload);
            console.log("LicenseOpt:", ip.licenseopt);
            console.log("BasePrice:", ip.basePrice);
            console.log("RoyaltyPercentage:", ip.royaltyPercentage);
        }
    }

    // Rent struct
    struct Rent {
        address renter;
        uint256 expiresAt;
    }

    // Remix Struct
    struct RemixInfo {
        IP ip;
        uint256 parentId;
    }

    // Struct buat fungsi ijal supaya nge-return data dari IP yang dipinjem
    struct RentInfo {
        IP[] ip;
        uint256 renterId;
    }

    // Mapping dari tokenId ke IP metadata
    mapping(uint256 => IP) public ips;

    // Mapping dari tokenId ke Rent metadata
    mapping(uint256 => address[]) public rents;

    // Mapping dari user address ke tokenId
    mapping(address => uint256[]) public ownerToTokenIds;

    // id IP => user => data rent
    mapping(uint256 => mapping(address => Rent)) public rental;

    // id IP => parent IP
    mapping(uint256 => uint256) public parentIds;

    // id IP => royalty token
    mapping(uint256 => address) public royaltyTokens;

    mapping(uint256 => mapping(address => bool)) public hasRemixed;

    // parent IP id => list of remixers' addresses
    mapping(uint256 => address[]) public remixersOf;

    mapping(uint256 => mapping(address => uint256)) public remixTokenOf;

    mapping(address => IP[]) public renterIPs;

    mapping(address => IP[]) public buyIPs;

    // helper function untuk keperluan buy [buat map ownerToTokenIds]
    function _removeTokenIdFromOwner(address owner, uint256 tokenId) internal {
        uint256[] storage tokenIds = ownerToTokenIds[owner];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                tokenIds[i] = tokenIds[tokenIds.length - 1]; // ganti dengan elemen terakhir
                tokenIds.pop(); // hapus elemen terakhir
                break;
            }
        }
    }

    // Daftarkan IP dan mint NFT
    // tamabahin logic license opt
    // 0 = personal, 1 = rent, 2 = rent&buy, 3 = remix: parent IP remix, 4 = remixIP: child remix
    function registerIP(
        string memory _title,
        string memory _description,
        uint256 _category,
        string memory _tag,
        string memory _fileUpload,
        uint8 _licenseopt,
        uint256 _basePrice,
        uint256 _rentPrice,
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
            rentPrice: _rentPrice,
            royaltyPercentage: _royaltyPercentage
        });

        ips[tokenId] = newIP;
        _safeMint(msg.sender, tokenId);
        address rt = royaltyTokenFactory.createRoyaltyToken(_title, _title, tokenId);
        royaltyTokens[tokenId] = rt;
        IERC20(rt).transfer(msg.sender, _basePrice);

        ownerToTokenIds[msg.sender].push(tokenId);

        return tokenId;
    }

    // Buy IP [pindah kepemilikan IP]
    function buyIP(uint256 tokenId) public payable {
        // cek valid owner
        address currentOwner = ownerOf(tokenId);
        require(currentOwner != msg.sender, "Cannot buy your own IP");

        // check price
        IP memory ip = ips[tokenId];
        uint256 ipPrice = ip.basePrice;
        if (msg.value < ipPrice) revert InsufficientFunds();

        // Transfer payment to current owner
        payable(currentOwner).transfer(msg.value);

        // _transfer itu => from, to, token
        _transfer(currentOwner, msg.sender, tokenId);

        // Update owner in IP metadata
        ips[tokenId].owner = msg.sender;

        // hapus pemilik lama, tambah ke pemilik baru
        _removeTokenIdFromOwner(currentOwner, tokenId);
        ownerToTokenIds[msg.sender].push(tokenId);
        buyIPs[msg.sender].push(ips[tokenId]);
    }

    // Rent IP [dipinjem]
    // ini penentuan duration jadinya
    function rentIP(uint256 tokenId) public payable {
        if (tokenId > nextTokenId) revert InvalidTokenId();
        uint256 price = ips[tokenId].rentPrice;
        uint256 duration = 30 days;
        if (msg.value < price) revert InsufficientFunds();
        rental[tokenId][msg.sender] = Rent({expiresAt: block.timestamp + duration, renter: msg.sender});
        rents[tokenId].push(msg.sender);
        renterIPs[msg.sender].push(ips[tokenId]);
    }

    // remix ip
    // pembagian royalti bukannya lewat withdraw?
    // pending royalti gmn?
    function remixIP(
        string memory _title,
        string memory _description,
        uint256 _category,
        string memory _tag,
        string memory _fileUpload,
        uint256 _royaltyPercentage,
        uint256 parentId
    ) public returns (uint256) {
        if (parentId > nextTokenId) revert InvalidTokenId();

        uint256 parentRoyaltyRightPercentage = _royaltyPercentage; // equal to 20%
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ips[tokenId] = IP(msg.sender, _title, _description, _category, _tag, _fileUpload, 4, 0, 0, _royaltyPercentage);
        parentIds[tokenId] = parentId;

        if (!hasRemixed[parentId][msg.sender]) {
            remixersOf[parentId].push(msg.sender);
            hasRemixed[parentId][msg.sender] = true;
            remixTokenOf[parentId][msg.sender] = tokenId;
        }

        // Add this line to update the mapping
        ownerToTokenIds[msg.sender].push(tokenId);

        address rt = royaltyTokenFactory.createRoyaltyToken(_title, _title, tokenId);
        royaltyTokens[tokenId] = rt;
        uint256 parentRoyaltyRight = (100_000_000e18 * parentRoyaltyRightPercentage) / 100;
        uint256 creatorRoyaltyRight = 100_000_000e18 - parentRoyaltyRight;

        // transfer to parent royalty token
        IERC20(rt).transfer(royaltyTokens[parentId], parentRoyaltyRight);

        // transfer to creator
        IERC20(rt).transfer(msg.sender, creatorRoyaltyRight);

        return tokenId;
    }

    // nanti returnnya address pemilik token
    function getIP(uint256 tokenId) public view returns (IP memory) {
        return ips[tokenId];
    }

    // nanti returnnya list IP nya
    function getIPsByOwner(address _owner) public view returns (IP[] memory) {
        uint256[] memory tokenIds = ownerToTokenIds[_owner];
        IP[] memory result = new IP[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            result[i] = ips[tokenIds[i]];
        }

        return result;
    }

    // Get IP yang bukan punya owner
    function getIPsNotOwnedBy(address user) public view returns (IP[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user) {
                count++;
            }
        }

        IP[] memory result = new IP[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user) {
                result[index++] = ips[i];
            }
        }

        return result;
    }

    // Get seluruh IP yang disewa oleh user
    function getListRent(address renter) public view returns (Rent[] memory) {
        uint256 count = 0;

        for (uint256 tokenId = 0; tokenId < nextTokenId; tokenId++) {
            if (rental[tokenId][renter].expiresAt > block.timestamp) {
                count++;
            }
        }

        Rent[] memory result = new Rent[](count);
        uint256 index = 0;
        for (uint256 tokenId = 0; tokenId < nextTokenId; tokenId++) {
            if (rental[tokenId][renter].expiresAt > block.timestamp) {
                result[index++] = rental[tokenId][renter];
            }
        }

        return result;
    }

    // get non-remixer IP
    function get_non_remix(address _owner) public view returns (IP[] memory) {
        uint256[] memory tokenIds = ownerToTokenIds[_owner];

        IP[] memory result = new IP[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // supposed that the remix in liscense opt is 5
            if (ips[tokenIds[i]].licenseopt != 5) {
                result[i] = ips[tokenIds[i]];
            }
        }

        return result;
    }

    // Kuarng data IPnya yang di remix
    // Get siapa aja yang nge-remix IP user
    function getMyIPsRemix(uint256 parentTokenId) public view returns (RemixInfo[] memory) {
        address[] memory remixerAddresses = remixersOf[parentTokenId];
        RemixInfo[] memory remixList = new RemixInfo[](remixerAddresses.length);

        for (uint256 i = 0; i < remixerAddresses.length; i++) {
            address remixer = remixerAddresses[i];
            uint256 remixTokenId = remixTokenOf[parentTokenId][remixer];
            remixList[i] = RemixInfo({ip: ips[remixTokenId], parentId: parentTokenId});
        }
        return remixList;
    }

    // Get IP yang user remix
    function getMyRemix(address _owner) public view returns (RemixInfo[] memory) {
        uint256[] storage tokenIds = ownerToTokenIds[_owner];
        uint256 count = 0;

        // First pass: count remixes
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (ips[tokenId].licenseopt == 4) {
                count++;
            }
        }

        // Create the result array
        RemixInfo[] memory result = new RemixInfo[](count);
        uint256 index = 0;

        // Second pass: populate the result array
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (ips[tokenId].licenseopt == 4) {
                result[index] = RemixInfo({ip: ips[tokenId], parentId: parentIds[tokenId]});
                index++;
            }
        }

        return result;
    }

    // kurang data IP buat di bagian royalty management
    // Function untuk melihat siapa aja yang minjem IP gua
    function getListRentFromMyIp() public view returns (RentInfo[] memory) {
        uint256[] memory tokenIds = ownerToTokenIds[msg.sender];

        // First, count the maximum possible number of renters
        uint256 maxRenters = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            maxRenters += rents[tokenIds[i]].length;
        }

        // Create the result array
        RentInfo[] memory result = new RentInfo[](maxRenters);
        uint256 resultIndex = 0;

        // For each token ID owned by the sender
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address[] memory rentersOfToken = rents[tokenId];

            // For each renter of this token
            for (uint256 j = 0; j < rentersOfToken.length; j++) {
                address renter = rentersOfToken[j];

                // Check if the rental is still active
                if (rental[tokenId][renter].expiresAt > block.timestamp) {
                    // Create an array with the single IP for this rental
                    IP[] memory rentedIP = new IP[](1);
                    rentedIP[0] = ips[tokenId];

                    // Add the rental info to the result
                    result[resultIndex] = RentInfo({
                        ip: rentedIP,
                        renterId: tokenId
                    });

                    resultIndex++;
                }
            }
        }

        // Create a right-sized array if there are fewer active rentals than maxRenters
        if (resultIndex < maxRenters) {
            RentInfo[] memory trimmedResult = new RentInfo[](resultIndex);
            for (uint256 i = 0; i < resultIndex; i++) {
                trimmedResult[i] = result[i];
            }
            return trimmedResult;
        }

        return result;
    }

    function getListBuy() public view returns (IP[] memory) {
        return buyIPs[msg.sender];
    }
}
