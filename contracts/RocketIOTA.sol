// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./RocketToken.sol";
import "./libraries/TokenLibrary.sol";

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);
}

interface INonfungiblePositionManager {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external returns (address pool);

    function mint(
        TokenLibrary.MintParams memory params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

interface IRocketTokenFactory {
    function createNewToken(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_
    ) external returns (address);
}

contract RocketIOTA is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;

    uint256 public constant BASE_DENOMINATOR = 10000;
    address public constant DEAD_ADDR =
        0x000000000000000000000000000000000000dEaD;

    uint256 internal PERCENT_RELEASE_AT_TGE;
    uint256 internal PERCENT_RELEASE;

    uint256 public MINIMUM_CAP;

    uint256 internal DURATION;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public BLOCK_INTERVAL; // 2s = 20000

    address public WETH;

    uint256 internal constant X96 = 79228162514264337593543950336;

    enum StatusPool {
        INACTIVE,
        ACTIVE,
        FULL,
        FINISHED,
        FAIL,
        COMPELETED
    }

    struct Pool {
        // limit purchase of Pool
        uint256 tokenPerPurchase; // fixed token per purchase
        uint256 maxRepeatPurchase; // max repeat purchase
        uint256 totalBatch; // total batch
        // limit time
        uint256 startTime;
        uint256 endTime;
        uint256 minDurationSell;
        uint256 maxDurationSell;
        // current status
        uint256 raisedInETH; // total raised ETH
        uint256 soldBatch; // total sold batch
        uint256 reserveETH;
        uint256 reserveBatch;
        StatusPool status;
        // referrer
        uint256 totalReferrerBond;
        uint256 totalBatchAvailable; // total batch available
    }

    struct PoolInfo {
        uint256 fixedCapETH; // target raise ETH
        uint256 totalSupplyToken; // total token supply
        uint256 tokenForAirdrop; // token for airdrop
        uint256 tokenForFarm; // token for farm
        uint256 tokenForSale; // token for sale
        uint256 tokenForAddLP; // token for add LP
        string metadata;
    }

    struct Vesting {
        uint256 startTime;
        bool isExist;
    }

    // Info of each farm.
    struct Farm {
        uint256 rewardPerBlock; // Reward token per block.
        uint256 lastRewardBlock; // Last block number that XOXs distribution occurs.
        uint256 accTokenPerShare; // Accumulated token per share, times 1e12. See below.
        bool isDisable; // disable farm
    }

    struct User {
        uint256 balance; // number batch bought
        uint256 balanceSold; // calculate 50% sold
        uint256 ethBought;
        uint256 rewardFarm;
        bool isClaimed;
        uint256 rewardDebt;
        uint256 tokenClaimed;
        bool isClaimedFarm;
        uint256 referrerReward;
        uint256 referrerBond;
    }

    mapping(address => Pool) public pools;
    mapping(address => PoolInfo) public poolInfos;
    mapping(address => Farm) public farms;
    mapping(address => mapping(address => User)) public users;

    address internal router;
    address internal platformAddress;
    uint256 internal platformFee;
    address internal feeAddress;
    uint256 internal fee;

    // counter buyer by pool
    mapping(address => address[]) public buyerArr;
    mapping(address => mapping(address => bool)) public boughtCheck;

    // check owner token
    mapping(address => address) public ownerToken;

    mapping(address => uint256) public counterSoldUsers;
    mapping(address => uint256) internal totalSellTax;

    mapping(address => Vesting) public vesting;

    mapping(address => bool) public completedTransfer;

    address public rocketTokenFactory;
    // Event for create new Token
    event CreateToken(
        address indexed token,
        address indexed owner,
        string name,
        string symbol,
        uint8 decimals,
        uint256 totalSupply
    );

    // Event for pool creation
    event ActivePool(
        address indexed pool,
        uint256 tokenForAirdrop,
        uint256 tokenForFarm,
        uint256 tokenForSale,
        uint256 tokenForLiquidity,
        uint256 capInETH,
        uint256 totalBatch,
        string metadata,
        uint256 startTime,
        uint256 endTime,
        uint256 minDurationSell
    );

    // Event for token purchase
    event Bought(
        address indexed pool,
        address indexed buyer,
        uint256 amount,
        uint256 paidETH,
        address referrer
    );

    // Event for token sale
    event Sold(
        address indexed pool,
        address indexed seller,
        uint256 amount,
        uint256 receivedETH
    );

    // Event for token refund
    event Refund(
        address indexed pool,
        address indexed buyer,
        uint256 amount,
        uint256 receivedETH
    );

    // Event for pool finalization
    event Finalized(address indexed pool);

    // Event Claimed token
    event Claimed(address indexed pool, address indexed user, uint256 amount);

    // Event Full pool
    event FullPool(address indexed pool);

    // Event Fail pool
    event FailPool(address indexed pool);

    // Event COMPLETED pool
    event CompletedPool(address indexed pool);

    function initialize(
        address _platformAddress,
        uint256 _platformFee,
        address _feeAddress,
        uint256 _fee,
        address _router,
        uint256 _blockInterval,
        address _WETH
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, _platformAddress);

        platformAddress = _platformAddress;
        platformFee = _platformFee;
        feeAddress = _feeAddress;
        fee = _fee;
        router = _router;
        BLOCK_INTERVAL = _blockInterval;
        WETH = _WETH;
        MINIMUM_CAP = 10_000 * 10 ** 18; // 10,000 IOTA
        DURATION = 8 hours;

        PERCENT_RELEASE_AT_TGE = 4000;
        PERCENT_RELEASE = 2000;
    }

    modifier enoughFee() {
        require(msg.value >= platformFee, "plat fee");
        _;
    }

    // Receive native token function
    receive() external payable {}

    fallback() external payable {}

    function setRocketTokenFactory(
        address _rocketTokenFactory
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rocketTokenFactory = _rocketTokenFactory;
    }

    function setConfig(
        uint256 _percentReleaseAtTGE,
        uint256 _percentRelease,
        uint256 _minimumCap,
        uint256 _duration,
        uint256 _blockInterval
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        PERCENT_RELEASE_AT_TGE = _percentReleaseAtTGE;
        PERCENT_RELEASE = _percentRelease;
        MINIMUM_CAP = _minimumCap;
        DURATION = _duration;
        BLOCK_INTERVAL = _blockInterval;
    }

    function setFee(uint256 _platformFee, uint256 _fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        platformFee = _platformFee;
        fee = _fee;
    }

    // function createToken in RocketLauch
    function createRocketToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) external {
        address newToken = IRocketTokenFactory(rocketTokenFactory)
            .createNewToken(name, symbol, totalSupply);
        ownerToken[newToken] = msg.sender;
        emit CreateToken(
            newToken,
            msg.sender,
            name,
            symbol,
            decimals,
            totalSupply
        );
    }

    struct ActivePoolParams {
        address token;
        uint256 fixedCapETH;
        uint256 tokenForAirdrop;
        uint256 tokenForFarm;
        uint256 tokenForSale;
        uint256 tokenForAddLP;
        // batch purchase
        uint256 tokenPerPurchase;
        uint256 maxRepeatPurchase;
        // limit time
        uint256 startTime;
        uint256 minDurationSell;
        uint256 maxDurationSell;
        // metadata
        string metadata;
    }

    // Function to active Pool
    function activePool(
        ActivePoolParams memory params
    ) public payable enoughFee {
        require(ownerToken[params.token] == msg.sender, "Invalid owner token");
        Pool storage pool = pools[params.token];
        require(params.startTime > block.timestamp, "Invalid startTime");
        require(
            params.maxDurationSell > params.minDurationSell,
            "Invalid time"
        );
        require(pool.status == StatusPool.INACTIVE, "Pool already active");
        uint256 balanceToken = IERC20Upgradeable(params.token).balanceOf(
            address(this)
        );
        uint256 totalSupply = IERC20Upgradeable(params.token).totalSupply();
        require(
            balanceToken == totalSupply,
            "Contract need to have all token."
        );
        require(
            totalSupply ==
                params.tokenForAirdrop +
                    params.tokenForFarm +
                    params.tokenForSale +
                    params.tokenForAddLP,
            "Invalid totalSupplyToken"
        );
        require(
            params.fixedCapETH >= MINIMUM_CAP,
            "Invalid fixedCapETH, must be greater than 2 ETH"
        );
        require(
            params.tokenForSale >= totalSupply.mul(70).div(100),
            "Invalid tokenForSale, must be greater than 70% of totalSupply"
        );
        require(
            params.tokenForAddLP >= totalSupply.mul(10).div(100),
            "Invalid tokenForAddLP, must be greater than 10% of totalSupply"
        );
        require(
            params.tokenForAirdrop <= totalSupply.mul(5).div(100),
            "Invalid tokenForAirdrop, must be less than 5% of totalSupply"
        );
        require(
            params.tokenForFarm <= totalSupply.mul(5).div(100),
            "Invalid tokenForFarm, must be less than 5% of totalSupply"
        );

        // setup PoolInfo
        PoolInfo storage poolInfo = poolInfos[params.token];
        poolInfo.fixedCapETH = params.fixedCapETH;
        poolInfo.totalSupplyToken = totalSupply;
        poolInfo.tokenForAirdrop = params.tokenForAirdrop;
        poolInfo.tokenForFarm = params.tokenForFarm;
        poolInfo.tokenForSale = params.tokenForSale;
        poolInfo.tokenForAddLP = params.tokenForAddLP;
        poolInfo.metadata = params.metadata;

        // limit purchase of Pool
        pool.tokenPerPurchase = params.tokenPerPurchase;
        pool.maxRepeatPurchase = params.maxRepeatPurchase;
        pool.totalBatch = params.tokenForSale.div(params.tokenPerPurchase);
        pool.totalBatchAvailable = pool.totalBatch;
        // limit time
        pool.startTime = params.startTime;
        pool.endTime = params.startTime.add(params.maxDurationSell);
        pool.minDurationSell = params.minDurationSell;
        pool.maxDurationSell = params.maxDurationSell;
        // current status
        pool.raisedInETH = 0;
        pool.soldBatch = 0;
        pool.reserveETH = params.fixedCapETH;
        pool.reserveBatch = pool.totalBatch.mul(2); // need multiply 2 for fomula
        pool.status = StatusPool.ACTIVE;
        // setup farm
        Farm storage farm = farms[params.token];
        farm.rewardPerBlock = params.tokenForFarm.div(
            params.maxDurationSell.mul(BASE_DENOMINATOR).div(BLOCK_INTERVAL)
        ); // = tokenForFarm / durationBlock
        farm.lastRewardBlock = block.number;
        farm.accTokenPerShare = 0;

        payable(platformAddress).transfer(platformFee);
        emit ActivePool(
            params.token,
            params.tokenForAirdrop,
            params.tokenForFarm,
            params.tokenForSale,
            params.tokenForAddLP,
            params.fixedCapETH,
            pool.totalBatch,
            params.metadata,
            params.startTime,
            pool.endTime,
            pool.minDurationSell
        );
    }

    // Function to buy Token with ETH
    function buy(
        address poolAddress,
        uint256 numberBatch,
        uint256 maxAmountETH,
        address referrer
    ) public payable nonReentrant {
        Pool storage pool = pools[poolAddress];
        require(numberBatch > 0, "Invalid number bond, can't be 0");
        require(
            pool.status == StatusPool.ACTIVE,
            "Pool not active or full or finished"
        );
        require(referrer != msg.sender, "Invalid referrer");
        require(maxAmountETH == msg.value, "maxAmountETH != msg.value");
        require(
            numberBatch <= pool.maxRepeatPurchase,
            "Exceed max repeat purchase"
        );
        require(
            block.timestamp >= pool.startTime &&
                block.timestamp <= pool.endTime,
            "Invalid time"
        );
        uint256 maxBatchCurrent = getMaxBatchCurrent(poolAddress);
        require(
            maxBatchCurrent >= pool.soldBatch.add(numberBatch),
            "Exceed max bond current, please wait for next bond"
        );
        require(
            numberBatch <= pool.totalBatch.sub(pool.soldBatch),
            "Exceed total batch"
        );

        uint256 amountETH = getAmountIn(
            numberBatch,
            pool.reserveETH,
            pool.reserveBatch
        );
        require(maxAmountETH >= amountETH, "Insufficient output ETH");
        // updateFarmingPool
        updateFarmingPool(poolAddress);
        User storage user = users[msg.sender][poolAddress];
        if (user.balance > 0) {
            // Calculate farming reward
            uint256 reward = user
                .balance
                .mul(farms[poolAddress].accTokenPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (reward > 0) {
                user.rewardFarm = user.rewardFarm.add(reward);
            }
        }

        // update pool info
        pool.reserveETH = pool.reserveETH.add(amountETH);
        pool.reserveBatch = pool.reserveBatch.sub(numberBatch);
        pool.soldBatch = pool.soldBatch.add(numberBatch);
        pool.raisedInETH = pool.raisedInETH.add(amountETH);
        // update user info
        user.balance = user.balance.add(numberBatch);
        user.ethBought = user.ethBought.add(amountETH);
        user.rewardDebt = user
            .balance
            .mul(farms[poolAddress].accTokenPerShare)
            .div(1e12);
        // need add user to array
        if (!boughtCheck[poolAddress][msg.sender]) {
            buyerArr[poolAddress].push(msg.sender);
            boughtCheck[poolAddress][msg.sender] = true;
        }
        if (referrer != address(0)) {
            users[referrer][poolAddress].referrerBond = users[referrer][
                poolAddress
            ].referrerBond.add(numberBatch);
            pool.totalReferrerBond = pool.totalReferrerBond.add(numberBatch);
        }
        emit Bought(poolAddress, msg.sender, numberBatch, amountETH, referrer);
        if (pool.soldBatch == pool.totalBatch) {
            pool.status = StatusPool.FULL;
            emit FullPool(poolAddress);
        }
        if (maxAmountETH > amountETH) {
            payable(msg.sender).transfer(maxAmountETH.sub(amountETH));
        }
    }

    struct LaunchPoolParams {
        // token
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        // active pool
        uint256 fixedCapETH;
        uint256 tokenForAirdrop;
        uint256 tokenForFarm;
        uint256 tokenForSale;
        uint256 tokenForAddLP;
        // batch purchase
        uint256 tokenPerPurchase;
        uint256 maxRepeatPurchase;
        // limit time
        uint256 startTime;
        uint256 minDurationSell;
        uint256 maxDurationSell;
        // metadata
        string metadata;
        // buy
        uint256 numberBatch;
        uint256 maxAmountETH;
        address referrer;
    }

    function launchPool(
        LaunchPoolParams memory params
    ) public payable enoughFee {
        address newToken = IRocketTokenFactory(rocketTokenFactory)
            .createNewToken(params.name, params.symbol, params.totalSupply);
        ownerToken[newToken] = msg.sender;
        emit CreateToken(
            newToken,
            msg.sender,
            params.name,
            params.symbol,
            params.decimals,
            params.totalSupply
        );
        // active pool
        Pool storage pool = pools[newToken];
        require(params.startTime > block.timestamp, "Invalid startTime");
        require(pool.status == StatusPool.INACTIVE, "Pool already active");
        uint256 balanceToken = IERC20Upgradeable(newToken).balanceOf(
            address(this)
        );
        uint256 totalSupply = IERC20Upgradeable(newToken).totalSupply();
        require(
            balanceToken == totalSupply,
            "Contract need to have all token."
        );
        require(
            totalSupply ==
                params.tokenForAirdrop +
                    params.tokenForFarm +
                    params.tokenForSale +
                    params.tokenForAddLP,
            "Invalid totalSupplyToken"
        );
        require(
            params.fixedCapETH >= MINIMUM_CAP,
            "Invalid fixedCapETH, must be greater than 2 ETH"
        );
        require(
            params.tokenForSale >= totalSupply.mul(70).div(100),
            "Invalid tokenForSale, must be greater than 70% of totalSupply"
        );
        require(
            params.tokenForAddLP >= totalSupply.mul(10).div(100),
            "Invalid tokenForAddLP, must be greater than 10% of totalSupply"
        );
        require(
            params.tokenForAirdrop <= totalSupply.mul(5).div(100),
            "Invalid tokenForAirdrop, must be less than 5% of totalSupply"
        );
        require(
            params.tokenForFarm <= totalSupply.mul(5).div(100),
            "Invalid tokenForFarm, must be less than 5% of totalSupply"
        );

        // setup PoolInfo
        PoolInfo storage poolInfo = poolInfos[newToken];
        poolInfo.fixedCapETH = params.fixedCapETH;
        poolInfo.totalSupplyToken = totalSupply;
        poolInfo.tokenForAirdrop = params.tokenForAirdrop;
        poolInfo.tokenForFarm = params.tokenForFarm;
        poolInfo.tokenForSale = params.tokenForSale;
        poolInfo.tokenForAddLP = params.tokenForAddLP;
        poolInfo.metadata = params.metadata;

        // limit purchase of Pool
        pool.tokenPerPurchase = params.tokenPerPurchase;
        pool.maxRepeatPurchase = params.maxRepeatPurchase;
        pool.totalBatch = params.tokenForSale.div(params.tokenPerPurchase);
        pool.totalBatchAvailable = pool.totalBatch;
        // limit time
        pool.startTime = params.startTime;
        pool.endTime = params.startTime.add(params.maxDurationSell);
        pool.minDurationSell = params.minDurationSell;
        pool.maxDurationSell = params.maxDurationSell;
        // current status
        pool.raisedInETH = 0;
        pool.soldBatch = 0;
        pool.reserveETH = params.fixedCapETH;
        pool.reserveBatch = pool.totalBatch.mul(2); // need multiply 2 for fomula
        pool.status = StatusPool.ACTIVE;
        // setup farm
        Farm storage farm = farms[newToken];
        farm.rewardPerBlock = params.tokenForFarm.div(
            params.maxDurationSell.mul(BASE_DENOMINATOR).div(BLOCK_INTERVAL)
        ); // = tokenForFarm / durationBlock
        farm.lastRewardBlock = block.number;
        farm.accTokenPerShare = 0;

        payable(platformAddress).transfer(platformFee);
        emit ActivePool(
            newToken,
            params.tokenForAirdrop,
            params.tokenForFarm,
            params.tokenForSale,
            params.tokenForAddLP,
            params.fixedCapETH,
            pool.totalBatch,
            params.metadata,
            params.startTime,
            pool.endTime,
            pool.minDurationSell
        );
        // end active pool

        if (params.numberBatch == 0) {
            return;
        }
        pool.totalBatchAvailable = pool.totalBatch.sub(params.numberBatch);
        // buy token
        uint256 ethValue = msg.value - platformFee;
        require(params.numberBatch > 0, "Invalid number bond, can't be 0");
        require(params.referrer != msg.sender, "Invalid referrer");
        require(params.maxAmountETH == ethValue, "maxAmountETH != ethValue");
        require(
            params.numberBatch < pool.totalBatch.sub(pool.soldBatch),
            "Exceed total batch"
        );

        uint256 amountETH = getAmountIn(
            params.numberBatch,
            pool.reserveETH,
            pool.reserveBatch
        );
        require(params.maxAmountETH >= amountETH, "Insufficient output ETH");
        // updateFarmingPool
        updateFarmingPool(newToken);
        // update pool info
        pool.reserveETH = pool.reserveETH.add(amountETH);
        pool.reserveBatch = pool.reserveBatch.sub(params.numberBatch);
        pool.soldBatch = pool.soldBatch.add(params.numberBatch);
        pool.raisedInETH = pool.raisedInETH.add(amountETH);
        // update user info
        User storage user = users[msg.sender][newToken];
        user.balance = user.balance.add(params.numberBatch);
        user.ethBought = user.ethBought.add(amountETH);
        user.rewardDebt = user
            .balance
            .mul(farms[newToken].accTokenPerShare)
            .div(1e12);
        // need add user to array
        if (!boughtCheck[newToken][msg.sender]) {
            buyerArr[newToken].push(msg.sender);
            boughtCheck[newToken][msg.sender] = true;
        }
        if (params.referrer != address(0)) {
            users[params.referrer][newToken].referrerBond = users[
                params.referrer
            ][newToken].referrerBond.add(params.numberBatch);
            pool.totalReferrerBond = pool.totalReferrerBond.add(
                params.numberBatch
            );
        }
        emit Bought(
            newToken,
            msg.sender,
            params.numberBatch,
            amountETH,
            params.referrer
        );
        if (params.maxAmountETH > amountETH) {
            payable(msg.sender).transfer(params.maxAmountETH.sub(amountETH));
        }
    }

    // Function to sell Token for ETH
    function sell(
        address poolAddress,
        uint256 batchNumber
    ) public nonReentrant {
        require(
            pools[poolAddress].status == StatusPool.ACTIVE,
            "Pool not active or full or finished"
        );
        User storage user = users[msg.sender][poolAddress];
        Pool storage pool = pools[poolAddress];
        uint256 amountETH = getAmountOut(
            batchNumber,
            pool.reserveBatch,
            pool.reserveETH
        );
        require(amountETH <= user.ethBought, "Exceed 100% of bought");
        // updateFarmingPool
        updateFarmingPool(poolAddress);
        // reward for user
        uint256 reward = user
            .balance
            .mul(farms[poolAddress].accTokenPerShare)
            .div(1e12)
            .sub(user.rewardDebt);
        if (reward > 0) {
            user.rewardFarm = user.rewardFarm.add(reward);
        }
        // reward for defi-team
        payable(feeAddress).transfer(amountETH.div(100)); // take 1% for platform
        uint256 sellTaxForLP = amountETH.mul(4).div(100); // take 4% for LP
        uint256 amountForUser = amountETH.mul(95).div(100); // fee 5%
        // update pool info
        pool.reserveETH = pool.reserveETH.sub(amountETH);
        pool.reserveBatch = pool.reserveBatch.add(batchNumber);
        pool.soldBatch = pool.soldBatch.sub(batchNumber);
        pool.raisedInETH = pool.raisedInETH.sub(amountETH);
        // update user info
        user.balanceSold = user.balanceSold.add(batchNumber);
        user.balance = user.balance.sub(batchNumber);
        user.ethBought = user.ethBought.sub(amountETH);
        user.rewardDebt = user
            .balance
            .mul(farms[poolAddress].accTokenPerShare)
            .div(1e12);
        totalSellTax[poolAddress] = totalSellTax[poolAddress].add(sellTaxForLP);

        // Transfer ETH to seller
        payable(msg.sender).transfer(amountForUser);

        emit Sold(poolAddress, msg.sender, batchNumber, amountForUser);
    }

    /**
     * @dev Finalizes the Rocket contract by performing certain actions.
     * @param poolAddress The address of the pool to be finalized.
     * @notice This function can only be called by an account with the ADMIN_ROLE.
     */
    function finalize(address poolAddress) public {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
                msg.sender == ownerToken[poolAddress],
            "Caller is not an admin or owner"
        );
        Pool storage pool = pools[poolAddress];
        require(pool.status == StatusPool.FULL, "Not reach target");
        uint256 amountTokenForAddLP = poolInfos[poolAddress].tokenForAddLP;
        uint256 ethForAddLP = pool.raisedInETH.add(totalSellTax[poolAddress]);
        // transfer reward to platform
        if (fee > 0) {
            uint256 feeAmount = ethForAddLP.mul(fee).div(BASE_DENOMINATOR);
            payable(feeAddress).transfer(feeAmount);
            ethForAddLP = ethForAddLP.sub(feeAmount);
        }
        // addLiquidtyETH on Uniswap V3 + burn LP token
        addLiquidityV3(ethForAddLP, amountTokenForAddLP, poolAddress);
        pool.status = StatusPool.FINISHED;
        // disable farm
        Farm storage farm = farms[poolAddress];
        updateFarmingPool(poolAddress);
        farm.isDisable = true;

        Vesting storage vest = vesting[poolAddress];
        vest.startTime = block.timestamp;
        vest.isExist = true;

        // if there is no referrer, then burn 100% of token for airdrop
        if (pool.totalReferrerBond == 0) {
            uint256 amountTokenForAirdrop = poolInfos[poolAddress]
                .tokenForAirdrop;
            IERC20Upgradeable(poolAddress).transfer(
                DEAD_ADDR,
                amountTokenForAirdrop
            );
        }

        emit Finalized(poolAddress);
    }

    // Function to transfer token to users when pool is finished
    function transferTokenUsers(
        address tokenAddress
    ) external onlyRole(ADMIN_ROLE) {
        require(
            pools[tokenAddress].status == StatusPool.FINISHED,
            "Pool not finished"
        );
        uint256 lengthBuyer = buyerArr[tokenAddress].length;
        require(
            !completedTransfer[tokenAddress],
            "All users have been transferred"
        );
        if (lengthBuyer > counterSoldUsers[tokenAddress].add(100)) {
            lengthBuyer = counterSoldUsers[tokenAddress].add(100);
        }
        uint256 percent = caculateUnlockedPercent(tokenAddress);
        require(percent == BASE_DENOMINATOR, "Not reach unlock time");
        for (uint256 i = counterSoldUsers[tokenAddress]; i < lengthBuyer; i++) {
            _claimTokenByUser(buyerArr[tokenAddress][i], tokenAddress);
        }

        counterSoldUsers[tokenAddress] = lengthBuyer;
        if (lengthBuyer == buyerArr[tokenAddress].length) {
            // Burn remaining Farming tokens
            uint256 remainingFarming = IERC20Upgradeable(tokenAddress)
                .balanceOf(address(this));
            IERC20Upgradeable(tokenAddress).transfer(
                DEAD_ADDR,
                remainingFarming
            );
            completedTransfer[tokenAddress] = true;
            emit CompletedPool(tokenAddress);
        }
    }

    // Function to refund ETH to users when pool is fail
    function refundETHToUsers(
        address tokenAddress
    ) external onlyRole(ADMIN_ROLE) {
        require(
            pools[tokenAddress].endTime < block.timestamp,
            "Pool is not over time"
        );
        require(
            pools[tokenAddress].status != StatusPool.FINISHED &&
                pools[tokenAddress].status != StatusPool.FULL,
            "Pool is finished"
        );

        uint256 lengthBuyer = buyerArr[tokenAddress].length;
        require(
            !completedTransfer[tokenAddress],
            "All users have been transferred"
        );
        if (lengthBuyer > counterSoldUsers[tokenAddress].add(100)) {
            lengthBuyer = counterSoldUsers[tokenAddress].add(100);
        }
        for (uint256 i = counterSoldUsers[tokenAddress]; i < lengthBuyer; i++) {
            refundETH(buyerArr[tokenAddress][i], tokenAddress);
        }
        counterSoldUsers[tokenAddress] = lengthBuyer;
        if (lengthBuyer == buyerArr[tokenAddress].length) {
            completedTransfer[tokenAddress] = true;
            emit FailPool(tokenAddress);
        }
    }

    // Function to claim token by user
    function claimToken(address pool) external {
        User storage user = users[msg.sender][pool];
        require(user.balance > 0, "User not bought");
        Vesting storage vest = vesting[pool];
        require(vest.isExist, "Vesting not exist");
        require(!user.isClaimed, "User already claimed");
        uint256 percent = caculateUnlockedPercent(pool);
        uint256 tokenAmount = user.balance.mul(pools[pool].tokenPerPurchase);
        tokenAmount = tokenAmount.mul(percent).div(BASE_DENOMINATOR);
        tokenAmount = tokenAmount.sub(user.tokenClaimed);
        require(tokenAmount > 0, "No token to claim");
        user.tokenClaimed = user.tokenClaimed.add(tokenAmount);
        if (!user.isClaimedFarm) {
            // Calculate farming reward
            uint256 reward = user
                .balance
                .mul(farms[pool].accTokenPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (reward > 0) {
                user.rewardFarm = user.rewardFarm.add(reward);
            }
            tokenAmount = tokenAmount.add(user.rewardFarm);
            // calculate referrer reward
            if (user.referrerBond > 0) {
                uint256 referrerReward = user
                    .referrerBond
                    .mul(poolInfos[pool].tokenForAirdrop)
                    .div(pools[pool].totalReferrerBond);
                tokenAmount = tokenAmount.add(referrerReward);
            }
            user.isClaimedFarm = true;
        }
        IERC20Upgradeable(pool).transfer(msg.sender, tokenAmount);
        if (percent == BASE_DENOMINATOR) {
            user.isClaimed = true;
        }
        emit Claimed(pool, msg.sender, tokenAmount);
    }

    function _claimTokenByUser(address buyer, address pool) internal {
        User storage user = users[buyer][pool];
        if (user.isClaimed) {
            return;
        }
        user.isClaimed = true;
        if (user.balance > 0) {
            uint256 tokenAmount = user.balance.mul(
                pools[pool].tokenPerPurchase
            );
            tokenAmount = tokenAmount.sub(user.tokenClaimed);
            if (tokenAmount > 0) {
                user.tokenClaimed = user.tokenClaimed.add(tokenAmount);
                if (!user.isClaimedFarm) {
                    // Calculate farming reward
                    uint256 reward = user
                        .balance
                        .mul(farms[pool].accTokenPerShare)
                        .div(1e12)
                        .sub(user.rewardDebt);
                    if (reward > 0) {
                        user.rewardFarm = user.rewardFarm.add(reward);
                    }
                    tokenAmount = tokenAmount.add(user.rewardFarm);
                    user.isClaimedFarm = true;
                }
                IERC20Upgradeable(pool).transfer(buyer, tokenAmount);
                emit Claimed(pool, buyer, tokenAmount);
            }
        }
    }

    function refundETH(address buyer, address pool) internal {
        User storage user = users[buyer][pool];
        if (user.isClaimed) {
            return;
        }
        if (user.balance > 0) {
            user.isClaimed = true;
            payable(buyer).transfer(user.ethBought);
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 numerator = amountIn.mul(reserveOut); // sell: Batch * RESERVE_ETH / BATCH +
        uint256 denominator = reserveIn.add(amountIn);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountIn) {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint numerator = reserveIn.mul(amountOut);
        uint denominator = reserveOut.sub(amountOut);
        amountIn = numerator / denominator;
    }

    function estimateBuy(
        address poolAddress,
        uint256 batchNumber
    ) public view returns (uint) {
        Pool storage pool = pools[poolAddress];
        return getAmountIn(batchNumber, pool.reserveETH, pool.reserveBatch);
    }

    function estimateSell(
        address poolAddress,
        uint256 batchNumber
    ) public view returns (uint) {
        Pool storage pool = pools[poolAddress];
        return getAmountOut(batchNumber, pool.reserveBatch, pool.reserveETH);
    }

    function getMaxBatchCurrent(
        address poolAddress
    ) public view returns (uint256) {
        Pool storage pool = pools[poolAddress];
        uint256 totalBatch = pool.totalBatchAvailable == 0
            ? pool.totalBatch
            : pool.totalBatchAvailable;
        uint256 batchBuyFirst = pool.totalBatchAvailable == 0
            ? 0
            : pool.totalBatch.sub(pool.totalBatchAvailable);
        if (block.timestamp >= pool.startTime.add(pool.minDurationSell)) {
            return totalBatch;
        }
        uint256 timePassed = block.timestamp.sub(pool.startTime);
        return
            batchBuyFirst.add(
                timePassed.mul(totalBatch).div(pool.minDurationSell)
            );
    }

    function pendingRewardFarming(
        address poolAddress,
        address userAddress
    ) public view returns (uint256) {
        User storage user = users[userAddress][poolAddress];
        if (user.balance == 0) {
            return 0;
        }
        uint256 accTokenPerShare = farms[poolAddress].accTokenPerShare;
        uint256 rewardPerBlock = farms[poolAddress].rewardPerBlock;
        uint256 lastRewardBlock = farms[poolAddress].lastRewardBlock;
        uint256 currentBlock = block.number;
        if (currentBlock > lastRewardBlock && poolAddress != address(0)) {
            uint256 multiplier = currentBlock.sub(lastRewardBlock);
            uint256 reward = multiplier.mul(rewardPerBlock);
            accTokenPerShare = accTokenPerShare.add(
                reward.mul(1e12).div(pools[poolAddress].soldBatch)
            );
        }
        return
            user.balance.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    function pendingReferrerReward(
        address poolAddress,
        address userAddress
    ) public view returns (uint256) {
        User storage user = users[userAddress][poolAddress];
        uint256 amountForAirdrop = poolInfos[poolAddress].tokenForAirdrop;
        uint256 totalReferrerBond = pools[poolAddress].totalReferrerBond;
        uint256 referrerBond = user.referrerBond;
        return referrerBond.mul(amountForAirdrop).div(totalReferrerBond);
    }

    // Function to claim token by user
    function pendingClaimAmount(
        address poolAddress,
        address userAddress
    ) public view returns (uint256) {
        User storage user = users[userAddress][poolAddress];
        if (user.balance == 0) return 0;
        if (user.isClaimed) return 0;
        Vesting storage vest = vesting[poolAddress];
        if (!vest.isExist) return 0;
        uint256 percent = caculateUnlockedPercent(poolAddress);
        uint256 tokenAmount = user.balance.mul(
            pools[poolAddress].tokenPerPurchase
        );
        tokenAmount = tokenAmount.mul(percent).div(BASE_DENOMINATOR);
        if (!user.isClaimedFarm) {
            uint256 reward = user
                .balance
                .mul(farms[poolAddress].accTokenPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            tokenAmount = tokenAmount.add(user.rewardFarm.add(reward));
        }
        tokenAmount = tokenAmount.sub(user.tokenClaimed);
        return tokenAmount;
    }

    function updateFarmingPool(address poolAddress) private {
        Farm storage farm = farms[poolAddress];
        if (farm.isDisable) return;
        if (block.number <= farm.lastRewardBlock) {
            return;
        }
        uint256 supply = pools[poolAddress].soldBatch;
        if (supply == 0) {
            farm.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number.sub(farm.lastRewardBlock);
        uint256 reward = multiplier.mul(farm.rewardPerBlock);
        farm.accTokenPerShare = farm.accTokenPerShare.add(
            reward.mul(1e12).div(supply)
        );
        farm.lastRewardBlock = block.number;
    }

    /**
     * @dev Pre function to caculate how long has pass since round unlocked
     * @notice Current set is 10% each hours
     */
    function caculateUnlockedPercent(
        address pool
    ) public view returns (uint256) {
        Vesting storage vest = vesting[pool];
        if (block.timestamp < vest.startTime) return 0;
        uint256 timePass = (block.timestamp.sub(vest.startTime)).div(DURATION);
        uint256 percent = timePass.mul(PERCENT_RELEASE).add(
            PERCENT_RELEASE_AT_TGE
        );
        if (percent > BASE_DENOMINATOR) return BASE_DENOMINATOR;
        return percent;
    }

     function addLiquidityV3(
        uint256 amountETH,
        uint256 amountToken,
        address token
    ) internal {
        IERC20Upgradeable(token).approve(router, amountToken);
        uint256 sqrtPrice = Math.sqrt(amountETH.mul(1e18).div(amountToken));
        IWETH(WETH).deposit{value: amountETH}();
        IWETH(WETH).approve(router, amountETH);
        uint256 sqrtPriceX96 = X96.mul(sqrtPrice).div(1e9); // The initial square root price of the pool as a Q64.96 value
        bool isToken0 = token < WETH;
        (address token0, address token1) = isToken0
            ? (token, WETH)
            : (WETH, token);
        INonfungiblePositionManager(router).createAndInitializePoolIfNecessary(
            token0,
            token1,
            3000,
            uint160(sqrtPriceX96)
        );
        INonfungiblePositionManager(router).mint(
            TokenLibrary.MintParams({
                token0: isToken0 ? token : WETH,
                token1: isToken0 ? WETH : token,
                fee: 3000,
                tickLower: -887220, // ?
                tickUpper: 887220, // ?
                amount0Desired: isToken0 ? amountToken : amountETH,
                amount1Desired: isToken0 ? amountETH : amountToken,
                amount0Min: 0,
                amount1Min: 0,
                recipient: tx.origin,
                deadline: block.timestamp
            })
        );
    }
}
