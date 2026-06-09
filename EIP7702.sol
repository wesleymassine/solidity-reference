// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
// EIP-7702: SET EOA ACCOUNT CODE (PECTRA UPGRADE)
// =============================================================================
// EIP-7702 is introduced in the Pectra hard fork (Ethereum 2025/2026).
// It allows an EOA (Externally Owned Account) to temporarily set its code
// to that of a smart contract by signing a special authorization tuple.
//
// This is different from ERC-4337 (Account Abstraction via UserOperation):
//   - ERC-4337: requires a new EntryPoint contract; no protocol changes
//   - EIP-7702: native protocol change; EOA behaves as a smart contract
//               within a single transaction, keeping its original address
//
// Key properties:
//   - The EOA sets code = delegate contract code, NOT a proxy — full bytecode
//   - Authorization is signed with a new transaction type (type 0x04)
//   - Code is set BEFORE execution, cleared unless the delegate persists it
//   - nonce in authorization prevents replay attacks
//   - chainId = 0 in authorization = valid on all chains (use with care)
// =============================================================================

// =============================================================================
// SECTION 1 — AUTHORIZATION TUPLE STRUCTURE
// =============================================================================
// The new transaction type 0x04 (SetCode) includes an authorization_list:
//
//   authorization_list = [[chain_id, address, nonce, y_parity, r, s], ...]
//
// Fields:
//   chain_id  : 0 = any chain, or specific chainId
//   address   : the contract whose code the EOA will delegate to
//   nonce     : must match EOA's current nonce to prevent replay
//   y_parity, r, s : secp256k1 signature over (chain_id, address, nonce)
//
// After the tx is processed:
//   EOA.code = delegate.code   (execCode designation)
//   EOA behaves exactly like that contract when called
//
// The EOA can revoke by signing a new authorization with address = 0x0
// =============================================================================

// =============================================================================
// SECTION 2 — SIMPLE DELEGATE CONTRACT
// =============================================================================
// This is the contract whose code the EOA will "borrow".
// It runs in the context of the EOA — msg.sender is the original caller,
// address(this) is the EOA address, storage reads/writes go to the EOA.

contract SimpleDelegate {
    // Storage slot 0 — in the EOA's storage after delegation
    address public owner;

    // Emitted from the EOA's address
    event Executed(address indexed target, uint256 value, bytes data);
    event BatchExecuted(uint256 count);

    error NotOwner();
    error CallFailed(uint256 index);

    // Called once after the EOA receives delegation to set up ownership.
    // Since address(this) == EOA, owner will be stored in EOA's slot 0.
    function initialize(address _owner) external {
        // SECURITY: only callable when owner is unset (first-time setup)
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // Execute a single call on behalf of the EOA
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        emit Executed(target, value, data);
        return result;
    }

    // Batch execution — the main UX improvement over raw EOA
    // One tx can: approve + swap + stake in sequence
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function executeBatch(Call[] calldata calls)
        external
        payable
        onlyOwner
        returns (bytes[] memory results)
    {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].data);
            if (!success) revert CallFailed(i);
            results[i] = result;
        }
        emit BatchExecuted(calls.length);
    }

    // Allow the EOA to receive ETH
    receive() external payable {}
}

// =============================================================================
// SECTION 3 — SESSION KEYS (TEMPORARY PERMISSIONS)
// =============================================================================
// EIP-7702 enables session keys: limited-permission signers that can act
// on behalf of the EOA for a specific time window or set of contracts.
// This is crucial for gaming, DeFi automation, and subscription flows.

contract SessionKeyDelegate {
    address public owner;

    struct SessionKey {
        address key;           // address that can call execute
        uint48  validAfter;    // timestamp start
        uint48  validUntil;    // timestamp end
        address allowedTarget; // address(0) = any contract
        uint256 spendLimit;    // max ETH per session
        uint256 spent;         // ETH already spent this session
    }

    // keyAddress => session
    mapping(address => SessionKey) public sessions;

    event SessionGranted(address indexed key, uint48 validUntil);
    event SessionRevoked(address indexed key);

    error NotAuthorized();
    error SessionExpired();
    error SpendLimitExceeded();
    error TargetNotAllowed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    // Owner grants a session key with constraints
    function grantSession(
        address key,
        uint48 validAfter,
        uint48 validUntil,
        address allowedTarget,
        uint256 spendLimit
    ) external onlyOwner {
        sessions[key] = SessionKey({
            key: key,
            validAfter: validAfter,
            validUntil: validUntil,
            allowedTarget: allowedTarget,
            spendLimit: spendLimit,
            spent: 0
        });
        emit SessionGranted(key, validUntil);
    }

    // Owner revokes session key immediately
    function revokeSession(address key) external onlyOwner {
        delete sessions[key];
        emit SessionRevoked(key);
    }

    // Session key executes within its constraints
    function executeAsSession(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        SessionKey storage s = sessions[msg.sender];

        // Validate session
        if (s.key == address(0)) revert NotAuthorized();
        if (block.timestamp < s.validAfter || block.timestamp > s.validUntil)
            revert SessionExpired();
        if (s.allowedTarget != address(0) && s.allowedTarget != target)
            revert TargetNotAllowed();

        // Enforce spend limit
        s.spent += value;
        if (s.spent > s.spendLimit) revert SpendLimitExceeded();

        // Execute call
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Call failed");
        return result;
    }
}

// =============================================================================
// SECTION 4 — SPONSORED TRANSACTIONS (PAYMASTER-LIKE PATTERN)
// =============================================================================
// Without ERC-4337, EIP-7702 can achieve gas sponsorship by having a
// "sponsor" contract call the delegated EOA on its behalf.
// The sponsor pays gas; the EOA's logic runs in its own storage context.

contract SponsoredDelegate {
    address public owner;

    // Approved sponsors who can trigger actions on behalf of the EOA
    mapping(address => bool) public sponsors;

    event SponsorAdded(address indexed sponsor);
    event SponsorRemoved(address indexed sponsor);
    event SponsoredCall(address indexed sponsor, address target);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyOwnerOrSponsor() {
        require(msg.sender == owner || sponsors[msg.sender], "Not authorized");
        _;
    }

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    function addSponsor(address sponsor) external onlyOwner {
        sponsors[sponsor] = true;
        emit SponsorAdded(sponsor);
    }

    function removeSponsor(address sponsor) external onlyOwner {
        sponsors[sponsor] = false;
        emit SponsorRemoved(sponsor);
    }

    // Sponsor calls this on behalf of the EOA user.
    // The EOA's logic runs but the sponsor pays gas.
    function sponsoredExecute(
        address target,
        bytes calldata data
    ) external onlyOwnerOrSponsor returns (bytes memory) {
        emit SponsoredCall(msg.sender, target);
        (bool success, bytes memory result) = target.call(data);
        require(success, "Call failed");
        return result;
    }
}

// =============================================================================
// SECTION 5 — SIGNATURE VALIDATION (EIP-1271 COMPATIBILITY)
// =============================================================================
// When an EOA is delegated, it can implement EIP-1271 (isValidSignature),
// making it compatible with contracts that check smart contract signatures.
// This enables: Permit2, Gnosis Safe guards, and many other protocols.

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);
}

contract ERC1271Delegate is IERC1271 {
    // EIP-1271 magic value
    bytes4 private constant MAGIC_VALUE = 0x1626ba7e;

    address public owner;
    // Multiple signers can be added (multisig simulation on a single EOA)
    mapping(address => bool) public signers;

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
        signers[_owner] = true;
    }

    function addSigner(address signer) external {
        require(msg.sender == owner, "Not owner");
        signers[signer] = true;
    }

    // Validates that the signature was created by an approved signer.
    // Called by Permit2, OpenSea, Gnosis Safe guards, etc.
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4)
    {
        address recovered = _recoverSigner(hash, signature);
        if (signers[recovered]) return MAGIC_VALUE;
        return 0xffffffff;
    }

    function _recoverSigner(bytes32 hash, bytes memory sig)
        internal
        pure
        returns (address)
    {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(hash, v, r, s);
    }
}

// =============================================================================
// SECTION 6 — MULTI-CALL WITH PERMIT2 INTEGRATION
// =============================================================================
// One powerful EIP-7702 pattern: combine Permit2 signature + action in one tx.
// The EOA's code validates the Permit2 signature and sweeps tokens + acts.

interface IPermit2 {
    struct PermitTransferFrom {
        address token;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract Permit2Delegate {
    address public owner;
    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    // Pull tokens from the EOA using Permit2 signature, then execute action.
    // Caller provides the signed Permit2 data — gas-efficient single tx.
    function pullAndExecute(
        IPermit2.PermitTransferFrom calldata permit,
        bytes calldata permitSig,
        address target,
        bytes calldata data
    ) external payable {
        require(msg.sender == owner, "Not owner");

        // Transfer tokens to this EOA (address(this) == EOA when delegated)
        PERMIT2.permitTransferFrom(
            permit,
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: permit.amount
            }),
            address(this), // owner = the EOA itself
            permitSig
        );

        // Execute the downstream action (e.g., swap, stake)
        (bool success, ) = target.call{value: msg.value}(data);
        require(success, "Target call failed");
    }
}

// =============================================================================
// SECTION 7 — REVOCATION AND RE-DELEGATION
// =============================================================================
// An EOA can revoke its delegation at any time by signing a new SetCode tx
// with address = 0x0 in the authorization tuple.
// It can also re-delegate to a different contract (e.g., upgrade its "code").
//
// This contract shows patterns for managing re-delegation safely.

contract UpgradeableDelegate {
    // Stored in EOA slot 0
    address public owner;
    // Stored in EOA slot 1 — tracks which implementation version initialized
    uint256 public version;

    event Upgraded(uint256 newVersion);

    // Safe re-initialization pattern.
    // When the EOA re-delegates to a new contract version, the new code
    // calls reinitialize() to set up any new storage without clearing old state.
    function reinitialize(uint256 newVersion) external {
        require(msg.sender == owner, "Not owner");
        require(newVersion > version, "Must increment version");
        version = newVersion;
        emit Upgraded(newVersion);
    }

    // Checks if this delegate is the "latest" by comparing a known code hash.
    // Useful for: "am I running under the current delegate implementation?"
    function isCurrentDelegate(address expectedImpl) external view returns (bool) {
        // When delegated, address(this) is the EOA; extcodehash gives the EOA's code.
        bytes32 currentHash;
        assembly {
            currentHash := extcodehash(address())
        }
        bytes32 expectedHash;
        assembly {
            expectedHash := extcodehash(expectedImpl)
        }
        return currentHash == expectedHash;
    }
}

// =============================================================================
// SECTION 8 — EIP-7702 vs ERC-4337 COMPARISON
// =============================================================================
//
// | Feature                   | EIP-7702                    | ERC-4337               |
// |---------------------------|-----------------------------|------------------------|
// | Protocol change           | Yes (Pectra HF)             | No (app-layer)         |
// | EOA address preserved     | Yes                         | New contract address   |
// | Gas sponsorship           | Via sponsor contracts       | Via Paymaster          |
// | Bundler required          | No                          | Yes                    |
// | Code persistence          | Ephemeral (per-tx) or stored| Permanent              |
// | Nonce management          | Native EOA nonce            | Contract nonce         |
// | Signature scheme          | ECDSA (native)              | Custom (any)           |
// | Multicall support         | Yes (delegate code)         | Yes (callData)         |
// | Session keys              | Yes (delegate code)         | Yes (UserOperation)    |
// | Backward compatible       | Yes (EOA is still EOA)      | Yes (new account type) |
// | Best for                  | Simple UX, no infra needed  | Complex AA, relayers   |
//
// When to use EIP-7702:
//   - User already has ETH in an EOA, doesn't want to migrate
//   - Single-chain simplicity, no bundler infrastructure
//   - Temporary smart-contract behavior (session, batch, then back to EOA)
//
// When to use ERC-4337:
//   - New users onboarded directly to smart accounts
//   - Complex validation logic (multisig, social recovery, ZK proofs)
//   - Full paymaster ecosystem with Pimlico, Biconomy, etc.
//   - Need deterministic address before deployment

// =============================================================================
// SECTION 9 — SECURITY CONSIDERATIONS
// =============================================================================
//
// RISK 1: Replay across chains
//   - If chainId = 0 in authorization, the same signed tuple works on ALL chains.
//   - Always use a specific chainId unless explicitly enabling cross-chain.
//   - MITIGATION: Validate chainId in delegate's initialize().
//
// RISK 2: Storage collisions between delegate versions
//   - Different delegate contracts might interpret slot 0 differently.
//   - MITIGATION: Use ERC-7201 namespaced storage in delegates.
//
// RISK 3: Malicious delegate contract
//   - If a user signs an authorization for a malicious contract,
//     that contract can drain all ETH and tokens from the EOA.
//   - MITIGATION: Never sign authorizations for unaudited contracts.
//
// RISK 4: Front-running of authorization
//   - An attacker watching the mempool could front-run initialization.
//   - MITIGATION: Include owner address in authorization nonce or use
//     a commit-reveal scheme for sensitive initializations.
//
// RISK 5: msg.sender vs address(this) confusion
//   - When delegate code runs in EOA context:
//     address(this) = EOA address (caller's perspective: the smart account)
//     msg.sender    = whoever called the EOA (external caller)
//   - MITIGATION: Be explicit about which address represents the "owner".

contract EIP7702SecurityPatterns {
    address public owner;
    // ERC-7201-style namespaced storage to avoid collisions
    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("eip7702.delegate.v1")) - 1)) & ~bytes32(uint256(0xff));

    struct DelegateStorage {
        address owner;
        uint256 version;
        bool initialized;
        mapping(address => bool) signers;
    }

    function _storage() private pure returns (DelegateStorage storage ds) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }

    // Chain-aware initialization — prevents cross-chain replay
    function initialize(address _owner, uint256 expectedChainId) external {
        DelegateStorage storage ds = _storage();
        require(!ds.initialized, "Already initialized");
        require(block.chainid == expectedChainId, "Wrong chain");
        ds.owner = _owner;
        ds.initialized = true;
        ds.version = 1;
    }

    // Validate that caller is the legitimate owner stored in namespaced slot
    modifier onlyOwner() {
        require(msg.sender == _storage().owner, "Not owner");
        _;
    }

    function execute(address target, bytes calldata data)
        external
        onlyOwner
        returns (bytes memory)
    {
        (bool success, bytes memory result) = target.call(data);
        require(success, "Call failed");
        return result;
    }
}

// =============================================================================
// SECTION 10 — PRACTICAL EXAMPLE: ONE-CLICK DeFi INTERACTION
// =============================================================================
// Without EIP-7702: approve (tx 1) → swap (tx 2) → stake (tx 3) = 3 txs, 3 popups
// With EIP-7702:    sign authorization + send batch tx = 1 tx, 1 popup

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IStaking {
    function stake(uint256 amount) external;
}

contract OnClickDeFiDelegate {
    address public owner;

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    // Single-tx: approve token → swap → stake
    // The user signs one SetCode authorization + sends this tx.
    function approveSwapAndStake(
        address token,
        address router,
        address outputToken,
        address staking,
        uint256 amount,
        uint256 minOutput,
        uint256 deadline
    ) external {
        require(msg.sender == owner, "Not owner");

        // Step 1: approve router to spend token
        IERC20(token).approve(router, amount);

        // Step 2: swap token for outputToken
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = outputToken;
        uint256[] memory amounts = IRouter(router).swapExactTokensForTokens(
            amount, minOutput, path, address(this), deadline
        );

        // Step 3: approve staking contract and stake received tokens
        uint256 received = amounts[amounts.length - 1];
        IERC20(outputToken).approve(staking, received);
        IStaking(staking).stake(received);
    }
}

// =============================================================================
// PROFESSIONAL CHECKLIST: EIP-7702 AUDIT POINTS
// =============================================================================
//
// [ ] chainId in authorization: avoid 0 unless cross-chain is intentional
// [ ] Nonce tracking: never reuse signed authorizations
// [ ] Storage layout: use ERC-7201 namespaced storage in all delegates
// [ ] Initialization guard: require(!initialized) before setting owner
// [ ] Front-running: include expected caller in initialization data
// [ ] Re-delegation: increment version safely with reinitializer guard
// [ ] Revocation: document how users revoke (sign auth with address=0)
// [ ] Session keys: validate validAfter, validUntil, spendLimit per call
// [ ] msg.sender vs address(this): document which is "self" in your delegate
// [ ] EIP-1271: ensure isValidSignature is implemented if protocols rely on it
// [ ] Audited delegate: never sign auth for unverified contracts
// [ ] Emergency exit: ensure owner can always call revoke without delegate
