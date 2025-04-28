// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RoyaltyToken} from "./RoyaltyToken.sol";

contract RoyaltyTokenFactory {
    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function createRoyaltyToken(string memory name, string memory symbol, uint256 ipId) public returns (address) {
        RoyaltyToken royaltyToken = new RoyaltyToken(name, symbol, msg.sender, ipId, rewardToken);
        return address(royaltyToken);
    }
}
