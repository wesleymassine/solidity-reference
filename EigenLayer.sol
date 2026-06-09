// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
// EIGENLAYER: RESTAKING AND ACTIVELY VALIDATED SERVICES (AVS)
// =============================================================================
// EigenLayer is a protocol that lets Ethereum validators and stakers "restake"
// their ETH (or LSTs) to extend cryptoeconomic security to other protocols.
//
// Key actors:
//   Staker    — deposits ETH/LSTs into EigenLayer strategies to earn extra yield
//   Operator  — node runner that registers with EigenLayer, stakes get delegated to them
//   AVS       — Actively Validated Service: any protocol that wants decentralized security
//               (e.g., bridges, data availability layers, sequencers, oracles)
//   Slasher   — contract that defines slashing conditions for a specific AVS
//
// Core flow:
//   1. Staker deposits ETH → StrategyManager → gets shares
//   2. Staker delegates shares to an Operator
//   3. Operator registers with an AVS (signs terms via AVSDirectory)
//   4. AVS can slash operator's stake if they misbehave (via SlashingManager)
//   5. Operator + staker earn extra yield from AVS in return for the risk
//
// Major AVSs (2025-2026):
//   - EigenDA       : data availability layer (first major AVS)
//   - Lagrange      : ZK coprocessor network
//   - Witness Chain  : decentralized watchtower network for rollups
//   - AltLayer      : restaked rollup sequencing
//   - Hyperlane     : interchain security module
//   - Brevis        : ZK coprocessor
//
// Contract architecture (EigenLayer v0.4 / v1):
//   StrategyManager     — handles deposits of ERC-20 tokens
//   DelegationManager   — handles operator registration and delegation
//   AVSDirectory        — registry of operators per AVS
//   SlashingManager     — coordinates slashing across the protocol
//   EigenPodManager     — handles native ETH restaking via EigenPods
// =============================================================================

// =============================================================================
// SECTION 1 — CORE EIGENLAYER INTERFACES
// =============================================================================

// Represents a stake amount in a strategy
struct OperatorShares {
    address strategy;
    uint256 shares;
}

// Operator registration data
struct OperatorDetails {
    address earningsReceiver;       // where to send operator rewards
    address delegationApprover;     // can approve/reject delegations (address(0) = auto-approve)
    uint32  stakerOptOutWindowBlocks; // withdrawal notice window
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(address token, uint256 amount) external returns (uint256 shares);
    function withdraw(address recipient, address token, uint256 amountShares) external;
    function sharesToUnderlying(uint256 shares) external view returns (uint256);
    function underlyingToShares(uint256 amount) external view returns (uint256);
    function underlyingToken() external view returns (IERC20);
}

interface IStrategyManager {
    function depositIntoStrategy(
        IStrategy strategy,
        address token,
        uint256 amount
    ) external returns (uint256 shares);

    function stakerStrategyShares(address staker, IStrategy strategy)
        external view returns (uint256 shares);

    function getDeposits(address staker)
        external view returns (IStrategy[] memory, uint256[] memory);
}

interface IDelegationManager {
    function registerAsOperator(
        OperatorDetails calldata registeringOperatorDetails,
        string calldata metadataURI
    ) external;

    function delegateTo(
        address operator,
        bytes calldata approverSignatureAndExpiry, // empty if auto-approve
        bytes32 approverSalt
    ) external;

    function undelegate(address staker) external returns (bytes32[] memory withdrawalRoots);

    function operatorDetails(address operator) external view returns (OperatorDetails memory);
    function isDelegated(address staker) external view returns (bool);
    function delegatedTo(address staker) external view returns (address);
    function isOperator(address operator) external view returns (bool);

    function operatorShares(address operator, IStrategy strategy)
        external view returns (uint256);
}

interface IAVSDirectory {
    // Operator registers with an AVS — signs a registration message
    function registerOperatorToAVS(
        address operator,
        bytes calldata operatorSignature
    ) external;

    // AVS deregisters an operator
    function deregisterOperatorFromAVS(address operator) external;

    // Check if operator is registered with this AVS
    function avsOperatorStatus(address avs, address operator)
        external view returns (uint8); // 0=unregistered, 1=registered
}

// =============================================================================
// SECTION 2 — STRATEGY CONTRACT (HOLDS DEPOSITED TOKENS)
// =============================================================================
// Each EigenLayer strategy manages a single ERC-20 token.
// When a staker deposits, they receive "shares" in the strategy.
// The actual EigenLayer strategies are deployed by the EL team;
// this shows the pattern for a custom strategy (e.g., LST strategy).

contract SimpleEigenStrategy is IStrategy {
    IERC20 public immutable override underlyingToken;
    IStrategyManager public immutable strategyManager;

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    event Deposited(address indexed staker, uint256 amount, uint256 shares);
    event Withdrawn(address indexed recipient, uint256 shares, uint256 amount);

    constructor(address _token, address _strategyManager) {
        underlyingToken = IERC20(_token);
        strategyManager = IStrategyManager(_strategyManager);
    }

    modifier onlyStrategyManager() {
        require(msg.sender == address(strategyManager), "Not StrategyManager");
        _;
    }

    // Called by StrategyManager when staker deposits
    function deposit(address token, uint256 amount)
        external
        override
        onlyStrategyManager
        returns (uint256 newShares)
    {
        require(address(underlyingToken) == token, "Wrong token");
        // Share calculation: proportional to existing pool
        if (totalShares == 0) {
            newShares = amount;
        } else {
            uint256 totalUnderlying = underlyingToken.balanceOf(address(this));
            newShares = amount * totalShares / (totalUnderlying - amount);
        }
        totalShares += newShares;
        emit Deposited(msg.sender, amount, newShares);
    }

    // Called by StrategyManager when staker withdraws
    function withdraw(address recipient, address token, uint256 amountShares)
        external
        override
        onlyStrategyManager
    {
        require(address(underlyingToken) == token, "Wrong token");
        uint256 amount = sharesToUnderlying(amountShares);
        totalShares -= amountShares;
        underlyingToken.transfer(recipient, amount);
        emit Withdrawn(recipient, amountShares, amount);
    }

    function sharesToUnderlying(uint256 _shares)
        public
        view
        override
        returns (uint256)
    {
        if (totalShares == 0) return 0;
        return _shares * underlyingToken.balanceOf(address(this)) / totalShares;
    }

    function underlyingToShares(uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        uint256 totalUnderlying = underlyingToken.balanceOf(address(this));
        if (totalUnderlying == 0 || totalShares == 0) return amount;
        return amount * totalShares / totalUnderlying;
    }
}

// =============================================================================
// SECTION 3 — AVS CONTRACT (SERVICE MIDDLEWARE)
// =============================================================================
// The AVS contract is the on-chain core of an Actively Validated Service.
// It registers operators, manages tasks, and triggers slashing.
//
// EigenLayer v0.4+ provides ServiceManagerBase that AVSs inherit from.

contract AVSServiceManager {
    IDelegationManager public immutable delegationManager;
    IAVSDirectory      public immutable avsDirectory;

    address public owner;

    // Registered operators for this AVS
    mapping(address => bool) public registeredOperators;
    // Operator metadata (stake requirements, performance)
    mapping(address => OperatorInfo) public operatorInfo;

    struct OperatorInfo {
        uint256 registeredAt;
        uint256 tasksCompleted;
        uint256 tasksFailed;
        bool    active;
    }

    event OperatorRegistered(address indexed operator);
    event OperatorDeregistered(address indexed operator);
    event TaskCreated(uint256 indexed taskId, bytes taskData);
    event TaskResponded(uint256 indexed taskId, address indexed operator);

    error NotRegistered();
    error AlreadyRegistered();
    error InsufficientStake();
    error NotOwner();

    // Minimum operator stake in ETH equivalent (wei) required for this AVS
    uint256 public constant MIN_STAKE = 32 ether;

    uint256 public taskCount;
    mapping(uint256 => Task) public tasks;

    struct Task {
        bytes   data;
        uint256 createdAt;
        uint256 deadline;
        bool    completed;
        address completedBy;
    }

    constructor(address _delegationManager, address _avsDirectory) {
        delegationManager = IDelegationManager(_delegationManager);
        avsDirectory = IAVSDirectory(_avsDirectory);
        owner = msg.sender;
    }

    // ==========================================================================
    // Operator registration with EigenLayer
    // ==========================================================================

    // Operator calls this to join this AVS.
    // They must already be registered as an operator in EigenLayer.
    // operatorSignature = EIP-712 signature over registration message
    function registerOperatorToAVS(
        address operator,
        bytes calldata operatorSignature
    ) external {
        if (registeredOperators[operator]) revert AlreadyRegistered();

        // Verify operator is registered with EigenLayer DelegationManager
        require(
            delegationManager.isOperator(operator),
            "Not an EigenLayer operator"
        );

        // Check operator has sufficient delegated stake for this AVS
        // (In practice: sum across all strategies they accepted)
        // This is simplified — real AVS would query operatorShares across strategies
        require(_getOperatorTotalStake(operator) >= MIN_STAKE, "Insufficient stake");

        // Register with AVSDirectory — logs this on EigenLayer's registry
        avsDirectory.registerOperatorToAVS(operator, operatorSignature);

        registeredOperators[operator] = true;
        operatorInfo[operator] = OperatorInfo({
            registeredAt:    block.timestamp,
            tasksCompleted:  0,
            tasksFailed:     0,
            active:          true
        });

        emit OperatorRegistered(operator);
    }

    function deregisterOperator(address operator) external {
        require(msg.sender == operator || msg.sender == owner, "Not authorized");
        if (!registeredOperators[operator]) revert NotRegistered();

        avsDirectory.deregisterOperatorFromAVS(operator);
        registeredOperators[operator] = false;
        operatorInfo[operator].active = false;

        emit OperatorDeregistered(operator);
    }

    // ==========================================================================
    // Task lifecycle
    // ==========================================================================

    // AVS creates a task that registered operators must respond to
    function createTask(bytes calldata data, uint256 deadline)
        external
        returns (uint256 taskId)
    {
        require(msg.sender == owner, "Not owner");
        taskId = taskCount++;
        tasks[taskId] = Task({
            data:        data,
            createdAt:   block.timestamp,
            deadline:    deadline,
            completed:   false,
            completedBy: address(0)
        });
        emit TaskCreated(taskId, data);
    }

    // Operator submits their response to a task
    function respondToTask(
        uint256 taskId,
        bytes calldata response,
        bytes calldata signature
    ) external {
        if (!registeredOperators[msg.sender]) revert NotRegistered();

        Task storage task = tasks[taskId];
        require(!task.completed, "Task already completed");
        require(block.timestamp <= task.deadline, "Task expired");

        // Verify the response is valid for this task
        // In a real AVS: verify BLS signature or ZK proof of correct computation
        _verifyResponse(taskId, task.data, response, signature);

        task.completed   = true;
        task.completedBy = msg.sender;
        operatorInfo[msg.sender].tasksCompleted++;

        emit TaskResponded(taskId, msg.sender);
    }

    function _verifyResponse(
        uint256 taskId,
        bytes memory taskData,
        bytes memory response,
        bytes memory signature
    ) internal view {
        // In production: verify BLS aggregate signature over task response
        // For simplicity: verify ECDSA signature over hash(taskId, response)
        bytes32 hash = keccak256(abi.encode(taskId, taskData, response));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        address signer = _recoverSigner(ethHash, signature);
        require(signer == msg.sender, "Invalid signature");
    }

    function _getOperatorTotalStake(address operator) internal view returns (uint256) {
        // Simplified: in practice query operatorShares across all accepted strategies
        // Real implementation would iterate over strategy list and convert shares to ETH
        return 32 ether; // placeholder — always returns minimum for this example
    }

    function _recoverSigner(bytes32 hash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Bad sig");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(hash, v, r, s);
    }
}

// =============================================================================
// SECTION 4 — SLASHING CONDITIONS
// =============================================================================
// Slashing is the penalty mechanism for misbehaving operators.
// In EigenLayer v1, slashing is coordinated via the SlashingManager.
// Each AVS defines its own slashing conditions (when and how much to slash).
//
// IMPORTANT: Slashing design is the most critical security decision in an AVS.
// Over-slashing destroys operator trust; under-slashing enables attacks.

// Slashing evidence types for a data availability AVS
enum SlashingReason {
    DataWithheld,         // operator signed a DA certificate but withheld data
    EquivocationSigned,   // signed two conflicting certificates for same slot
    DowntimeProlonged,    // offline for more than MAX_DOWNTIME blocks
    IncorrectResponse     // provably wrong computation output
}

struct SlashingEvidence {
    address operator;
    SlashingReason reason;
    bytes evidence;       // proof of misbehavior (chain data, signatures, etc.)
    uint256 slashBps;     // basis points of stake to slash (e.g., 1000 = 10%)
}

contract AVSSlashingManager {
    IDelegationManager public immutable delegationManager;
    AVSServiceManager  public immutable serviceManager;

    // Maximum slash per incident (to bound operator risk)
    uint256 public constant MAX_SLASH_BPS = 1000; // 10% max per slash
    uint256 public constant BPS_DENOM     = 10_000;

    address public slashingCommittee; // multisig or governance that approves slashes
    uint256 public slashingDelay = 3 days; // time for operator to challenge

    struct PendingSlash {
        SlashingEvidence evidence;
        uint256 proposedAt;
        bool    executed;
        bool    cancelled;
    }

    mapping(uint256 => PendingSlash) public pendingSlashes;
    uint256 public slashCount;

    event SlashProposed(uint256 indexed slashId, address indexed operator, uint256 slashBps);
    event SlashExecuted(uint256 indexed slashId, address indexed operator);
    event SlashCancelled(uint256 indexed slashId, string reason);

    error NotCommittee();
    error TooEarly();
    error AlreadyExecuted();
    error SlashTooLarge();

    constructor(address _delegationManager, address _serviceManager, address _committee) {
        delegationManager = IDelegationManager(_delegationManager);
        serviceManager    = AVSServiceManager(_serviceManager);
        slashingCommittee = _committee;
    }

    // Phase 1: Propose a slash — anyone can propose, committee must approve
    function proposeSlash(SlashingEvidence calldata evidence)
        external
        returns (uint256 slashId)
    {
        require(evidence.slashBps <= MAX_SLASH_BPS, "Slash exceeds maximum");
        slashId = slashCount++;
        pendingSlashes[slashId] = PendingSlash({
            evidence:    evidence,
            proposedAt:  block.timestamp,
            executed:    false,
            cancelled:   false
        });
        emit SlashProposed(slashId, evidence.operator, evidence.slashBps);
    }

    // Phase 2: Execute after delay — only committee can execute
    function executeSlash(uint256 slashId) external {
        if (msg.sender != slashingCommittee) revert NotCommittee();

        PendingSlash storage pending = pendingSlashes[slashId];
        if (pending.executed)                          revert AlreadyExecuted();
        if (block.timestamp < pending.proposedAt + slashingDelay) revert TooEarly();

        pending.executed = true;

        // Validate evidence before slashing
        _validateEvidence(pending.evidence);

        // Execute the slash via EigenLayer's slashing mechanism
        // In EigenLayer v1: call slashingManager.slashOperator(operator, strategies, bps)
        // Here we emit the event for demonstration
        emit SlashExecuted(slashId, pending.evidence.operator);
    }

    // Governance can cancel a slash if the evidence is wrong
    function cancelSlash(uint256 slashId, string calldata reason) external {
        if (msg.sender != slashingCommittee) revert NotCommittee();
        PendingSlash storage pending = pendingSlashes[slashId];
        require(!pending.executed, "Already executed");
        pending.cancelled = true;
        emit SlashCancelled(slashId, reason);
    }

    function _validateEvidence(SlashingEvidence memory evidence) internal pure {
        // In production: validate evidence based on reason type:
        // - DataWithheld: verify DA certificate signature + sampling failure proof
        // - EquivocationSigned: two signed messages for same slot with different data
        // - DowntimeProlonged: heartbeat timestamps from registry
        // - IncorrectResponse: ZK proof of incorrect computation
        require(evidence.evidence.length > 0, "Empty evidence");
    }
}

// =============================================================================
// SECTION 5 — STAKER FLOW: DEPOSIT AND DELEGATE
// =============================================================================
// Shows the full staker journey: deposit → delegate → restake for AVS

contract EigenLayerStakerHelper {
    IStrategyManager  public immutable strategyManager;
    IDelegationManager public immutable delegationManager;

    event Deposited(address indexed staker, address strategy, uint256 shares);
    event Delegated(address indexed staker, address indexed operator);

    constructor(address _strategyManager, address _delegationManager) {
        strategyManager   = IStrategyManager(_strategyManager);
        delegationManager = IDelegationManager(_delegationManager);
    }

    // Step 1: Stake ETH or LST into an EigenLayer strategy
    function deposit(
        address token,
        IStrategy strategy,
        uint256 amount
    ) external returns (uint256 shares) {
        // Approve StrategyManager to pull tokens from staker
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(strategyManager), amount);

        // Deposit into strategy — staker receives shares
        shares = strategyManager.depositIntoStrategy(strategy, token, amount);
        emit Deposited(msg.sender, address(strategy), shares);
    }

    // Step 2: Delegate shares to an operator
    // Once delegated, operator's stake increases — enabling AVS participation
    function delegateTo(address operator) external {
        require(delegationManager.isOperator(operator), "Not a registered operator");

        delegationManager.delegateTo(
            operator,
            "",   // no approver signature needed (auto-approve)
            bytes32(0)
        );
        emit Delegated(msg.sender, operator);
    }

    // View: check total restaked value for a staker across all strategies
    function getStakerPortfolio(address staker)
        external
        view
        returns (IStrategy[] memory strategies, uint256[] memory shares)
    {
        return strategyManager.getDeposits(staker);
    }
}

// =============================================================================
// SECTION 6 — OPERATOR REGISTRATION FLOW
// =============================================================================

contract EigenLayerOperatorHelper {
    IDelegationManager public immutable delegationManager;
    IAVSDirectory      public immutable avsDirectory;

    constructor(address _delegationManager, address _avsDirectory) {
        delegationManager = IDelegationManager(_delegationManager);
        avsDirectory      = IAVSDirectory(_avsDirectory);
    }

    // Step 1: Register as an operator in EigenLayer
    function registerAsOperator(
        address earningsReceiver,
        uint32  stakerOptOutWindowBlocks,
        string calldata metadataURI
    ) external {
        OperatorDetails memory details = OperatorDetails({
            earningsReceiver:         earningsReceiver,
            delegationApprover:       address(0), // auto-approve all delegations
            stakerOptOutWindowBlocks: stakerOptOutWindowBlocks
        });
        delegationManager.registerAsOperator(details, metadataURI);
    }

    // Step 2: Register with a specific AVS to start earning AVS rewards
    // The operator must sign a registration message for the AVS
    function registerWithAVS(
        address avs,
        bytes calldata operatorSignature
    ) external {
        // This calls AVSDirectory which tracks operator-AVS relationships
        // The AVS contract itself may have additional requirements
        IAVSDirectory(avs).registerOperatorToAVS(msg.sender, operatorSignature);
    }
}

// =============================================================================
// SECTION 7 — WITHDRAWAL AND UNBONDING
// =============================================================================
// EigenLayer has a withdrawal delay (currently 7 days on mainnet).
// This ensures the slashing window is still valid when withdrawal is pending.
// Operators also have a stakerOptOutWindow before they can exit.

contract EigenLayerWithdrawalHelper {
    IDelegationManager public immutable delegationManager;

    // EigenLayer withdrawal delay (set on DelegationManager)
    uint256 public constant WITHDRAWAL_DELAY_BLOCKS = 50400; // ~7 days at 12s/block

    event WithdrawalQueued(address indexed staker, bytes32[] roots);
    event UndelegationQueued(address indexed staker, bytes32[] roots);

    constructor(address _delegationManager) {
        delegationManager = IDelegationManager(_delegationManager);
    }

    // Queue a withdrawal — starts the 7-day delay
    // After delay, call completeQueuedWithdrawal on DelegationManager
    function queueWithdrawal(address staker) external returns (bytes32[] memory roots) {
        require(msg.sender == staker, "Not staker");
        // Undelegate: queues withdrawal of all shares from current operator
        roots = delegationManager.undelegate(staker);
        emit UndelegationQueued(staker, roots);
    }
}

// =============================================================================
// SECTION 8 — AVS REWARD DISTRIBUTION
// =============================================================================
// Operators earn rewards for participating in AVS tasks.
// EigenLayer provides a RewardsCoordinator that handles reward distribution.
// AVS owners submit reward roots; operators/stakers claim via Merkle proofs.

interface IRewardsCoordinator {
    struct RewardsSubmission {
        StrategyAndMultiplier[] strategiesAndMultipliers;
        address token;
        uint256 amount;
        uint32  startTimestamp;
        uint32  duration;
    }

    struct StrategyAndMultiplier {
        IStrategy strategy;
        uint96    multiplier; // relative weight of this strategy
    }

    // AVS submits rewards to be distributed to operators + their stakers
    function createAVSRewardsSubmission(
        RewardsSubmission[] calldata submissions
    ) external;
}

contract AVSRewardManager {
    IRewardsCoordinator public immutable rewardsCoordinator;
    address public immutable rewardToken;
    address public owner;

    uint256 public constant EPOCH_DURATION = 7 days;
    uint256 public totalRewardsPerEpoch;

    constructor(address _coordinator, address _rewardToken, uint256 _rewardsPerEpoch) {
        rewardsCoordinator   = IRewardsCoordinator(_coordinator);
        rewardToken          = _rewardToken;
        totalRewardsPerEpoch = _rewardsPerEpoch;
        owner                = msg.sender;
    }

    // Distribute this epoch's rewards to operators via EigenLayer's coordinator
    function distributeEpochRewards(
        IStrategy[] calldata strategies,
        uint96[]    calldata multipliers
    ) external {
        require(msg.sender == owner, "Not owner");
        require(strategies.length == multipliers.length, "Length mismatch");

        IRewardsCoordinator.StrategyAndMultiplier[] memory sm =
            new IRewardsCoordinator.StrategyAndMultiplier[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            sm[i] = IRewardsCoordinator.StrategyAndMultiplier({
                strategy:   strategies[i],
                multiplier: multipliers[i]
            });
        }

        IRewardsCoordinator.RewardsSubmission[] memory submissions =
            new IRewardsCoordinator.RewardsSubmission[](1);
        submissions[0] = IRewardsCoordinator.RewardsSubmission({
            strategiesAndMultipliers: sm,
            token:                    rewardToken,
            amount:                   totalRewardsPerEpoch,
            startTimestamp:           uint32(block.timestamp - EPOCH_DURATION),
            duration:                 uint32(EPOCH_DURATION)
        });

        // Approve and submit
        IERC20(rewardToken).approve(address(rewardsCoordinator), totalRewardsPerEpoch);
        rewardsCoordinator.createAVSRewardsSubmission(submissions);
    }
}

// =============================================================================
// SECTION 9 — EIGENPOD: NATIVE ETH RESTAKING
// =============================================================================
// For validators with native ETH staking (not LSTs):
// - Validator sets withdrawal credentials to their EigenPod address
// - EigenPod proves beacon chain state to EigenLayer via SSZ proofs
// - Staker can delegate their beacon ETH stake to operators

// EigenPod interface (simplified)
interface IEigenPod {
    // Called after the pod receives ETH from the beacon chain
    function activateRestaking() external;

    // Verify a validator's full withdrawal via beacon chain proof
    function verifyAndProcessWithdrawals(
        uint64 oracleTimestamp,
        bytes calldata stateRootProof,
        bytes[] calldata withdrawalProofs,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields,
        bytes32[][] calldata withdrawalFields
    ) external;
}

interface IEigenPodManager {
    // Create an EigenPod for the caller (one per staker)
    function createPod() external returns (address);
    // Get the EigenPod address for a staker
    function getPod(address staker) external view returns (IEigenPod);
    // Check if a staker has an EigenPod
    function hasPod(address staker) external view returns (bool);
}

// Example: Validator operator that manages an EigenPod for native restaking
contract ValidatorRestaker {
    IEigenPodManager   public immutable podManager;
    IDelegationManager public immutable delegationManager;

    address public owner;
    IEigenPod public pod;

    event PodCreated(address pod);
    event RestakingActivated();

    constructor(address _podManager, address _delegationManager) {
        podManager        = IEigenPodManager(_podManager);
        delegationManager = IDelegationManager(_delegationManager);
        owner             = msg.sender;
    }

    // Step 1: Create an EigenPod — set validator withdrawal credentials to this address
    function createPod() external returns (address podAddress) {
        require(msg.sender == owner, "Not owner");
        podAddress = podManager.createPod();
        pod = IEigenPod(podAddress);
        emit PodCreated(podAddress);
    }

    // Step 2: After setting withdrawal credentials, activate restaking
    function activateRestaking() external {
        require(msg.sender == owner, "Not owner");
        pod.activateRestaking();
        emit RestakingActivated();
    }

    // Step 3: Delegate the native ETH stake to an operator
    function delegateToOperator(address operator) external {
        require(msg.sender == owner, "Not owner");
        delegationManager.delegateTo(operator, "", bytes32(0));
    }
}

// =============================================================================
// SECTION 10 — RISK MODEL AND SECURITY CONSIDERATIONS
// =============================================================================
//
// RISK 1: Correlated slashing
//   - If many operators run the same software and it has a bug, ALL get slashed
//   - AVS should require operator diversity (different clients, geographies)
//   - MITIGATION: maximum slash per incident capped; insurance fund
//
// RISK 2: Stake concentration
//   - If one operator controls 33%+ of AVS stake, they can attack it cheaply
//   - MITIGATION: maximum operator share cap, minimum number of operators
//
// RISK 3: Withdrawal timing attacks
//   - Operator detects upcoming slash → queues withdrawal first to escape
//   - EigenLayer's answer: withdrawal delay must be >= operator opt-out window
//   - MITIGATION: slashingDelay < stakerOptOutWindowBlocks enforced on-chain
//
// RISK 4: Oracle manipulation for evidence
//   - If slashing relies on an oracle to report misbehavior, oracle can be attacked
//   - MITIGATION: use fraud proofs on-chain (verify directly, not via oracle)
//
// RISK 5: Economic security budget exhaustion
//   - If an AVS extracts all value, operators/stakers have no incentive to stay
//   - MITIGATION: reward > risk * slashProbability for rational operators
//
// ECONOMIC FORMULA:
//   Expected AVS return for operator = reward - (slashProbability * slashAmount)
//   Operator will participate if: reward > slashProbability * slashAmount
//   AVS is secure if: cost of attack > economic gain from attack
//   Total economic security = sum of all staked capital at risk

// =============================================================================
// PROFESSIONAL CHECKLIST: EIGENLAYER AVS AUDIT POINTS
// =============================================================================
//
// [ ] Operator registration: verify isOperator() on DelegationManager before accepting
// [ ] Minimum stake: enforce MIN_STAKE threshold, reject underfunded operators
// [ ] Slashing cap: MAX_SLASH_BPS prevents existential risk per incident
// [ ] Slashing delay: challenge period before slash executes (fraud proof window)
// [ ] Evidence validation: on-chain verifiable evidence, not just oracle claims
// [ ] Withdrawal timing: stakerOptOutWindow >= slashing investigation period
// [ ] Operator cap: no single operator > 33% of AVS stake
// [ ] Reward distribution: use EigenLayer RewardsCoordinator, not custom distribution
// [ ] AVSDirectory: always register/deregister via IAVSDirectory for composability
// [ ] MetadataURI: operator and AVS metadata URIs should point to IPFS (immutable)
// [ ] Task timeout: tasks with deadlines should handle operator non-response gracefully
// [ ] EigenPod: withdrawal credentials must be set before any deposits to beacon
// [ ] Correlated slashing: monitor for operator software diversity
// [ ] Fee structure: operator commission rate documented and bounded
