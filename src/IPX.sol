// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
// import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {RoyaltyTokenFactory} from "./RoyaltyTokenFactory.sol";
import "forge-std/console.sol"; // Foundry

contract IPX is ERC721 {
    error InsufficientFunds();
    error InvalidTokenId();

    uint256 public rentId;
    uint256 public nextTokenId = 0;
    // RoyaltyTokenFactory public royaltyTokenFactory;

    constructor() ERC721("IPX", "IPX") {
        // royaltyTokenFactory = RoyaltyTokenFactory(_royaltyTokenFactory);
    }

    // IP struct
    struct IP {
        address owner;
        string title;
        string description;
        uint256 category;
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
        bool isValid;
    }

    // Remix Struct
    struct RemixInfo {
        IP ip;
        uint256 parentId;
    }

    // Struct buat fungsi ijal supaya nge-return data dari IP yang dipinjem
    struct RentInfo {
        IP ip;
        uint256 parentId;
    }

    struct RentedIP {
        IP ip;
        Rent rent;
    }

    struct Royalty {
        uint256 pendingRoyalty;
        uint256 claimedRoyalty;
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
    // mapping(uint256 => address) public royaltyTokens;

    // Mapping untuk menyimpan informasi royalty
    mapping(uint256 => Royalty) public royalties;

    mapping(uint256 => mapping(address => bool)) public hasRemixed;

    // parent IP id => list of remixers' addresses
    mapping(uint256 => address[]) public remixersOf;

    mapping(uint256 => mapping(address => uint256)) public remixTokenOf;

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
            fileUpload: _fileUpload,
            licenseopt: _licenseopt,
            basePrice: _basePrice,
            rentPrice: _rentPrice,
            royaltyPercentage: _royaltyPercentage
        });

        ips[tokenId] = newIP;
        _safeMint(msg.sender, tokenId);
        // address rt = royaltyTokenFactory.createRoyaltyToken(_title, _title, tokenId);
        // royaltyTokens[tokenId] = rt;
        // IERC20(rt).transfer(msg.sender, _basePrice);

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
    }

    // Rent IP [dipinjem]
    // ini penentuan duration jadinya
    function rentIP(uint256 tokenId, uint256 finalprice) public payable {
        if (tokenId > nextTokenId) revert InvalidTokenId();
        uint256 price = ips[tokenId].rentPrice;
        if (finalprice % price != 0) revert("Final price must be a multiple of rent price per day");
        uint256 durationInDays = finalprice / price;
        uint256 durationInSeconds = durationInDays * 1 days;
        if (msg.value < price) revert InsufficientFunds();
        rental[tokenId][msg.sender] = Rent({expiresAt: block.timestamp + durationInSeconds, renter: msg.sender, isValid: true});
        rents[tokenId].push(msg.sender);
    }

    // remix ip
    // pembagian royalti bukannya lewat withdraw?
    // pending royalti gmn?
    function remixIP(
        string memory _title,
        string memory _description,
        uint256 _category,
        string memory _fileUpload,
        uint256 parentId
    ) public returns (uint256) {
        if (parentId > nextTokenId) revert InvalidTokenId();

        // uint256 parentRoyaltyRightPercentage = ips[parentId].royaltyPercentage;
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        ips[tokenId] = IP(msg.sender, _title, _description, _category, _fileUpload, 4, 0, 0, 0);
        parentIds[tokenId] = parentId;

        if (!hasRemixed[parentId][msg.sender]) {
            remixersOf[parentId].push(msg.sender);
            hasRemixed[parentId][msg.sender] = true;
            remixTokenOf[parentId][msg.sender] = tokenId;
        }

        // Add this line to update the mapping
        ownerToTokenIds[msg.sender].push(tokenId);

        // address rt = royaltyTokenFactory.createRoyaltyToken(_title, _title, tokenId);
        // royaltyTokens[tokenId] = rt;
        // uint256 parentRoyaltyRight = (100_000_000e18 * parentRoyaltyRightPercentage) / 100;
        // uint256 creatorRoyaltyRight = 100_000_000e18 - parentRoyaltyRight;

        // // transfer to parent royalty token
        // IERC20(rt).transfer(royaltyTokens[parentId], parentRoyaltyRight);

        // // transfer to creator
        // IERC20(rt).transfer(msg.sender, creatorRoyaltyRight);

        return tokenId;
    }

    // Fungsi untuk menyetor royalti ke IP parent
    function depositRoyalty(uint256 remixTokenId) external payable {
        uint256 parentId = parentIds[remixTokenId];
        if (parentId == 0 && remixTokenId != 0) revert("Remix must have a valid parentId");
        if (msg.value == 0) revert("No royalty sent");

        royalties[parentId].pendingRoyalty += msg.value;
    }

    // Fungsi untuk klaim royalti oleh pemilik IP asli
    function claimRoyalty(uint256 tokenId) external {
        IP memory ip = ips[tokenId];
        if (msg.sender != ip.owner) revert("Only IP owner can claim royalties");

        uint256 amount = royalties[tokenId].pendingRoyalty;
        require(amount > 0, "No royalties to claim");

        royalties[tokenId].pendingRoyalty = 0;
        royalties[tokenId].claimedRoyalty += amount;

        payable(msg.sender).transfer(amount);
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

      // kurang logic yang bukan remix licesenceopt != 3
    // Get IP yang bukan punya owner
    function getIPsNotOwnedBy(address user) public view returns (IP[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user && ips[i].licenseopt != 3 && ips[i].licenseopt != 4) {
                count++;
            }
        }

        IP[] memory result = new IP[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user && ips[i].licenseopt != 3 && ips[i].licenseopt != 4) {
                result[index++] = ips[i];
            }
        }

        return result;
    }

    function getIPsNotOwnedByRemix(address user) public view returns (IP[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user && ips[i].licenseopt == 3) {
                count++;
            }
        }

        IP[] memory result = new IP[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextTokenId; i++) {
            if (ips[i].owner != user && ips[i].licenseopt == 3) {
                result[index++] = ips[i];
            }
        }

        return result;
    }

    // Get seluruh IP yang disewa oleh user
    function getListRent(address renter) public returns (RentedIP[] memory) {
        cleanAllExpiredRents(); // only clean for this user

        uint256 count = 0;

        // Count how many valid rentals this user has
        for (uint256 tokenId = 0; tokenId < nextTokenId; tokenId++) {
            if (rental[tokenId][renter].expiresAt > block.timestamp && rental[tokenId][renter].isValid) {
                count++;
            }
        }

        RentedIP[] memory result = new RentedIP[](count);
        uint256 index = 0;

        for (uint256 tokenId = 0; tokenId < nextTokenId; tokenId++) {
            Rent storage rent = rental[tokenId][renter];
                result[index] = RentedIP({
                    ip: ips[tokenId],
                    rent: rent
                });
                index++;
        }
        return result;
    }

     function getRoyalty(uint256 tokenId) external view returns (uint256 pending, uint256 claimed) {
        Royalty memory royalty = royalties[tokenId];
        return (royalty.pendingRoyalty, royalty.claimedRoyalty);
    }

    function cleanAllExpiredRents() public {
        for (uint256 tokenId = 0; tokenId < nextTokenId; tokenId++) {
            address[] storage renters = rents[tokenId];
            for (uint256 i = 0; i < renters.length; i++) {
                address renter = renters[i];
                if (
                    rental[tokenId][renter].expiresAt > 0 &&
                    rental[tokenId][renter].expiresAt < block.timestamp &&
                    rental[tokenId][renter].isValid
                ) {
                    rental[tokenId][renter].isValid = false;
                }
            }
        }
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
    function getListRentFromMyIp() public view returns (address[] memory) {
        uint256[] memory tokenIds = ownerToTokenIds[msg.sender];

        // First, count the maximum possible number of renters
        uint256 maxRenters = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            maxRenters += rents[tokenIds[i]].length;
        }

        // Create temporary arrays
        address[] memory tempRenters = new address[](maxRenters);
        uint256 uniqueCount = 0;

        // Collect unique renters
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            for (uint256 j = 0; j < rents[tokenId].length; j++) {
                address renter = rents[tokenId][j];
                bool isDuplicate = false;

                // Check if this address already exists in our result
                for (uint256 k = 0; k < uniqueCount; k++) {
                    if (tempRenters[k] == renter) {
                        isDuplicate = true;
                        break;
                    }
                }

                // If not a duplicate, add it
                if (!isDuplicate) {
                    tempRenters[uniqueCount] = renter;
                    uniqueCount++;
                }
            }
        }

        // Create a right-sized array with only unique renters
        address[] memory uniqueRenters = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueRenters[i] = tempRenters[i];
        }

        return uniqueRenters;
    }
}