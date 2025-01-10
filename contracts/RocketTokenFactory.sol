// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./RocketTokenNew.sol";
contract RocketTokenFactory {
    address public owner;
    address public rocketLaunch;
    constructor() {
        owner = msg.sender;
        rocketLaunch = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setRocketLaunch(address _rocketLaunch) public onlyOwner {
        rocketLaunch = _rocketLaunch;
    }

    function createNewToken(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) public returns (address) {
        require(msg.sender == rocketLaunch, "Only rocketLaunch can call this function");
        RocketTokenNew newToken = new RocketTokenNew(name_, symbol_, 18, totalSupply_, msg.sender);
        return address(newToken);
    }
}
