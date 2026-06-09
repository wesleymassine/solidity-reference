// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// =============================================================================
// ON-CHAIN GOVERNANCE: GOVERNOR + TIMELOCK + DAO PATTERNS
// =============================================================================
// On-chain governance lets token holders vote on protocol changes without
// trusting a multisig or centralized team. The result is executed automatically
// on-chain after a successful vote.
//
// Standard architecture (OpenZeppelin Governor):
//   GovernanceToken  — ERC-20 with vote delegation (ERC-20Votes)
//   Governor         — accepts proposals, tallies votes, queues winners
//   TimelockController — holds protocol ownership, enforces execution delay
//
// Proposal lifecycle:
//   1. Propose   — any token holder with enough tokens creates a proposal
//   2. Delay     — voting delay period (e.g., 1 day) before voting starts
//   3. Vote      — voting period (e.g., 1 week) where holders vote
//   4. Queue     — successful proposals are queued in the Timelock
//   5. Execute   — after timelock delay (e.g., 2 days), anyone can execute
//   6. (Cancel)  — proposer or guardian can cancel before execution
//
// Governor modules (mix and match):
//   GovernorVotes          — integrate ERC-20Votes or ERC-721Votes
//   GovernorVotesQuorumFraction — quorum as % of total supply
//   GovernorTimelockControl — queue/execute via TimelockController
//   GovernorSettings       — voting delay/period/proposal threshold as params
//   GovernorBravo          — Compound-style compatibility
//
// Real examples:
//   Uniswap     — UNI token, Governor Bravo
//   Compound    — COMP token, Governor Bravo (the original)
//   Aave        — AAVE + stkAAVE, AaveGovernanceV2
//   ENS         — ENS token, OpenZeppelin Governor
//   Nouns DAO   — NFT-based voting (1 Noun = 1 vote)
// =============================================================================

// =============================================================================
// SECTION 1 — GOVERNANCE TOKEN (ERC-20 WITH VOTE DELEGATION)
// =============================================================================
// Voting power comes from token balance at the time of proposal creation.
// Delegation allows users to assign their voting power to a delegate
// without transferring tokens. This enables professional delegates (a16z, etc.)

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract GovernanceToken {
    string  public constant name     = "Governance Token";
    string  public constant symbol   = "GOV";
    uint8   public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ERC-20Votes: delegation and historical checkpoints
    mapping(address => address) public delegates;         // account → delegate
    mapping(address => uint256) public numCheckpoints;
    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    struct Checkpoint {
        uint32  fromBlock;
        uint224 votes;
    }

    // EIP-712 for delegation signatures
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    mapping(address => uint256) public delegationNonces;

    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    constructor() {
        minter = msg.sender;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Not minter");
        totalSupply += amount;
        balanceOf[to] += amount;
        _moveDelegates(address(0), delegates[to], amount);
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        // Update voting power of the delegate when tokens move
        _moveDelegates(delegates[from], delegates[to], amount);
        emit Transfer(from, to, amount);
    }

    // ==========================================================================
    // Delegation
    // ==========================================================================

    // Delegate voting power to another address (or self for direct voting)
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    // Delegate via EIP-712 signature (allows gasless delegation)
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v, bytes32 r, bytes32 s
    ) external {
        require(block.timestamp <= expiry, "Delegation expired");
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        require(nonce == delegationNonces[signatory]++, "Invalid nonce");
        _delegate(signatory, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf[delegator];
        delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint256 fromNum = numCheckpoints[from];
                uint256 fromOld = fromNum > 0 ? checkpoints[from][fromNum - 1].votes : 0;
                _writeCheckpoint(from, fromNum, fromOld, fromOld - amount);
            }
            if (to != address(0)) {
                uint256 toNum = numCheckpoints[to];
                uint256 toOld = toNum > 0 ? checkpoints[to][toNum - 1].votes : 0;
                _writeCheckpoint(to, toNum, toOld, toOld + amount);
            }
        }
    }

    function _writeCheckpoint(address account, uint256 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        if (nCheckpoints > 0 && checkpoints[account][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[account][nCheckpoints - 1].votes = uint224(newVotes);
        } else {
            checkpoints[account][nCheckpoints] = Checkpoint(uint32(block.number), uint224(newVotes));
            numCheckpoints[account] = nCheckpoints + 1;
        }
        emit DelegateVotesChanged(account, oldVotes, newVotes);
    }

    // Get votes at a specific past block (used by Governor for snapshot)
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "Not yet determined");
        return _checkpointsLookup(checkpoints[account], numCheckpoints[account], blockNumber);
    }

    function getCurrentVotes(address account) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    function _checkpointsLookup(
        mapping(uint256 => Checkpoint) storage ckpts,
        uint256 nCkpts,
        uint256 blockNumber
    ) internal view returns (uint256) {
        if (nCkpts == 0) return 0;
        if (ckpts[nCkpts - 1].fromBlock <= blockNumber) return ckpts[nCkpts - 1].votes;
        if (ckpts[0].fromBlock > blockNumber) return 0;
        // Binary search
        uint256 lower = 0;
        uint256 upper = nCkpts - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = ckpts[center];
            if (cp.fromBlock == blockNumber) return cp.votes;
            else if (cp.fromBlock < blockNumber) lower = center;
            else upper = center - 1;
        }
        return ckpts[lower].votes;
    }
}

// =============================================================================
// SECTION 2 — TIMELOCK CONTROLLER
// =============================================================================
// Holds protocol ownership and enforces a mandatory delay between
// a successful vote and execution. This gives the community time to react
// (exit positions, veto via guardian) if a malicious proposal passes.

contract TimelockController {
    uint256 public minDelay;    // minimum delay in seconds (e.g., 2 days)
    uint256 public constant GRACE_PERIOD = 14 days; // deadline to execute after delay

    mapping(bytes32 => uint256) public timestamps; // operationId → eta

    // Roles
    mapping(address => bool) public proposers;  // can schedule (Governor contract)
    mapping(address => bool) public executors;  // can execute (address(0) = anyone)
    mapping(address => bool) public cancellers; // can cancel (guardian multisig)
    address public admin;

    enum OperationState { Unset, Waiting, Ready, Done }

    event CallScheduled(bytes32 indexed id, uint256 index, address target, uint256 value, bytes data, uint256 delay);
    event CallExecuted(bytes32 indexed id, uint256 index, address target, uint256 value, bytes data);
    event Cancelled(bytes32 indexed id);
    event MinDelayChanged(uint256 oldDelay, uint256 newDelay);

    error OperationAlreadyScheduled();
    error OperationNotReady();
    error OperationExpired();
    error InsufficientDelay();
    error NotProposer();
    error NotExecutor();
    error NotCanceller();

    constructor(uint256 _minDelay, address[] memory _proposers, address[] memory _executors) {
        minDelay = _minDelay;
        admin = msg.sender;
        for (uint256 i = 0; i < _proposers.length; i++) proposers[_proposers[i]] = true;
        for (uint256 i = 0; i < _executors.length; i++) executors[_executors[i]] = true;
        cancellers[msg.sender] = true; // deployer is initial canceller
    }

    modifier onlyRole(mapping(address => bool) storage role) {
        require(role[msg.sender] || msg.sender == admin, "Access denied");
        _;
    }

    // Compute the unique operation ID for a batch of calls
    function hashOperation(
        address target, uint256 value, bytes calldata data,
        bytes32 predecessor, bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function hashOperationBatch(
        address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads,
        bytes32 predecessor, bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
    }

    // Schedule a single operation (called by Governor after vote passes)
    function schedule(
        address target, uint256 value, bytes calldata data,
        bytes32 predecessor, bytes32 salt, uint256 delay
    ) external onlyRole(proposers) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        if (timestamps[id] != 0) revert OperationAlreadyScheduled();
        if (delay < minDelay) revert InsufficientDelay();
        timestamps[id] = block.timestamp + delay;
        emit CallScheduled(id, 0, target, value, data, delay);
    }

    // Schedule a batch of calls in one timelock operation
    function scheduleBatch(
        address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads,
        bytes32 predecessor, bytes32 salt, uint256 delay
    ) external onlyRole(proposers) {
        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        if (timestamps[id] != 0) revert OperationAlreadyScheduled();
        if (delay < minDelay) revert InsufficientDelay();
        timestamps[id] = block.timestamp + delay;
        for (uint256 i = 0; i < targets.length; i++) {
            emit CallScheduled(id, i, targets[i], values[i], payloads[i], delay);
        }
    }

    // Execute after delay has passed
    function execute(
        address target, uint256 value, bytes calldata payload,
        bytes32 predecessor, bytes32 salt
    ) external payable {
        if (!executors[msg.sender] && !executors[address(0)]) revert NotExecutor();
        bytes32 id = hashOperation(target, value, payload, predecessor, salt);
        _beforeCall(id, predecessor);
        _execute(target, value, payload);
        emit CallExecuted(id, 0, target, value, payload);
        _afterCall(id);
    }

    function executeBatch(
        address[] calldata targets, uint256[] calldata values, bytes[] calldata payloads,
        bytes32 predecessor, bytes32 salt
    ) external payable {
        if (!executors[msg.sender] && !executors[address(0)]) revert NotExecutor();
        bytes32 id = hashOperationBatch(targets, values, payloads, predecessor, salt);
        _beforeCall(id, predecessor);
        for (uint256 i = 0; i < targets.length; i++) {
            _execute(targets[i], values[i], payloads[i]);
            emit CallExecuted(id, i, targets[i], values[i], payloads[i]);
        }
        _afterCall(id);
    }

    function cancel(bytes32 id) external onlyRole(cancellers) {
        require(getOperationState(id) == OperationState.Waiting, "Cannot cancel");
        delete timestamps[id];
        emit Cancelled(id);
    }

    function _beforeCall(bytes32 id, bytes32 predecessor) internal view {
        OperationState state = getOperationState(id);
        if (state == OperationState.Unset)    revert OperationNotReady();
        if (state == OperationState.Waiting)  revert OperationNotReady();
        if (state == OperationState.Done)     revert OperationAlreadyScheduled();
        // Predecessor must be done if specified
        if (predecessor != bytes32(0)) {
            require(getOperationState(predecessor) == OperationState.Done, "Predecessor not done");
        }
    }

    function _execute(address target, uint256 value, bytes calldata data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly { revert(add(result, 32), mload(result)) }
        }
    }

    function _afterCall(bytes32 id) internal {
        // Mark as done — set timestamp to 1 (non-zero = done, non-future = executed)
        timestamps[id] = 1;
    }

    function getOperationState(bytes32 id) public view returns (OperationState) {
        uint256 timestamp = timestamps[id];
        if (timestamp == 0) return OperationState.Unset;
        if (timestamp == 1) return OperationState.Done;
        if (timestamp > block.timestamp) return OperationState.Waiting;
        if (block.timestamp <= timestamp + GRACE_PERIOD) return OperationState.Ready;
        return OperationState.Done; // grace period expired — treat as done (expired)
    }

    function isOperation(bytes32 id) external view returns (bool) {
        return timestamps[id] > 0;
    }

    function isOperationReady(bytes32 id) external view returns (bool) {
        return getOperationState(id) == OperationState.Ready;
    }

    function updateDelay(uint256 newDelay) external {
        require(msg.sender == address(this), "TimelockController: caller must be timelock");
        emit MinDelayChanged(minDelay, newDelay);
        minDelay = newDelay;
    }

    receive() external payable {}
}

// =============================================================================
// SECTION 3 — GOVERNOR CONTRACT
// =============================================================================
// The Governor accepts proposals, manages the voting period, tallies votes,
// and queues successful proposals in the Timelock for execution.

contract Governor {
    GovernanceToken public immutable token;
    TimelockController public immutable timelock;

    // Governance parameters (can be updated via governance itself)
    uint256 public votingDelay    = 1 days;      // blocks before voting starts
    uint256 public votingPeriod   = 1 weeks;     // duration of voting
    uint256 public proposalThreshold = 1_000e18; // min tokens to propose
    uint256 public quorumNumerator   = 4;        // 4% quorum of total supply

    enum ProposalState {
        Pending,   // created, not yet in voting
        Active,    // voting in progress
        Canceled,
        Defeated,  // quorum not reached or majority against
        Succeeded, // passed, not yet queued
        Queued,    // in timelock
        Expired,   // timelock grace period expired
        Executed
    }

    enum VoteType { Against, For, Abstain }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 voteStart;      // timestamp voting begins
        uint256 voteEnd;        // timestamp voting ends
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool    canceled;
        bool    executed;
        bytes32 timelockId;     // operation id in TimelockController
        // Calldata for execution
        address[] targets;
        uint256[] values;
        bytes[]   calldatas;
        string    description;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public voteChoice;

    uint256 public proposalCount;

    event ProposalCreated(
        uint256 indexed proposalId, address indexed proposer,
        address[] targets, uint256[] values, bytes[] calldatas,
        uint256 voteStart, uint256 voteEnd, string description
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 weight, string reason);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    error InsufficientVotingPower();
    error ProposalNotSucceeded();
    error ProposalNotQueued();
    error AlreadyVoted();
    error VotingNotActive();

    constructor(address _token, address payable _timelock) {
        token = GovernanceToken(_token);
        timelock = TimelockController(payable(_timelock));
    }

    // ==========================================================================
    // Proposal creation
    // ==========================================================================

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[]   calldata calldatas,
        string    calldata description
    ) external returns (uint256 proposalId) {
        // Check proposer has enough tokens
        uint256 proposerVotes = token.getCurrentVotes(msg.sender);
        if (proposerVotes < proposalThreshold) revert InsufficientVotingPower();

        proposalId = ++proposalCount;
        uint256 start = block.timestamp + votingDelay;
        uint256 end   = start + votingPeriod;

        Proposal storage p = proposals[proposalId];
        p.id          = proposalId;
        p.proposer    = msg.sender;
        p.voteStart   = start;
        p.voteEnd     = end;
        p.targets     = targets;
        p.values      = values;
        p.calldatas   = calldatas;
        p.description = description;

        emit ProposalCreated(proposalId, msg.sender, targets, values, calldatas, start, end, description);
    }

    // ==========================================================================
    // Voting
    // ==========================================================================

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight) {
        return _castVote(proposalId, msg.sender, support, "");
    }

    function castVoteWithReason(
        uint256 proposalId, uint8 support, string calldata reason
    ) external returns (uint256 weight) {
        return _castVote(proposalId, msg.sender, support, reason);
    }

    // Vote via EIP-712 signature (allows gasless voting via relayer)
    function castVoteBySig(
        uint256 proposalId, uint8 support,
        uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 weight) {
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
            keccak256("Governor"),
            block.chainid,
            address(this)
        ));
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Ballot(uint256 proposalId,uint8 support)"),
            proposalId, support
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address voter = ecrecover(digest, v, r, s);
        require(voter != address(0), "Invalid signature");
        return _castVote(proposalId, voter, support, "");
    }

    function _castVote(
        uint256 proposalId, address voter, uint8 support, string memory reason
    ) internal returns (uint256 weight) {
        Proposal storage p = proposals[proposalId];
        if (state(proposalId) != ProposalState.Active) revert VotingNotActive();
        if (hasVoted[proposalId][voter]) revert AlreadyVoted();

        // Snapshot voting power at the block voting started
        weight = token.getPastVotes(voter, p.voteStart);

        hasVoted[proposalId][voter] = true;
        voteChoice[proposalId][voter] = VoteType(support);

        if (support == uint8(VoteType.Against))  p.againstVotes += weight;
        else if (support == uint8(VoteType.For)) p.forVotes     += weight;
        else                                     p.abstainVotes += weight;

        emit VoteCast(voter, proposalId, support, weight, reason);
    }

    // ==========================================================================
    // Proposal state machine
    // ==========================================================================

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.executed)  return ProposalState.Executed;
        if (p.canceled)  return ProposalState.Canceled;
        if (block.timestamp < p.voteStart) return ProposalState.Pending;
        if (block.timestamp <= p.voteEnd)  return ProposalState.Active;

        // Voting ended — check results
        if (!_quorumReached(proposalId) || !_voteSucceeded(proposalId))
            return ProposalState.Defeated;

        // Passed — check timelock status
        bytes32 tid = p.timelockId;
        if (tid == bytes32(0)) return ProposalState.Succeeded; // not yet queued
        TimelockController.OperationState tlState = timelock.getOperationState(tid);
        if (tlState == TimelockController.OperationState.Done)    return ProposalState.Executed;
        if (tlState == TimelockController.OperationState.Waiting) return ProposalState.Queued;
        if (tlState == TimelockController.OperationState.Ready)   return ProposalState.Queued;
        return ProposalState.Expired;
    }

    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage p = proposals[proposalId];
        uint256 totalSupplyAtSnapshot = token.totalSupply(); // simplified: should use past supply
        uint256 quorum = totalSupplyAtSnapshot * quorumNumerator / 100;
        return p.forVotes + p.abstainVotes >= quorum;
    }

    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage p = proposals[proposalId];
        return p.forVotes > p.againstVotes;
    }

    // ==========================================================================
    // Queue & Execute
    // ==========================================================================

    function queue(uint256 proposalId) external returns (uint256 eta) {
        if (state(proposalId) != ProposalState.Succeeded) revert ProposalNotSucceeded();

        Proposal storage p = proposals[proposalId];
        bytes32 salt = keccak256(bytes(p.description));
        bytes32 timelockId = timelock.hashOperationBatch(
            p.targets, p.values, p.calldatas, bytes32(0), salt
        );

        timelock.scheduleBatch(
            p.targets, p.values, p.calldatas,
            bytes32(0), salt, timelock.minDelay()
        );

        p.timelockId = timelockId;
        eta = block.timestamp + timelock.minDelay();
        emit ProposalQueued(proposalId, eta);
    }

    function execute(uint256 proposalId) external payable {
        ProposalState s = state(proposalId);
        if (s != ProposalState.Queued) revert ProposalNotQueued();

        Proposal storage p = proposals[proposalId];
        p.executed = true;

        bytes32 salt = keccak256(bytes(p.description));
        timelock.executeBatch{value: msg.value}(
            p.targets, p.values, p.calldatas, bytes32(0), salt
        );

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(msg.sender == p.proposer, "Not proposer");
        require(state(proposalId) == ProposalState.Pending, "Cannot cancel");
        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // ==========================================================================
    // Parameter updates (via governance itself — goes through timelock)
    // ==========================================================================

    function setVotingDelay(uint256 newDelay) external {
        require(msg.sender == address(timelock), "Must go through governance");
        votingDelay = newDelay;
    }

    function setVotingPeriod(uint256 newPeriod) external {
        require(msg.sender == address(timelock), "Must go through governance");
        votingPeriod = newPeriod;
    }

    function setProposalThreshold(uint256 newThreshold) external {
        require(msg.sender == address(timelock), "Must go through governance");
        proposalThreshold = newThreshold;
    }
}

// =============================================================================
// SECTION 4 — GUARDIAN / VETO MECHANISM
// =============================================================================
// A guardian (multisig or council) can veto proposals that are in the
// timelock waiting phase. This is a safety mechanism during protocol infancy.
// The goal is to remove the guardian over time as governance matures.

contract GovernorGuardian {
    TimelockController public immutable timelock;
    address public guardian;
    bool public guardianEnabled = true;

    event GuardianVetoed(bytes32 indexed timelockId);
    event GuardianRenounced();

    constructor(address _timelock, address _guardian) {
        timelock = TimelockController(payable(_timelock));
        guardian = _guardian;
    }

    // Guardian can cancel a queued proposal (during its timelock wait)
    function veto(bytes32 timelockId) external {
        require(msg.sender == guardian, "Not guardian");
        require(guardianEnabled, "Guardian renounced");
        timelock.cancel(timelockId);
        emit GuardianVetoed(timelockId);
    }

    // Guardian renounces power — cannot be undone
    // Called once the protocol is mature enough to run without a safety net
    function renounceGuardian() external {
        require(msg.sender == guardian, "Not guardian");
        guardianEnabled = false;
        guardian = address(0);
        emit GuardianRenounced();
    }
}

// =============================================================================
// SECTION 5 — SNAPSHOT + ON-CHAIN EXECUTION (HYBRID GOVERNANCE)
// =============================================================================
// Many protocols use Snapshot (off-chain) for voting (free, gasless)
// but still require on-chain execution via Timelock for security.
//
// Pattern: Snapshot proposal → optimistic execution via a trusted relayer
// The relayer submits the winning action on-chain after the Snapshot vote ends.
// A challenge period allows anyone to object before execution.

contract SnapshotGovernor {
    TimelockController public immutable timelock;
    address public relayer;     // trusted Snapshot-to-onchain bridge

    uint256 public challengePeriod = 3 days;

    struct SnapshotProposal {
        bytes32 snapshotId;     // Snapshot proposal ID (off-chain reference)
        address[] targets;
        uint256[] values;
        bytes[]   calldatas;
        string    description;
        uint256   submittedAt;
        bool      challenged;
        bool      executed;
    }

    mapping(bytes32 => SnapshotProposal) public proposals;

    event SnapshotResultSubmitted(bytes32 indexed snapshotId, uint256 challengeDeadline);
    event SnapshotProposalChallenged(bytes32 indexed snapshotId);
    event SnapshotProposalExecuted(bytes32 indexed snapshotId);

    constructor(address _timelock, address _relayer) {
        timelock = TimelockController(payable(_timelock));
        relayer  = _relayer;
    }

    // Relayer submits the winning result of a Snapshot vote
    function submitResult(
        bytes32 snapshotId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[]   calldata calldatas,
        string    calldata description
    ) external {
        require(msg.sender == relayer, "Not relayer");
        proposals[snapshotId] = SnapshotProposal({
            snapshotId:  snapshotId,
            targets:     targets,
            values:      values,
            calldatas:   calldatas,
            description: description,
            submittedAt: block.timestamp,
            challenged:  false,
            executed:    false
        });
        emit SnapshotResultSubmitted(snapshotId, block.timestamp + challengePeriod);
    }

    // Anyone can challenge a submitted result during the challenge period
    // In production: challenge requires a bond and triggers a full on-chain vote
    function challenge(bytes32 snapshotId) external {
        SnapshotProposal storage p = proposals[snapshotId];
        require(block.timestamp <= p.submittedAt + challengePeriod, "Challenge period over");
        require(!p.challenged, "Already challenged");
        p.challenged = true;
        emit SnapshotProposalChallenged(snapshotId);
        // In production: escalate to full on-chain vote via Governor
    }

    // Execute after challenge period passes without a challenge
    function execute(bytes32 snapshotId) external payable {
        SnapshotProposal storage p = proposals[snapshotId];
        require(!p.challenged, "Was challenged");
        require(!p.executed, "Already executed");
        require(block.timestamp > p.submittedAt + challengePeriod, "Still in challenge period");

        p.executed = true;

        bytes32 salt = keccak256(bytes(p.description));
        timelock.scheduleBatch(p.targets, p.values, p.calldatas, bytes32(0), salt, 0);
        timelock.executeBatch{value: msg.value}(p.targets, p.values, p.calldatas, bytes32(0), salt);

        emit SnapshotProposalExecuted(snapshotId);
    }
}

// =============================================================================
// SECTION 6 — NFT GOVERNANCE (NOUNS-STYLE: 1 NFT = 1 VOTE)
// =============================================================================
// Instead of token-weighted voting, each NFT gives 1 vote.
// Prevents plutocracy (wealth concentration = vote concentration).
// Used by: Nouns DAO, Purple DAO, Gnars DAO.

interface IERC721Enumerable {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function totalSupply() external view returns (uint256);
}

contract NFTGovernor {
    IERC721Enumerable public immutable nft;
    TimelockController public immutable timelock;

    uint256 public votingPeriod   = 1 weeks;
    uint256 public proposalThreshold = 1; // need at least 1 NFT to propose
    uint256 public quorum = 10;           // minimum 10 NFTs must vote For

    struct NFTProposal {
        address proposer;
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool    executed;
        bool    canceled;
        address[] targets;
        uint256[] values;
        bytes[]   calldatas;
        mapping(uint256 => bool) nftVoted; // tokenId → voted
    }

    mapping(uint256 => NFTProposal) public proposals;
    uint256 public proposalCount;

    event Proposed(uint256 indexed proposalId, address proposer);
    event NFTVoteCast(uint256 indexed proposalId, uint256 indexed tokenId, bool support);

    constructor(address _nft, address payable _timelock) {
        nft      = IERC721Enumerable(_nft);
        timelock = TimelockController(payable(_timelock));
    }

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[]   calldata calldatas
    ) external returns (uint256 proposalId) {
        require(nft.balanceOf(msg.sender) >= proposalThreshold, "Need NFT to propose");

        proposalId = ++proposalCount;
        NFTProposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.voteEnd  = block.timestamp + votingPeriod;
        p.targets  = targets;
        p.values   = values;
        p.calldatas = calldatas;

        emit Proposed(proposalId, msg.sender);
    }

    // Voter casts votes with ALL their NFTs at once
    function castVote(uint256 proposalId, bool support) external {
        NFTProposal storage p = proposals[proposalId];
        require(block.timestamp <= p.voteEnd, "Voting ended");

        uint256 balance = nft.balanceOf(msg.sender);
        uint256 votePower = 0;

        // Each owned NFT that hasn't voted counts as 1 vote
        // NOTE: In production use a snapshotted list to prevent transfer gaming
        for (uint256 i = 0; i < balance; i++) {
            // This pattern is simplified — real Nouns-style uses an enumerated approach
            // Real impl: iterate known tokenIds owned at proposal time via off-chain snapshot
            votePower++;
        }

        if (support) p.forVotes     += votePower;
        else         p.againstVotes += votePower;
    }
}

// =============================================================================
// PROFESSIONAL CHECKLIST: GOVERNANCE AUDIT POINTS
// =============================================================================
//
// [ ] Token delegation: getPastVotes uses snapshot at voteStart block — not current balance
// [ ] Quorum: calculated on total supply at voteStart, not current supply
// [ ] Proposal threshold: checked at proposal time, not vote time
// [ ] Vote delay: prevents flash loan attacks (must hold tokens before proposal)
// [ ] Timelock minimum: delay >= 24h to give community time to react
// [ ] Grace period: proposals expire after X days past timelock ETA
// [ ] Cancellation: only proposer can cancel before voting starts
// [ ] Predecessor: timelock supports operation ordering (predecessor must be done first)
// [ ] Guardian: renounceGuardian() is irreversible — document and announce before calling
// [ ] Self-governance: changing governance params must go through the timelock
// [ ] EIP-712 voting: include chainId and verifyingContract to prevent cross-chain replay
// [ ] NFT governance: prevent vote-then-transfer attacks with proposal-time snapshots
// [ ] Snapshot hybrid: challenge period must be > withdrawal delay on timelock
// [ ] Role separation: proposer (Governor) ≠ executor (anyone) ≠ canceller (guardian)
// [ ] Timelock admin: renounce admin role after setup — timelock should govern itself
