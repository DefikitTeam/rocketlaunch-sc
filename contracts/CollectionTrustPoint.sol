// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract CollectionTrustPoint is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    EIP712Upgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // keccak256("Mint(uint256 _id,address _recipient)")
    bytes32 public constant MINT_TYPEHASH =
        0x63c8ee7239e0c2271d18063690b2e0238194ad8e3196f198c3b7bd8462215136;

    enum TYPE_TRUST_POINT {
        WALLET,
        TOKEN
    }

    struct TrustPoint {
        uint256 id;
        uint256 multiplier;
        string description;
        TYPE_TRUST_POINT trustPointType;
        bool isActive;
    }

    struct TrustPointInitData {
        uint256 id;
        uint256 multiplier;
        string description;
        TYPE_TRUST_POINT trustPointType;
    }

    struct WalletInfo {
        uint256 multiplier;
    }

    struct TokenInfo {
        uint256 multiplier;
    }

    mapping(uint256 => TrustPoint) public trustPoints;
    mapping(address => WalletInfo) public walletInfo;
    mapping(address => TokenInfo) public tokenInfo;

    address public rocketLaunch;

    string private baseURI;
    uint256 public trustPointId;

    event TrustPointAdded(
        uint256 id,
        uint256 multiplier,
        string description,
        TYPE_TRUST_POINT trustPointType
    );

    function initialize(
        string memory _apiUrl,
        address minter,
        address _rocketLaunch,
        TrustPointInitData[] memory initialPoints
    ) public initializer {
        __ERC1155_init(_apiUrl);
        __Ownable_init();
        __AccessControl_init();
        __EIP712_init("CollectionTrustPoint", "1");
        baseURI = _apiUrl;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(MINTER_ROLE, rocketLaunch);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);

        rocketLaunch = _rocketLaunch;

        // Initialize trust points with the provided data
        _initializeTrustPoints(initialPoints);
    }

    function _initializeTrustPoints(
        TrustPointInitData[] memory initialPoints
    ) private {
        uint256[] memory ids = new uint256[](initialPoints.length);
        uint256 highestId = 0;

        for (uint256 i = 0; i < initialPoints.length; i++) {
            TrustPointInitData memory data = initialPoints[i];

            trustPoints[data.id] = TrustPoint({
                id: data.id,
                multiplier: data.multiplier,
                description: data.description,
                trustPointType: data.trustPointType,
                isActive: true
            });

            ids[i] = data.id;

            // Keep track of the highest ID
            if (data.id > highestId) {
                highestId = data.id;
            }

            // Emit individual events for backward compatibility and better indexing
            emit TrustPointAdded(
                data.id,
                data.multiplier,
                data.description,
                data.trustPointType
            );
        }

        // Set trustPointId to the highest ID
        trustPointId = highestId;
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

    function mint(address to, uint256 id) public onlyRole(MINTER_ROLE) {
        require(trustPoints[id].isActive, "NFT: ID does not exist");
        require(balanceOf(to, id) == 0, "NFT: Account already owns this token");
        _mint(to, id, 1, "");
        _updateTrustPoint(to, id);
    }

    function mintWithSignature(uint256 id, bytes memory signature) public {
        require(trustPoints[id].isActive, "NFT: ID does not exist");
        require(
            balanceOf(msg.sender, id) == 0,
            "NFT: Account already owns this token"
        );
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(MINT_TYPEHASH, id, msg.sender))
        );
        require(_checkSignature(signature, digest), "NFT: Invalid signature");
        _mint(msg.sender, id, 1, "");
        _updateTrustPoint(msg.sender, id);
    }

    function addNewTrustPoint(
        uint256 multiplier,
        string memory description,
        TYPE_TRUST_POINT trustPointType
    ) public onlyRole(MINTER_ROLE) {
        trustPointId++;
        trustPoints[trustPointId] = TrustPoint({
            id: trustPointId,
            multiplier: multiplier,
            description: description,
            trustPointType: trustPointType,
            isActive: true
        });

        // Emit event when adding new trust point
        emit TrustPointAdded(
            trustPointId,
            multiplier,
            description,
            trustPointType
        );
    }

    function setBaseURI(
        string memory newuri
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newuri;
    }

    function tokenURI(uint256 id) public view returns (string memory) {
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

    function _updateTrustPoint(address user, uint256 id) private {
        if (trustPoints[id].trustPointType == TYPE_TRUST_POINT.WALLET) {
            _updateTrustPointWallet(user, id);
        } else {
            _updateTrustPointToken(user, id);
        }
    }

    function _updateTrustPointWallet(address user, uint256 id) private {
        walletInfo[user].multiplier += trustPoints[id].multiplier;
    }

    function _updateTrustPointToken(address token, uint256 id) private {
        tokenInfo[token].multiplier += trustPoints[id].multiplier;
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override {
        revert("Not allowed");
    }
}
