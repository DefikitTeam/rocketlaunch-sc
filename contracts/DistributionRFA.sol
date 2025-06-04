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

    enum CampaignType {
        NONE, // 0 - Default/uninitialized
        WEEKLY, // 1
        MONTHLY, // 2
        QUARTERLY, // 3
        YEARLY // 4
    }

    struct WeeklyRetroActive {
        bytes32 merkleRoot;
        uint256 amount; // amount Bera (native token)
        uint256 timestamp;
        bool isActive;
        string description;
    }
    struct MonthlyRetroActive {
        bytes32 merkleRoot;
        uint256 amount; // amount Bera (native token)
        uint256 timestamp;
        bool isActive;
        string description;
    }
    struct QuarterlyRetroActive {
        bytes32 merkleRoot;
        uint256 amount; // amount Bera (native token)
        uint256 timestamp;
        bool isActive;
        string description;
    }

    struct YearlyRetroActive {
        bytes32 merkleRoot;
        uint256 amount; // amount Bera (native token)
        uint256 timestamp;
        bool isActive;
        string description;
    }

    struct UserInfo {
        uint256 claimedAmount;
        uint256 claimTimestamp;
        bool hasClaimed;
    }

    mapping(uint256 => MonthlyRetroActive) public monthlyRetroActive;
    mapping(uint256 => WeeklyRetroActive) public weeklyRetroActive;
    mapping(uint256 => QuarterlyRetroActive) public quarterlyRetroActive;
    mapping(uint256 => YearlyRetroActive) public yearlyRetroActive;

    mapping(uint256 => mapping(address => UserInfo)) public userWeeklyClaimed;
    mapping(uint256 => mapping(address => UserInfo)) public userMonthlyClaimed;
    mapping(uint256 => mapping(address => UserInfo))
        public userQuarterlyClaimed;
    mapping(uint256 => mapping(address => UserInfo)) public userYearlyClaimed;

    address private operator; // operator is wallet can call next round

    // Constants for security
    uint256 public constant MAX_MERKLE_PROOF_LENGTH = 32; // Maximum merkle proof array length
    uint256 public constant MAX_CLAIM_AMOUNT_WEEKLY = 50 ether; // Maximum single claim amount
    uint256 public constant MAX_CLAIM_AMOUNT_MONTHLY = 100 ether; // Maximum single claim amount
    uint256 public constant MAX_CLAIM_AMOUNT_QUARTERLY = 600 ether; // Maximum single claim amount
    uint256 public constant MAX_CLAIM_AMOUNT_YEARLY = 1000 ether; // Maximum single claim amount

    // Weekly Campaign Events
    event WeeklyCampaignCreated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event WeeklyCampaignUpdated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event WeeklyRetroActiveClaimed(
        address indexed user,
        uint256 indexed timestamp,
        uint256 amount
    );

    // Monthly Campaign Events
    event MonthlyCampaignCreated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event MonthlyCampaignUpdated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event MonthlyRetroActiveClaimed(
        address indexed user,
        uint256 indexed timestamp,
        uint256 amount
    );

    // Quarterly Campaign Events
    event QuarterlyCampaignCreated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event QuarterlyCampaignUpdated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event QuarterlyRetroActiveClaimed(
        address indexed user,
        uint256 indexed timestamp,
        uint256 amount
    );

    // Yearly Campaign Events
    event YearlyCampaignCreated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event YearlyCampaignUpdated(
        uint256 indexed timestamp,
        bytes32 indexed merkleRoot,
        uint256 amount,
        string description
    );

    event YearlyRetroActiveClaimed(
        address indexed user,
        uint256 indexed timestamp,
        uint256 amount
    );

    // General Events
    event OperatorUpdated(
        address indexed oldOperator,
        address indexed newOperator
    );

    event EmergencyWithdrawal(address indexed owner, uint256 amount);

    event ContractFunded(address indexed sender, uint256 amount);

    // User tracking events
    event UserClaimInfo(
        address indexed user,
        uint256 indexed timestamp,
        uint256 amount,
        CampaignType campaignType
    );

    // Legacy events for backward compatibility (deprecated)
    event NewCampaign(uint256 amount, uint256 timestamp, string description);
    event UpdateCampaign(uint256 amount, uint256 timestamp, string description);
    event ClaimRetroActive(
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    // Receive native token function
    receive() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

    fallback() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

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
        address oldOperator = operator;
        operator = _operator;
        emit OperatorUpdated(oldOperator, _operator);
    }

    /**
     * @dev Update weekly retro active info
     */
    function updateWeeklyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) public onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            weeklyRetroActive[_timestamp].amount > 0,
            "Airdrop: campaign not found"
        );
        weeklyRetroActive[_timestamp].amount = _amount;
        weeklyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        weeklyRetroActive[_timestamp].description = _description;
        emit WeeklyCampaignUpdated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Create new weekly retro active info
     */
    function createNewWeeklyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) external onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merkleRoot != bytes32(0), "Invalid merkle root");

        require(
            weeklyRetroActive[_timestamp].isActive == false,
            "Airdrop: campaign already exists"
        );

        weeklyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        weeklyRetroActive[_timestamp].amount = _amount;
        weeklyRetroActive[_timestamp].description = _description;
        weeklyRetroActive[_timestamp].isActive = true;
        emit WeeklyCampaignCreated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Update monthly retro active info
     */
    function updateMonthlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) public onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            monthlyRetroActive[_timestamp].amount > 0,
            "Airdrop: campaign not found"
        );
        monthlyRetroActive[_timestamp].amount = _amount;
        monthlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        monthlyRetroActive[_timestamp].description = _description;
        emit MonthlyCampaignUpdated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Create new monthly retro active info
     */
    function createNewMonthlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) external onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merkleRoot != bytes32(0), "Invalid merkle root");

        require(
            monthlyRetroActive[_timestamp].isActive == false,
            "Airdrop: campaign already exists"
        );

        monthlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        monthlyRetroActive[_timestamp].amount = _amount;
        monthlyRetroActive[_timestamp].description = _description;
        monthlyRetroActive[_timestamp].isActive = true;
        emit MonthlyCampaignCreated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Update quarterly retro active info
     */
    function updateQuarterlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) public onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            quarterlyRetroActive[_timestamp].amount > 0,
            "Airdrop: campaign not found"
        );
        quarterlyRetroActive[_timestamp].amount = _amount;
        quarterlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        quarterlyRetroActive[_timestamp].description = _description;
        emit QuarterlyCampaignUpdated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Create new quarterly retro active info
     */
    function createNewQuarterlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) external onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merkleRoot != bytes32(0), "Invalid merkle root");

        require(
            quarterlyRetroActive[_timestamp].isActive == false,
            "Airdrop: campaign already exists"
        );

        quarterlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        quarterlyRetroActive[_timestamp].amount = _amount;
        quarterlyRetroActive[_timestamp].description = _description;
        quarterlyRetroActive[_timestamp].isActive = true;
        emit QuarterlyCampaignCreated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Update yearly retro active info
     */
    function updateYearlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) public onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            yearlyRetroActive[_timestamp].amount > 0,
            "Airdrop: campaign not found"
        );
        yearlyRetroActive[_timestamp].amount = _amount;
        yearlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        yearlyRetroActive[_timestamp].description = _description;
        emit YearlyCampaignUpdated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    /**
     * @dev Create new yearly retro active info
     */
    function createNewYearlyRetroActive(
        bytes32 _merkleRoot,
        uint256 _amount,
        uint256 _timestamp,
        string calldata _description
    ) external onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merkleRoot != bytes32(0), "Invalid merkle root");

        require(
            yearlyRetroActive[_timestamp].isActive == false,
            "Airdrop: campaign already exists"
        );

        yearlyRetroActive[_timestamp].merkleRoot = _merkleRoot;
        yearlyRetroActive[_timestamp].amount = _amount;
        yearlyRetroActive[_timestamp].description = _description;
        yearlyRetroActive[_timestamp].isActive = true;
        emit YearlyCampaignCreated(
            _timestamp,
            _merkleRoot,
            _amount,
            _description
        );
    }

    // claim tokens from Weekly Campaign for token
    function claimWeeklyRetroActiveForToken(
        uint256 _timestamp,
        uint256 _amount,
        address _token,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= MAX_CLAIM_AMOUNT_WEEKLY, "Amount exceeds maximum");
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            weeklyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userWeeklyClaimed[_timestamp][_token];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                weeklyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, _token)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit WeeklyRetroActiveClaimed(_token, _timestamp, _amount);
        emit UserClaimInfo(_token, _timestamp, _amount, CampaignType.WEEKLY);
    }

    // claim tokens from Weekly Campaign for Wallet
    function claimWeeklyRetroActive(
        uint256 _timestamp,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= MAX_CLAIM_AMOUNT_WEEKLY, "Amount exceeds maximum");
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            weeklyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userWeeklyClaimed[_timestamp][msg.sender];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                weeklyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, msg.sender)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit WeeklyRetroActiveClaimed(msg.sender, _timestamp, _amount);
        emit UserClaimInfo(
            msg.sender,
            _timestamp,
            _amount,
            CampaignType.WEEKLY
        );
    }

    // claim tokens from Monthly Campaign for token
    function claimMonthlyRetroActiveForToken(
        uint256 _timestamp,
        uint256 _amount,
        address _token,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused onlyOperator {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= MAX_CLAIM_AMOUNT_MONTHLY, "Amount exceeds maximum");
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            monthlyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userMonthlyClaimed[_timestamp][_token];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                monthlyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, _token)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit MonthlyRetroActiveClaimed(_token, _timestamp, _amount);
        emit UserClaimInfo(_token, _timestamp, _amount, CampaignType.MONTHLY);
    }

    // claim tokens from Monthly Campaign for Wallet
    function claimMonthlyRetroActive(
        uint256 _timestamp,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= MAX_CLAIM_AMOUNT_MONTHLY, "Amount exceeds maximum");
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            monthlyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userMonthlyClaimed[_timestamp][msg.sender];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                monthlyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, msg.sender)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit MonthlyRetroActiveClaimed(msg.sender, _timestamp, _amount);
        emit UserClaimInfo(
            msg.sender,
            _timestamp,
            _amount,
            CampaignType.MONTHLY
        );
    }

    // claim tokens from Quarterly Campaign for token
    function claimQuarterlyRetroActiveForToken(
        uint256 _timestamp,
        uint256 _amount,
        address _token,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _amount <= MAX_CLAIM_AMOUNT_QUARTERLY,
            "Amount exceeds maximum"
        );
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            quarterlyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userQuarterlyClaimed[_timestamp][_token];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                quarterlyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, _token)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit QuarterlyRetroActiveClaimed(_token, _timestamp, _amount);
        emit UserClaimInfo(
            _token,
            _timestamp,
            _amount,
            CampaignType.QUARTERLY
        );
    }

    // claim tokens from Quarterly Campaign
    function claimQuarterlyRetroActive(
        uint256 _timestamp,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _amount <= MAX_CLAIM_AMOUNT_QUARTERLY,
            "Amount exceeds maximum"
        );
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            quarterlyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userQuarterlyClaimed[_timestamp][
            msg.sender
        ];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                quarterlyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, msg.sender)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit QuarterlyRetroActiveClaimed(msg.sender, _timestamp, _amount);
        emit UserClaimInfo(
            msg.sender,
            _timestamp,
            _amount,
            CampaignType.QUARTERLY
        );
    }

    // claim tokens from Yearly Campaign
    function claimYearlyRetroActive(
        uint256 _timestamp,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= MAX_CLAIM_AMOUNT_YEARLY, "Amount exceeds maximum");
        require(
            _merkleProof.length <= MAX_MERKLE_PROOF_LENGTH,
            "Merkle proof too long"
        );
        require(
            yearlyRetroActive[_timestamp].isActive == true,
            "Campaign does not exist"
        );
        UserInfo storage userInfo = userYearlyClaimed[_timestamp][msg.sender];
        require(userInfo.hasClaimed == false, "Airdrop: already claimed");
        require(
            MerkleProofUpgradeable.verify(
                _merkleProof,
                yearlyRetroActive[_timestamp].merkleRoot,
                _leaf(_amount, msg.sender)
            ),
            "Airdrop: Invalid proof"
        );
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        // Update user info
        userInfo.claimedAmount = _amount;
        userInfo.claimTimestamp = block.timestamp;
        userInfo.hasClaimed = true;

        // Send Bera to user
        payable(msg.sender).transfer(_amount);
        emit YearlyRetroActiveClaimed(msg.sender, _timestamp, _amount);
        emit UserClaimInfo(
            msg.sender,
            _timestamp,
            _amount,
            CampaignType.YEARLY
        );
    }

    function _leaf(
        uint256 amount,
        address account
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, amount));
    }

    function emergency(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );
        payable(owner()).transfer(_amount);
        emit EmergencyWithdrawal(owner(), _amount);
    }

    /**
     * @dev Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
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

    // function pendingRetroActive(
    //     address _account,
    //     uint256 _timestamp,
    //     uint256 _amount,
    //     bytes32[] calldata _merkleProof,
    //     CampaignType _campaignType
    // ) public view returns (uint256) {
    //     // Input validation
    //     if (_amount == 0) return 0;

    //     // Check if already claimed
    //     bytes32 merkleRoot;
    //     bool isActive;

    //     // Get campaign data based on type
    //     if (_campaignType == CampaignType.WEEKLY) {
    //         merkleRoot = weeklyRetroActive[_timestamp].merkleRoot;
    //         isActive = weeklyRetroActive[_timestamp].isActive;
    //         if (userWeeklyClaimed[_timestamp][_account].hasClaimed) return 0;
    //     } else if (_campaignType == CampaignType.MONTHLY) {
    //         merkleRoot = monthlyRetroActive[_timestamp].merkleRoot;
    //         isActive = monthlyRetroActive[_timestamp].isActive;
    //         if (userMonthlyClaimed[_timestamp][_account].hasClaimed) return 0;
    //     } else if (_campaignType == CampaignType.QUARTERLY) {
    //         merkleRoot = quarterlyRetroActive[_timestamp].merkleRoot;
    //         isActive = quarterlyRetroActive[_timestamp].isActive;
    //         if (userQuarterlyClaimed[_timestamp][_account].hasClaimed) return 0;
    //     } else if (_campaignType == CampaignType.YEARLY) {
    //         merkleRoot = yearlyRetroActive[_timestamp].merkleRoot;
    //         isActive = yearlyRetroActive[_timestamp].isActive;
    //         if (userYearlyClaimed[_timestamp][_account].hasClaimed) return 0;
    //     } else {
    //         return 0; // Invalid campaign type
    //     }

    //     // Check if campaign is active
    //     if (!isActive) return 0;

    //     // Verify merkle proof
    //     if (
    //         !MerkleProofUpgradeable.verify(
    //             _merkleProof,
    //             merkleRoot,
    //             _leaf(_amount, _account)
    //         )
    //     ) {
    //         return 0;
    //     }
    //     return _amount;
    // }

    // /**
    //  * @dev Batch check multiple users' claim status for a campaign
    //  * @dev Gas-efficient way to check multiple addresses at once
    //  */
    // function batchCheckClaimStatus(
    //     address[] calldata _accounts,
    //     uint256 _timestamp,
    //     CampaignType _campaignType
    // ) external view returns (bool[] memory claimed) {
    //     require(_accounts.length <= 100, "Too many accounts to check"); // Prevent gas issues

    //     claimed = new bool[](_accounts.length);

    //     for (uint256 i = 0; i < _accounts.length; i++) {
    //         if (_campaignType == CampaignType.WEEKLY) {
    //             claimed[i] = userWeeklyClaimed[_timestamp][_accounts[i]].hasClaimed;
    //         } else if (_campaignType == CampaignType.MONTHLY) {
    //             claimed[i] = userMonthlyClaimed[_timestamp][_accounts[i]].hasClaimed;
    //         } else if (_campaignType == CampaignType.QUARTERLY) {
    //             claimed[i] = userQuarterlyClaimed[_timestamp][_accounts[i]].hasClaimed;
    //         } else if (_campaignType == CampaignType.YEARLY) {
    //             claimed[i] = userYearlyClaimed[_timestamp][_accounts[i]].hasClaimed;
    //         }
    //     }
    // }

    // /**
    //  * @dev Get user claim info for specific campaign and user
    //  */
    // function getUserClaimInfo(
    //     address _account,
    //     uint256 _timestamp,
    //     CampaignType _campaignType
    // ) external view returns (
    //     uint256 claimedAmount,
    //     uint256 claimTimestamp,
    //     bool hasClaimed
    // ) {
    //     UserInfo memory userInfo;

    //     if (_campaignType == CampaignType.WEEKLY) {
    //         userInfo = userWeeklyClaimed[_timestamp][_account];
    //     } else if (_campaignType == CampaignType.MONTHLY) {
    //         userInfo = userMonthlyClaimed[_timestamp][_account];
    //     } else if (_campaignType == CampaignType.QUARTERLY) {
    //         userInfo = userQuarterlyClaimed[_timestamp][_account];
    //     } else if (_campaignType == CampaignType.YEARLY) {
    //         userInfo = userYearlyClaimed[_timestamp][_account];
    //     }

    //     return (userInfo.claimedAmount, userInfo.claimTimestamp, userInfo.hasClaimed);
    // }
}
