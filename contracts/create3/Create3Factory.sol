// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Create3Factory {
    error DeploymentFailed();

    function deploy(bytes32 salt, bytes memory creationCode) public returns (address deployed) {
        // Deploy proxy
        address proxy = address(new Create3Proxy{salt: salt}());
        
        // Deploy implementation through proxy
        deployed = Create3Proxy(proxy).deploy(creationCode);
        if (deployed == address(0)) revert DeploymentFailed();
    }

    function getDeploymentAddress(address deployer, bytes32 salt) public view returns (address) {
        // Compute proxy address
        bytes32 proxyHash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(type(Create3Proxy).creationCode)
            )
        );
        return address(uint160(uint256(proxyHash)));
    }
}

contract Create3Proxy {
    constructor() payable {}
    
    function deploy(bytes memory creationCode) public returns (address deployed) {
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
    }
}
