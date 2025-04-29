// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract RoyaltyToken is ERC20, ERC20Burnable, Ownable, ERC20Permit, ERC20Votes, ReentrancyGuard {
    // errors
    error NotIPX();
    error NotImplemented();
    error AlreadyClaimed();

    address public ipx;
    uint256 public ipId;
    address public rewardToken;

    mapping(uint256 => uint256) public royaltyDistributions;
    mapping(uint256 => mapping(address => bool)) public royaltyClaimed;

    constructor(string memory _name, string memory _symbol, address _ipx, uint256 _ipId, address _rewardToken)
        ERC20(_name, _symbol)
        Ownable(_ipx)
        ERC20Permit(_name)
    {
        ipx = _ipx;
        ipId = _ipId;
        _mint(_ipx, 100_000_000e18);
        rewardToken = _rewardToken;
    }

    function getIPX() public view returns (address) {
        return ipx;
    }

    function getIPId() public view returns (uint256) {
        return ipId;
    }

    function depositRoyalty(uint256 amount) public nonReentrant returns (uint256) {
        royaltyDistributions[block.number] += amount;
        IERC20(rewardToken).transferFrom(msg.sender, address(this), amount);
        return block.number;
    }

    function claimRoyalty(uint256 blockNumber) public nonReentrant {
        if (royaltyClaimed[blockNumber][msg.sender]) revert AlreadyClaimed();

        uint256 rtOwned = getPastBalance(msg.sender, blockNumber);
        uint256 totalSupply = getPastTotalSupply(blockNumber);
        uint256 totalRoyaltyAmount = royaltyDistributions[blockNumber];

        uint256 amount = (rtOwned * totalRoyaltyAmount) / totalSupply;
        royaltyClaimed[blockNumber][msg.sender] = true;
        IERC20(rewardToken).transfer(msg.sender, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        // force to self delegate
        // source: https://forum.openzeppelin.com/t/self-delegation-in-erc20votes/17501/17
        if (to != address(0) && numCheckpoints(to) == 0 && delegates(to) == address(0)) {
            _delegate(to, to);
        }
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function getPastBalance(address account, uint256 blockNumber) public view returns (uint256) {
        return super.getPastVotes(account, blockNumber);
    }

    function getPastVotes(address account, uint256 blockNumber) public view override returns (uint256) {
        revert NotImplemented();
    }

    function delegate(address delegatee) public virtual override {
        revert NotImplemented();
    }

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
    {
        revert NotImplemented();
    }
}
