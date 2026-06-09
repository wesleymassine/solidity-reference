// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
// TOKENOMICS: VESTING, DISTRIBUTION, BONDING CURVES & STAKING
// =============================================================================
// Tokenomics defines how tokens are created, distributed, and incentivized.
// Every serious protocol needs these patterns at launch.
//
// Topics covered:
//   1. Linear vesting with cliff
//   2. Custom vesting schedules (milestone-based, graded)
//   3. Merkle airdrop (gas-efficient distribution to thousands of addresses)
//   4. Bonding curves (linear, square root, Bancor formula)
//   5. Liquidity Bootstrapping Pool (LBP) — fair token launch
//   6. Staking with reward accrual (single-asset, dual-token)
//   7. Vote-escrowed tokens (veTokens) — time-weighted governance power
//   8. Token buyback & burn (fee → protocol revenue → deflation)
//   9. Emission schedule — decreasing inflation over time
// =============================================================================

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

// =============================================================================
// SECTION 1 — LINEAR VESTING WITH CLIFF
// =============================================================================
// Standard for: team tokens, investor tokens, advisor allocations.
// Cliff: no tokens available until cliff timestamp.
// After cliff: linear release over the remaining vesting period.
//
// Example: 1 year cliff, 3 years total vesting
//   Month 0-12:  0 tokens claimable
//   Month 12:    25% unlocked instantly (cliff unlock)
//   Month 12-48: remaining 75% unlock linearly

contract VestingWallet {
    IERC20 public immutable token;

    struct VestingSchedule {
        address beneficiary;
        uint256 totalAmount;
        uint256 cliffTime;      // unix timestamp when cliff ends
        uint256 startTime;      // vesting start (can be before cliff)
        uint256 duration;       // total vesting duration in seconds
        uint256 released;       // already claimed
        bool    revocable;      // can the owner revoke?
        bool    revoked;
    }

    mapping(bytes32 => VestingSchedule) public schedules;
    mapping(address => bytes32[]) public beneficiarySchedules;
    uint256 private _scheduleCount;

    address public owner;

    event ScheduleCreated(bytes32 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event TokensReleased(bytes32 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event ScheduleRevoked(bytes32 indexed scheduleId, uint256 refundAmount);

    error NotOwner();
    error NotBeneficiary();
    error NothingToRelease();
    error ScheduleRevoked_();
    error NotRevocable();

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    // Create a new vesting schedule for a beneficiary
    function createSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,  // seconds from start to cliff
        uint256 vestingDuration, // total seconds of vesting
        bool    revocable
    ) external returns (bytes32 scheduleId) {
        if (msg.sender != owner) revert NotOwner();
        require(vestingDuration > 0, "Duration must be > 0");
        require(totalAmount > 0, "Amount must be > 0");
        require(beneficiary != address(0), "Zero address");

        // Pull tokens from owner into this contract
        token.transferFrom(msg.sender, address(this), totalAmount);

        scheduleId = keccak256(abi.encode(beneficiary, ++_scheduleCount, block.timestamp));
        schedules[scheduleId] = VestingSchedule({
            beneficiary:  beneficiary,
            totalAmount:  totalAmount,
            cliffTime:    startTime + cliffDuration,
            startTime:    startTime,
            duration:     vestingDuration,
            released:     0,
            revocable:    revocable,
            revoked:      false
        });
        beneficiarySchedules[beneficiary].push(scheduleId);

        emit ScheduleCreated(scheduleId, beneficiary, totalAmount);
    }

    // Beneficiary claims all vested tokens
    function release(bytes32 scheduleId) external returns (uint256 releasable) {
        VestingSchedule storage s = schedules[scheduleId];
        if (msg.sender != s.beneficiary) revert NotBeneficiary();
        if (s.revoked) revert ScheduleRevoked_();

        releasable = vestedAmount(scheduleId) - s.released;
        if (releasable == 0) revert NothingToRelease();

        s.released += releasable;
        token.transfer(s.beneficiary, releasable);

        emit TokensReleased(scheduleId, s.beneficiary, releasable);
    }

    // Compute how many tokens are vested at current time
    function vestedAmount(bytes32 scheduleId) public view returns (uint256) {
        VestingSchedule storage s = schedules[scheduleId];
        if (s.revoked) return s.released; // only what's already released remains

        if (block.timestamp < s.cliffTime) return 0;

        uint256 elapsed = block.timestamp - s.startTime;
        if (elapsed >= s.duration) return s.totalAmount; // fully vested

        // Linear vesting between cliff and end
        return s.totalAmount * elapsed / s.duration;
    }

    function releasable(bytes32 scheduleId) external view returns (uint256) {
        return vestedAmount(scheduleId) - schedules[scheduleId].released;
    }

    // Owner revokes a revocable schedule — unvested tokens return to owner
    function revoke(bytes32 scheduleId) external {
        if (msg.sender != owner) revert NotOwner();
        VestingSchedule storage s = schedules[scheduleId];
        if (!s.revocable) revert NotRevocable();
        if (s.revoked) revert ScheduleRevoked_();

        uint256 vested   = vestedAmount(scheduleId);
        uint256 refund   = s.totalAmount - vested;
        s.revoked        = true;

        // Remaining unvested tokens go back to owner
        if (refund > 0) token.transfer(owner, refund);

        emit ScheduleRevoked(scheduleId, refund);
    }
}

// =============================================================================
// SECTION 2 — MERKLE AIRDROP
// =============================================================================
// Distribute tokens to thousands of addresses without looping on-chain.
// Off-chain: build a Merkle tree with (address, amount) leaves.
// On-chain: store only the root. Each user proves inclusion and claims.
// Gas cost: O(log N) per claim regardless of N total recipients.

contract MerkleAirdrop {
    IERC20  public immutable token;
    bytes32 public immutable merkleRoot;
    uint256 public immutable expiry;        // after expiry, owner can reclaim unclaimed

    mapping(address => bool) public claimed;

    address public owner;

    event Claimed(address indexed account, uint256 amount);
    event UnclaimedReclaimed(uint256 amount);

    error AlreadyClaimed();
    error InvalidProof();
    error AirdropNotExpired();

    constructor(address _token, bytes32 _merkleRoot, uint256 _expiry) {
        token      = IERC20(_token);
        merkleRoot = _merkleRoot;
        expiry     = _expiry;
        owner      = msg.sender;
    }

    // User proves they are in the Merkle tree and claims their tokens
    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        if (claimed[account]) revert AlreadyClaimed();

        // Verify Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        if (!_verify(merkleProof, merkleRoot, leaf)) revert InvalidProof();

        claimed[account] = true;
        token.transfer(account, amount);
        emit Claimed(account, amount);
    }

    // After expiry, owner reclaims unclaimed tokens
    function reclaimUnclaimed() external {
        require(msg.sender == owner, "Not owner");
        if (block.timestamp < expiry) revert AirdropNotExpired();
        uint256 remaining = token.balanceOf(address(this));
        token.transfer(owner, remaining);
        emit UnclaimedReclaimed(remaining);
    }

    function _verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            // Sort to ensure consistent hashing regardless of leaf order
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash == root;
    }
}

// =============================================================================
// SECTION 3 — BONDING CURVES
// =============================================================================
// A bonding curve is a mathematical function that determines token price
// based on supply. As more tokens are bought, price increases automatically.
// Enables continuous token issuance without exchange listing.
//
// Types:
//   Linear:      price = a * supply + b           (simple, predictable)
//   Square root: price = a * sqrt(supply)         (slower growth, more stable)
//   Exponential: price = a * e^(k*supply)         (aggressive early growth)
//   Bancor:      price = reserveBalance / (supply * reserveRatio)

library BondingCurveMath {
    // Linear bonding curve: price per token = slope * supply + basePrice
    // Integral (cost to buy from s1 to s2):
    //   cost = slope * (s2² - s1²) / 2 + basePrice * (s2 - s1)
    function linearCost(
        uint256 currentSupply,
        uint256 tokensToBuy,
        uint256 slope,      // wei per token² (scaled by 1e18)
        uint256 basePrice   // wei per token
    ) internal pure returns (uint256 cost) {
        uint256 s1 = currentSupply;
        uint256 s2 = currentSupply + tokensToBuy;
        // Area under the line = trapezoid area
        cost = slope * (s2 * s2 - s1 * s1) / 2 / 1e18
             + basePrice * tokensToBuy / 1e18;
    }

    // Tokens you get for a given ETH amount (linear curve)
    // Inverse: solve tokensToBuy from cost
    // Quadratic formula: slope/2 * t² + (slope*s + base) * t - cost = 0
    function linearTokensForEth(
        uint256 currentSupply,
        uint256 ethAmount,
        uint256 slope,
        uint256 basePrice
    ) internal pure returns (uint256 tokens) {
        // Simplified Newton's method approximation
        uint256 priceNow = slope * currentSupply / 1e18 + basePrice;
        tokens = ethAmount * 1e18 / priceNow; // first approximation
        // In production: use a proper Newton's iteration for precision
    }

    // Bancor formula: tokensMinted = supply * ((1 + ethDeposit/reserveBalance)^CW - 1)
    // CW = Connector Weight (e.g., 0.5 for square-root curve)
    // Simplified version (no fractional exponent in Solidity — use off-chain or table):
    function bancorApproxTokens(
        uint256 supply,
        uint256 reserveBalance,
        uint256 reserveWeight,  // out of 1e6 (e.g., 500000 = 50%)
        uint256 ethDeposited
    ) internal pure returns (uint256 tokensMinted) {
        // Using (1 + x)^n ≈ 1 + n*x for small x (Taylor expansion)
        // Good approximation when ethDeposited << reserveBalance
        uint256 ratio = ethDeposited * 1e18 / reserveBalance;
        tokensMinted  = supply * reserveWeight * ratio / 1e6 / 1e18;
    }
}

contract LinearBondingCurve {
    IERC20 public immutable token;
    uint256 public totalSupply;

    uint256 public constant SLOPE     = 1e9;   // 1 gwei per token of supply
    uint256 public constant BASE_PRICE = 0.001 ether; // 0.001 ETH starting price

    uint256 public reserveBalance; // ETH held in reserve

    event TokensPurchased(address indexed buyer, uint256 ethIn, uint256 tokensOut);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 ethOut);

    error InsufficientEth();
    error SlippageExceeded();

    constructor(address _token) {
        token = IERC20(_token);
    }

    // Buy tokens by sending ETH — price increases as supply grows
    function buy(uint256 minTokensOut) external payable returns (uint256 tokensBought) {
        uint256 ethIn = msg.value;
        tokensBought = BondingCurveMath.linearTokensForEth(totalSupply, ethIn, SLOPE, BASE_PRICE);

        if (tokensBought < minTokensOut) revert SlippageExceeded();

        totalSupply    += tokensBought;
        reserveBalance += ethIn;
        token.transfer(msg.sender, tokensBought);

        emit TokensPurchased(msg.sender, ethIn, tokensBought);
    }

    // Sell tokens back — receives ETH from reserve at current price
    function sell(uint256 tokensIn, uint256 minEthOut) external returns (uint256 ethOut) {
        require(totalSupply >= tokensIn, "Exceeds supply");

        // Cost to buy tokensIn at current supply = what seller receives
        ethOut = BondingCurveMath.linearCost(totalSupply - tokensIn, tokensIn, SLOPE, BASE_PRICE);
        if (ethOut < minEthOut) revert SlippageExceeded();

        token.transferFrom(msg.sender, address(this), tokensIn);
        totalSupply    -= tokensIn;
        reserveBalance -= ethOut;

        (bool ok, ) = msg.sender.call{value: ethOut}("");
        require(ok, "ETH transfer failed");

        emit TokensSold(msg.sender, tokensIn, ethOut);
    }

    // Current spot price (ETH per token)
    function spotPrice() external view returns (uint256) {
        return SLOPE * totalSupply / 1e18 + BASE_PRICE;
    }
}

// =============================================================================
// SECTION 4 — STAKING WITH REWARD DISTRIBUTION
// =============================================================================
// Users lock tokens to earn rewards.
// Rewards are distributed proportionally based on staked amount.
// Uses the "reward per token" pattern — O(1) claims without iteration.

contract StakingRewards {
    IERC20 public immutable stakingToken;   // token users stake
    IERC20 public immutable rewardToken;    // token users earn

    uint256 public rewardRate;              // reward tokens per second distributed
    uint256 public rewardsDuration = 30 days;
    uint256 public periodFinish;            // timestamp rewards period ends
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;    // accumulated reward per staked token

    mapping(address => uint256) public userRewardPerTokenPaid; // snapshot at last update
    mapping(address => uint256) public rewards;                // pending rewards

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken  = IERC20(_rewardToken);
        owner        = msg.sender;
    }

    // ==========================================================================
    // Core accounting: update reward snapshot before any balance change
    // ==========================================================================

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime       = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account]                = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    // Accumulated reward tokens per staked token (global)
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored +
            (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply;
    }

    // Pending rewards for an account
    function earned(address account) public view returns (uint256) {
        return balanceOf[account] *
            (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18
            + rewards[account];
    }

    // ==========================================================================
    // User actions
    // ==========================================================================

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalSupply       += amount;
        balanceOf[msg.sender] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        totalSupply           -= amount;
        balanceOf[msg.sender] -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Convenience: withdraw + claim in one tx
    function exit() external {
        withdraw(balanceOf[msg.sender]);
        claimReward();
    }

    // ==========================================================================
    // Owner: fund the rewards contract
    // ==========================================================================

    function notifyRewardAmount(uint256 reward) external updateReward(address(0)) {
        require(msg.sender == owner, "Not owner");
        rewardToken.transferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover  = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish   = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }
}

// =============================================================================
// SECTION 5 — VE TOKEN (VOTE-ESCROWED)
// =============================================================================
// Users lock tokens for a duration to receive non-transferable veTokens.
// The longer the lock, the more voting power and protocol fees they receive.
// Used by: Curve (veCRV), Balancer (veBAL), Frax (veFXS), Velodrome.
//
// Key mechanics:
//   - veToken balance decays linearly to 0 at lock expiry
//   - Users can extend their lock to maintain voting power
//   - veToken is NOT transferable (prevents vote buying)
//   - Protocol fees distributed to veToken holders proportionally

contract VeToken {
    IERC20 public immutable baseToken;

    uint256 public constant MAX_LOCK_DURATION = 4 * 365 days; // 4 years max
    uint256 public constant WEEK = 1 weeks;                    // locks snap to weeks

    struct Lock {
        uint256 amount;    // base tokens locked
        uint256 end;       // lock expiry (rounded to week)
    }

    mapping(address => Lock) public locks;

    uint256 public totalBaseTokenLocked;

    event Locked(address indexed user, uint256 amount, uint256 end);
    event Withdrawn(address indexed user, uint256 amount);
    event LockExtended(address indexed user, uint256 newEnd);
    event LockIncreased(address indexed user, uint256 addedAmount);

    error LockNotExpired();
    error LockExpired();
    error InvalidDuration();
    error NoLock();

    constructor(address _baseToken) {
        baseToken = IERC20(_baseToken);
    }

    // Lock base tokens for a duration — receive veToken voting power
    function lock(uint256 amount, uint256 duration) external {
        require(amount > 0, "Zero amount");
        if (duration == 0 || duration > MAX_LOCK_DURATION) revert InvalidDuration();

        // Snap expiry to nearest week (like Curve)
        uint256 roundedEnd = (block.timestamp + duration) / WEEK * WEEK;

        Lock storage userLock = locks[msg.sender];
        if (userLock.amount > 0) {
            // Extend existing lock
            require(roundedEnd > userLock.end, "Must extend lock");
            userLock.end = roundedEnd;
            if (amount > 0) {
                userLock.amount += amount;
                baseToken.transferFrom(msg.sender, address(this), amount);
                totalBaseTokenLocked += amount;
            }
        } else {
            // New lock
            userLock.amount = amount;
            userLock.end    = roundedEnd;
            baseToken.transferFrom(msg.sender, address(this), amount);
            totalBaseTokenLocked += amount;
        }

        emit Locked(msg.sender, amount, roundedEnd);
    }

    // Voting power: linear decay from full (at lock time) to 0 (at expiry)
    // veBalance = lockedAmount * timeRemaining / maxDuration
    function balanceOf(address user) external view returns (uint256) {
        Lock storage l = locks[user];
        if (l.end <= block.timestamp) return 0;
        uint256 timeRemaining = l.end - block.timestamp;
        return l.amount * timeRemaining / MAX_LOCK_DURATION;
    }

    // Total veToken supply (sum of all decaying balances — approximate)
    function totalSupply() external view returns (uint256) {
        // In production: maintain a checkpoint system (like Curve's EscrowVoting)
        // For simplicity: return total locked (over-estimates, but shows concept)
        return totalBaseTokenLocked;
    }

    // Extend lock duration (maintains or increases voting power)
    function extendLock(uint256 newEnd) external {
        Lock storage l = locks[msg.sender];
        if (l.amount == 0) revert NoLock();
        if (l.end <= block.timestamp) revert LockExpired();

        uint256 roundedEnd = newEnd / WEEK * WEEK;
        require(roundedEnd > l.end, "Must extend");
        require(roundedEnd <= block.timestamp + MAX_LOCK_DURATION, "Too long");

        l.end = roundedEnd;
        emit LockExtended(msg.sender, roundedEnd);
    }

    // Withdraw base tokens after lock expires
    function withdraw() external {
        Lock storage l = locks[msg.sender];
        if (l.amount == 0) revert NoLock();
        if (block.timestamp < l.end) revert LockNotExpired();

        uint256 amount = l.amount;
        l.amount = 0;
        l.end    = 0;
        totalBaseTokenLocked -= amount;

        baseToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
}

// =============================================================================
// SECTION 6 — TOKEN BUYBACK & BURN
// =============================================================================
// Protocol collects fees (in ETH or stablecoin) and uses them to:
//   a) Buy back the protocol token on the open market
//   b) Burn the bought tokens (deflationary)
// This creates sustainable demand tied to protocol usage.

interface IRouter {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface IBurnable is IERC20 {
    function burn(uint256 amount) external;
}

contract BuybackAndBurn {
    IBurnable public immutable token;
    IRouter   public immutable router;
    address   public immutable weth;

    address public owner;

    uint256 public totalBurned;

    event BuybackExecuted(uint256 ethSpent, uint256 tokensBought);
    event TokensBurned(uint256 amount);

    constructor(address _token, address _router, address _weth) {
        token  = IBurnable(_token);
        router = IRouter(_router);
        weth   = _weth;
        owner  = msg.sender;
    }

    // Collect ETH fees from protocol components
    receive() external payable {}

    // Buy token with accumulated ETH and burn it
    function buybackAndBurn(uint256 minTokensOut) external {
        require(msg.sender == owner, "Not owner");
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to spend");

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);

        uint256[] memory amounts = router.swapExactETHForTokens{value: ethBalance}(
            minTokensOut, path, address(this), block.timestamp
        );

        uint256 tokensBought = amounts[amounts.length - 1];
        emit BuybackExecuted(ethBalance, tokensBought);

        // Burn the purchased tokens
        token.burn(tokensBought);
        totalBurned += tokensBought;
        emit TokensBurned(tokensBought);
    }
}

// =============================================================================
// SECTION 7 — EMISSION SCHEDULE (DECREASING INFLATION)
// =============================================================================
// Controls how new tokens are minted over time.
// Common patterns:
//   Halving (Bitcoin-style): emissions halve every N blocks/years
//   Exponential decay:       emissions = initialRate * e^(-k * time)
//   Fixed schedule:          predefined emission per epoch

contract TokenEmissions {
    IERC20 public immutable token; // must have mint() — simplified interface

    // Halving schedule (Bitcoin-inspired)
    uint256 public constant INITIAL_RATE   = 100e18;   // tokens per epoch
    uint256 public constant EPOCH_DURATION = 365 days;
    uint256 public constant HALVING_PERIOD = 4 * 365 days; // halve every 4 years

    uint256 public startTime;
    uint256 public lastEpoch;

    address public miningPool;   // receives mining emissions
    address public treasury;     // receives treasury share
    address public owner;

    uint256 public constant MINING_SHARE   = 60; // 60% to miners/LPs
    uint256 public constant TREASURY_SHARE = 40; // 40% to treasury

    event EmissionDistributed(uint256 epoch, uint256 totalAmount, uint256 halvingCount);

    constructor(address _token, address _miningPool, address _treasury) {
        token       = IERC20(_token);
        miningPool  = _miningPool;
        treasury    = _treasury;
        startTime   = block.timestamp;
        owner       = msg.sender;
    }

    // Calculate current emission rate accounting for halvings
    function currentEmissionRate() public view returns (uint256) {
        uint256 elapsed = block.timestamp - startTime;
        uint256 halvings = elapsed / HALVING_PERIOD;
        // Each halving divides by 2: rate = initialRate >> halvings
        if (halvings >= 64) return 0; // prevent shift overflow — fully emitted
        return INITIAL_RATE >> halvings;
    }

    // Distribute emissions for the current epoch
    function distributeEpoch() external {
        uint256 currentEpoch = (block.timestamp - startTime) / EPOCH_DURATION;
        require(currentEpoch > lastEpoch, "Epoch not complete");

        uint256 rate = currentEmissionRate();
        if (rate == 0) return; // fully emitted

        lastEpoch = currentEpoch;

        uint256 miningAmount  = rate * MINING_SHARE / 100;
        uint256 treasuryAmount = rate * TREASURY_SHARE / 100;

        // In production: token.mint(miningPool, miningAmount)
        // Simplified: assumes this contract holds the tokens
        token.transfer(miningPool, miningAmount);
        token.transfer(treasury,   treasuryAmount);

        emit EmissionDistributed(currentEpoch, rate, _halvingCount());
    }

    function _halvingCount() internal view returns (uint256) {
        return (block.timestamp - startTime) / HALVING_PERIOD;
    }
}

// =============================================================================
// SECTION 8 — TOKEN DISTRIBUTION SUMMARY TABLE
// =============================================================================
//
// Pattern          | When to use                        | Gas cost
// -----------------|------------------------------------|----------
// Merkle airdrop   | Large recipient lists (>1000)      | O(log N) per claim
// Direct transfer  | Small lists (<100)                 | O(N) (owner loops)
// Vesting wallet   | Team / investor allocations        | O(1) per claim
// Bonding curve    | Fair launch, continuous issuance   | O(1) per buy/sell
// Staking rewards  | LP / holder incentives             | O(1) per update
// veToken          | Long-term alignment, fee sharing   | O(1) per op
// Buyback & burn   | Revenue → token demand             | 1 swap + 1 burn
// Halving schedule | Predictable, deflationary supply   | O(1) per epoch

// =============================================================================
// PROFESSIONAL CHECKLIST: TOKENOMICS AUDIT POINTS
// =============================================================================
//
// [ ] Vesting cliff: check cliff < vestingEnd always; 0 cliff = no cliff (not broken)
// [ ] Vesting revoke: unvested goes to owner, vested remains claimable
// [ ] Merkle leaf: include address AND amount in leaf (amount-only = amount-swap attack)
// [ ] Merkle leaf hash: keccak256(abi.encodePacked) — not encodePacked alone (hash collision)
// [ ] Merkle expiry: include expiry to reclaim undistributed tokens
// [ ] Bonding curve: sell price ≤ buy price (no arbitrage from rounding)
// [ ] Bonding curve reserve: ETH reserve must always cover all outstanding tokens
// [ ] Staking updateReward: call before EVERY balance change (stake, withdraw, transfer)
// [ ] Staking reward rate: rewardRate * rewardsDuration <= reward token balance
// [ ] veToken: non-transferable — remove transfer/transferFrom or revert
// [ ] veToken week snap: rounding to week prevents precision games
// [ ] veToken expiry: balanceOf returns 0 after expiry (no zombie voting power)
// [ ] Buyback slippage: minTokensOut protects against sandwich attacks
// [ ] Buyback governance: large buybacks should require governance approval
// [ ] Emission cap: total emissions + existing supply never exceed max supply
// [ ] Halving overflow: INITIAL_RATE >> halvings returns 0 after 64 halvings
// [ ] Admin keys: vesting owner, emission admin should eventually be timelock
