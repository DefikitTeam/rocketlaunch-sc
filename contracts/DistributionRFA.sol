//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract DistributionRFA is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    struct MonthlyRetroActive {
        bytes32 merkleRoot;
        uint256 amount; // amount Bera (native token)
        string description;
    }

    mapping(uint256 => MonthlyRetroActive) public monthlyRetroActive;
    uint256 public nonce; // nonce: count campaign
    address private operator; // operator is wallet can call next round

    mapping(uint256 => mapping(address => uint256)) public userClaimed;

    event NewCampaign(uint256 amount, uint256 nonce, string description);

    event UpdateCampaign(uint256 amount, uint256 nonce, string description);

    event ClaimRetroActive(
        address indexed sender,
        uint256 amount,
        uint256 nonce
    );

    // Receive native token function
    receive() external payable {}

    fallback() external payable {}

    /* ========== CONSTRUCTOR ========== */
    /**
     * @dev constructor the contract
     * @param _operator Wallet is operator
     * @notice Each parameters should be set carefully since it's not modifiable for each round
     */
    function initialize(address _operator) public initializer {
        require(
            _operator != address(0),
            "DistributionRFA: Invalid operator address"
        );
        __Ownable_init();
        nonce = 0; // Start at 0 so first campaign is nonce 1
        operator = _operator;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    /**
     * @dev This function is designed to pause invest activity on this contract in case emergency happen
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract & let everything be normal
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev setup operator: can call some function
     */
    function setupOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Invalid operator address");
        operator = _operator;
    }

    /**
     * @dev Update monthly retro active info
     */
    function updateMonthlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _nonce,
        string calldata _description
    ) public onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_nonce <= nonce && _nonce > 0, "Invalid nonce");
        require(
            monthlyRetroActive[_nonce].amount > 0,
            "Airdrop: campaign not found"
        );
        monthlyRetroActive[_nonce].amount = _amount;
        monthlyRetroActive[_nonce].merkleRoot = _merkleRoot;
        monthlyRetroActive[_nonce].description = _description;
        emit UpdateCampaign(_amount, _nonce, _description);
    }

    /**
     * @dev Create new monthly retro active info
     */
    function createNewMonthlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        string calldata _description
    ) external onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merkleRoot != bytes32(0), "Invalid merkle root");

        ++nonce; // Increment first, so first campaign is nonce 1

        require(
            monthlyRetroActive[nonce].amount == 0,
            "Airdrop: campaign already exists"
        );

        monthlyRetroActive[nonce].merkleRoot = _merkleRoot;
        monthlyRetroActive[nonce].amount = _amount;
        monthlyRetroActive[nonce].description = _description;
        emit NewCampaign(_amount, nonce, _description);
    }

    // claim tokens from Campaign
    function claim(
        uint256 _nonce,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(_nonce <= nonce && _nonce > 0, "Invalid nonce");
        require(
            monthlyRetroActive[_nonce].amount > 0,
            "Campaign does not exist"
        );
        require(
            userClaimed[_nonce][msg.sender] == 0,
            "Airdrop: already claimed"
        );
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                monthlyRetroActive[_nonce].merkleRoot,
                _leaf(_amount, msg.sender)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update state before external call (CEI pattern)
        userClaimed[_nonce][msg.sender] = _amount;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit ClaimRetroActive(msg.sender, _amount, _nonce);
    }

    function _leaf(
        uint256 amount,
        address account
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, amount));
    }

    function pendingRetroActive(
        address _account,
        uint256 _nonce,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) public view returns (uint256) {
        // Check if nonce is valid (exists and not in future)
        if (_nonce > nonce || _nonce == 0) return 0;

        // Check if campaign exists
        if (monthlyRetroActive[_nonce].amount == 0) return 0;

        // Check if already claimed
        if (userClaimed[_nonce][_account] > 0) return 0;

        // Verify merkle proof
        if (
            !MerkleProofUpgradeable.verify(
                _merkleProof,
                monthlyRetroActive[_nonce].merkleRoot,
                _leaf(_amount, _account)
            )
        ) {
            return 0;
        }
        return _amount;
    }

    function emergency(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );
        payable(owner()).transfer(_amount);
    }

    /**
     * @dev Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Check if user has claimed for a specific nonce
     */
    function hasClaimed(
        uint256 _nonce,
        address _account
    ) external view returns (bool) {
        return userClaimed[_nonce][_account] > 0;
    }

    /**
     * @dev Throws if the sender is not the operator.
     */
    function _checkOperator() internal view virtual {
        require(
            owner() == _msgSender() || operator == _msgSender(),
            "Caller is not owner or operator"
        );
    }
}
