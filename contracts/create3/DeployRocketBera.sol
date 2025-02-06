// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Create3Factory.sol";
import "../RocketBera.sol";

contract DeployRocketBera {
    function deploy(
        Create3Factory factory,
        bytes32 salt,
        address platformAddress,
        uint256 platformFee,
        address feeAddress,
        uint256 fee,
        address wBera,
        address bexOpAddress,
        uint256 blockInterval,
        uint256 minCap
    ) external returns (address) {
        // Generate initialization code
        bytes memory initCode = abi.encodePacked(
            type(RocketBera).creationCode
        );

        // Deploy using Create3
        address deployed = factory.deploy(salt, initCode);

        // Initialize the contract
        RocketBera(payable(deployed)).initialize(
            platformAddress,
            platformFee,
            feeAddress,
            fee,
            wBera,
            bexOpAddress,
            blockInterval,
            minCap
        );

        return deployed;
    }

    function computeAddress(Create3Factory factory, address deployer, bytes32 salt) external view returns (address) {
        return factory.getDeploymentAddress(deployer, salt);
    }
}