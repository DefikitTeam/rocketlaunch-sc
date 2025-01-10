// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract BeraBearNFT is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    EIP712Upgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public totalSupply;
    string private baseURI;

    // keccak256("Mint(uint256 _id,address _recipient)")
    bytes32 public constant MINT_TYPEHASH =
        0x63c8ee7239e0c2271d18063690b2e0238194ad8e3196f198c3b7bd8462215136;

    function initialize(
        string memory _apiUrl,
        address minter
    ) public initializer {
        __ERC1155_init(_apiUrl);
        __Ownable_init();
        __AccessControl_init();
        __EIP712_init("bera bear", "1");
        baseURI = _apiUrl;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        totalSupply = 1;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mint(address to, uint256 id, bytes memory signature) public {
        require(id <= totalSupply, "NFT: ID does not exist");
        require(balanceOf(to, id) == 0, "NFT: Account already owns this token");
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(MINT_TYPEHASH, id, to))
        );
        require(_checkSignature(signature, digest), "NFT: Invalid signature");
        _mint(to, id, 1, "");
    }

    struct MintBatchParams {
        address to;
        uint256 id;
        bytes signature;
    }

    function mintBatch(MintBatchParams[] memory params) public {
        require(params.length > 0, "NFT: No parameters provided");
        for (uint256 i = 0; i < params.length; i++) {
            require(params[i].id <= totalSupply, "NFT: ID does not exist");
            require(
                balanceOf(params[i].to, params[i].id) == 0,
                "NFT: Account already owns this token"
            );
            bytes32 digest = _hashTypedDataV4(
                keccak256(abi.encode(MINT_TYPEHASH, params[i].id, params[i].to))
            );
            require(
                _checkSignature(params[i].signature, digest),
                "NFT: Invalid signature"
            );
            _mint(params[i].to, params[i].id, 1, "");
        }
    }

    function activeNewNFT(uint256 number) public onlyRole(DEFAULT_ADMIN_ROLE) {
        totalSupply += number;
    }

    function setBaseURI(
        string memory newuri
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newuri;
    }

    function tokenURI(uint256 id) public view returns (string memory) {
        require(
            id <= totalSupply,
            "ERC1155Metadata: URI query for nonexistent token"
        );
        return
            string(abi.encodePacked(baseURI, StringsUpgradeable.toString(id)));
    }

    function uri(uint256 id) public view override returns (string memory) {
        return tokenURI(id);
    }

    function _checkSignature(
        bytes memory signature,
        bytes32 digest
    ) private view returns (bool) {
        address checkAdress = ECDSAUpgradeable.recover(digest, signature);
        return hasRole(MINTER_ROLE, checkAdress);
    }
}
