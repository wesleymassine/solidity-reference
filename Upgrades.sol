// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ============================================================
//  UPGRADES.SOL — Upgradeable Contract Patterns: Complete Reference
// ============================================================
//
//  Covers every production-grade upgrade strategy with full
//  security analysis, storage safety, and real attack scenarios.
//
//  SECTIONS:
//  1.  Proxy Architecture Overview
//  2.  Transparent Proxy Pattern
//  3.  UUPS Pattern (ERC-1822)
//  4.  Beacon Proxy Pattern
//  5.  Diamond Pattern (EIP-2535)
//  6.  ERC-7201 — Namespaced Storage
//  7.  Storage Layout Safety & Gaps
//  8.  Initializer Security
//  9.  Function Selector Clashing
//  10. Storage Collision Attacks (Deep Dive)
//  11. Upgrade Authorization Patterns
//  12. Storage Layout Verification Tools
//  13. Migration Patterns
//  14. Upgrade Security Checklist
//
// ============================================================

// ============================================================
// SECTION 1: PROXY ARCHITECTURE OVERVIEW
// ============================================================

/*
 * WHY UPGRADEABLE CONTRACTS?
 * - Fix bugs after deployment
 * - Add features without redeploying
 * - Preserve state (users don't need to migrate)
 * - Keep the same address (integrations don't break)
 *
 * HOW PROXIES WORK:
 *   User → Proxy (DELEGATECALL) → Implementation
 *   - Storage lives in the Proxy
 *   - Logic lives in the Implementation
 *   - msg.sender and msg.value are preserved in DELEGATECALL
 *   - Implementation reads/writes Proxy's storage
 *
 * PATTERN COMPARISON:
 * ┌──────────────────┬───────────┬──────────┬────────┬─────────┐
 * │ Pattern          │ Gas/call  │ Upgrader │ Beacon │ Facets  │
 * ├──────────────────┼───────────┼──────────┼────────┼─────────┤
 * │ Transparent      │ +overhead │ Admin    │ No     │ No      │
 * │                  │ (ifAdmin) │ (proxy)  │        │         │
 * ├──────────────────┼───────────┼──────────┼────────┼─────────┤
 * │ UUPS             │ Minimal   │ Owner    │ No     │ No      │
 * │                  │           │ (impl)   │        │         │
 * ├──────────────────┼───────────┼──────────┼────────┼─────────┤
 * │ Beacon           │ +2 reads  │ Beacon   │ Yes    │ No      │
 * │                  │           │ owner    │ (1tx)  │         │
 * ├──────────────────┼───────────┼──────────┼────────┼─────────┤
 * │ Diamond          │ +1 read   │ Diamond  │ No     │ Yes     │
 * │ (EIP-2535)       │           │ owner    │        │ (multi) │
 * └──────────────────┴───────────┴──────────┴────────┴─────────┘
 *
 * WHEN TO USE EACH:
 * Transparent  → Simple projects, developer familiar with OZ tooling
 * UUPS         → Gas-efficient, upgrade logic in implementation (preferred)
 * Beacon       → Many proxy instances all sharing one implementation
 *                (e.g., factory of clones: AMM pairs, vaults per user)
 * Diamond      → Complex protocols hitting 24KB size limit, or needing
 *                granular upgrade of individual functions
 *
 * HONEST TRADE-OFF:
 * Upgradeability = trust assumption.
 * Users must trust whoever controls the upgrade key.
 * Timelocks + multisigs reduce this risk but don't eliminate it.
 * Consider whether your protocol actually needs upgradeability.
 */

// ============================================================
// SECTION 2: TRANSPARENT PROXY PATTERN
// ============================================================

/*
 * KEY PROPERTY:
 * The admin can only call admin functions (upgrade, changeAdmin).
 * The admin cannot accidentally call implementation functions.
 * Regular users can only call implementation functions.
 *
 * WHY: Prevents the "transparent proxy" selector collision attack
 * where admin calls are mistakenly routed to implementation.
 *
 * STORAGE SLOT for implementation address:
 * EIP-1967: keccak256("eip1967.proxy.implementation") - 1
 * = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
 *
 * STORAGE SLOT for admin address:
 * EIP-1967: keccak256("eip1967.proxy.admin") - 1
 * = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
 *
 * ATTACK PREVENTED: If admin could call implementation functions,
 * an attacker who tricks the admin into calling a function with
 * the same selector as `upgradeTo` could hijack the proxy.
 */

/// @title TransparentProxy — EIP-1967 transparent upgradeable proxy
contract TransparentProxy {

    // EIP-1967 slots — deliberately non-sequential to avoid collision
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address implementation, address admin, bytes memory initData) {
        _setImplementation(implementation);
        _setAdmin(admin);
        if (initData.length > 0) {
            (bool ok,) = implementation.delegatecall(initData);
            require(ok, "Initialization failed");
        }
    }

    // -------------------------------------------------------
    // Admin-only functions — not routed to implementation
    // -------------------------------------------------------

    function upgradeTo(address newImplementation) external {
        require(msg.sender == _getAdmin(), "Not admin");
        require(newImplementation.code.length > 0, "Not a contract");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external {
        require(msg.sender == _getAdmin(), "Not admin");
        require(newImplementation.code.length > 0, "Not a contract");
        _setImplementation(newImplementation);
        (bool ok,) = newImplementation.delegatecall(data);
        require(ok, "Migration call failed");
        emit Upgraded(newImplementation);
    }

    function changeAdmin(address newAdmin) external {
        require(msg.sender == _getAdmin(), "Not admin");
        require(newAdmin != address(0), "Zero address");
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    function admin() external view returns (address) {
        require(msg.sender == _getAdmin(), "Not admin");
        return _getAdmin();
    }

    function implementation() external view returns (address) {
        require(msg.sender == _getAdmin(), "Not admin");
        return _getImplementation();
    }

    // -------------------------------------------------------
    // Fallback — routes non-admin calls to implementation
    // -------------------------------------------------------

    fallback() external payable {
        // Admin cannot call implementation — they hit the functions above
        require(msg.sender != _getAdmin(), "Admin cannot call implementation");
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }

    function _delegate(address impl) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() internal view returns (address impl) {
        assembly { impl := sload(IMPLEMENTATION_SLOT) }
    }

    function _setImplementation(address impl) private {
        assembly { sstore(IMPLEMENTATION_SLOT, impl) }
    }

    function _getAdmin() internal view returns (address adm) {
        assembly { adm := sload(ADMIN_SLOT) }
    }

    function _setAdmin(address adm) private {
        assembly { sstore(ADMIN_SLOT, adm) }
    }
}

// ============================================================
// SECTION 3: UUPS PATTERN (ERC-1822)
// ============================================================

/*
 * KEY DIFFERENCE from Transparent:
 * The upgrade logic lives IN THE IMPLEMENTATION, not the proxy.
 * The proxy is a minimal forwarder — no admin logic.
 *
 * ADVANTAGES:
 * - Cheaper per call (no admin check in proxy)
 * - Smaller proxy bytecode
 * - Upgrade authorization is flexible (any logic in implementation)
 *
 * DANGER:
 * If you deploy an implementation that removes the `upgradeTo` function,
 * the proxy is permanently locked at that version.
 * Always test the upgrade path before deploying a new implementation.
 *
 * ERC-1967 slot for implementation (same as Transparent):
 * 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
 */

/// @title UUPSProxy — minimal proxy for UUPS pattern
contract UUPSProxy {

    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address implementation, bytes memory initData) {
        assembly { sstore(IMPLEMENTATION_SLOT, implementation) }
        if (initData.length > 0) {
            (bool ok,) = implementation.delegatecall(initData);
            require(ok, "Init failed");
        }
    }

    fallback() external payable {
        assembly {
            let impl := sload(IMPLEMENTATION_SLOT)
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

/// @title UUPSImplementationV1 — implementation with upgrade logic
/// @dev CRITICAL: _authorizeUpgrade MUST be overridden and access-controlled
contract UUPSImplementationV1 {

    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Storage (starts at slot 0 in the PROXY's storage)
    address private _owner;
    uint256 private _value;
    bool    private _initialized;

    error NotOwner();
    error AlreadyInitialized();
    error NotUUPS();

    event Upgraded(address indexed newImplementation);

    // -------------------------------------------------------
    // CRITICAL: Lock the implementation itself
    // Without this, an attacker can call initialize() on the
    // implementation directly and become owner, then selfdestruct it.
    // -------------------------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _initialized = true; // prevents anyone from initializing the bare impl
    }

    // -------------------------------------------------------
    // Use initializer instead of constructor
    // -------------------------------------------------------
    function initialize(address owner_) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        _owner = owner_;
    }

    function setValue(uint256 v) external {
        require(msg.sender == _owner, "Not owner");
        _value = v;
    }

    function getValue() external view returns (uint256) { return _value; }
    function owner()    external view returns (address)  { return _owner; }

    // -------------------------------------------------------
    // Upgrade functions — live in the implementation
    // -------------------------------------------------------

    /// @notice Override in subclass to define who can upgrade
    function _authorizeUpgrade(address newImplementation) internal virtual {
        require(msg.sender == _owner, "Not owner");
        // In production: add timelock, multisig, or governance check
        // Example: require(block.timestamp >= proposedAt + 2 days);
        newImplementation; // reference param to prevent unused-variable warning
    }

    function upgradeTo(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
        require(newImplementation.code.length > 0, "Not a contract");

        // Verify the new implementation is also UUPS-compatible
        // by checking it has the upgradeTo function selector
        // (prevents bricking the proxy with a non-UUPS implementation)
        try UUPSImplementationV1(newImplementation).proxiableUUID() returns (bytes32 uuid) {
            require(uuid == IMPLEMENTATION_SLOT, "Not UUPS compatible");
        } catch {
            revert NotUUPS();
        }

        assembly { sstore(IMPLEMENTATION_SLOT, newImplementation) }
        emit Upgraded(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external {
        _authorizeUpgrade(newImplementation);
        require(newImplementation.code.length > 0, "Not a contract");
        assembly { sstore(IMPLEMENTATION_SLOT, newImplementation) }
        (bool ok,) = newImplementation.delegatecall(data);
        require(ok, "Migration failed");
        emit Upgraded(newImplementation);
    }

    /// @notice Returns the ERC-1967 slot — proves this is UUPS compatible
    function proxiableUUID() external pure returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }
}

/// @title UUPSImplementationV2 — upgraded version preserving storage layout
contract UUPSImplementationV2 is UUPSImplementationV1 {

    // -------------------------------------------------------
    // RULE: ONLY APPEND NEW VARIABLES — never reorder or remove
    // These must come AFTER all V1 variables in declaration order
    // -------------------------------------------------------
    // V1 had: _owner (slot 0), _value (slot 1), _initialized (slot 2)
    // V2 adds: _newFeature (slot 3)
    uint256 private _newFeature; // safe: appended after V1 variables

    // -------------------------------------------------------
    // Use reinitializer for V2-specific setup
    // reinitializer(2) means it can only run once with version=2
    // -------------------------------------------------------
    uint8 private _initVersion; // tracks which version was initialized

    function initializeV2(uint256 featureValue) external {
        require(msg.sender == this.owner(), "Not owner");
        require(_initVersion < 2, "Already initialized V2");
        _initVersion  = 2;
        _newFeature   = featureValue;
    }

    function getNewFeature() external view returns (uint256) { return _newFeature; }
}

// ============================================================
// SECTION 4: BEACON PROXY PATTERN
// ============================================================

/*
 * USE CASE: Factory that deploys many identical proxies
 * (e.g., one vault per user, one pool per token pair)
 *
 * STRUCTURE:
 *   Beacon  ─── holds implementation address
 *   Proxy A ─┐
 *   Proxy B ─┼─ all read from Beacon
 *   Proxy C ─┘
 *
 * UPGRADE: Change implementation in Beacon → ALL proxies upgrade instantly
 * vs UUPS/Transparent: must upgrade each proxy individually
 *
 * COST: Each call reads the Beacon address (1 extra SLOAD + external call)
 *
 * EIP-1967 slot for beacon:
 * keccak256("eip1967.proxy.beacon") - 1
 * = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50
 */

interface IBeacon {
    function implementation() external view returns (address);
}

/// @title UpgradeableBeacon — controls implementation for all beacon proxies
contract UpgradeableBeacon is IBeacon {

    address private _implementation;
    address public  owner;

    event Upgraded(address indexed implementation);

    error NotOwner();
    error NotContract();

    constructor(address implementation_, address owner_) {
        require(implementation_.code.length > 0, "Not a contract");
        _implementation = implementation_;
        owner           = owner_;
    }

    function implementation() external view override returns (address) {
        return _implementation;
    }

    /// @notice Upgrade ALL beacon proxies in one transaction
    function upgradeTo(address newImplementation) external {
        if (msg.sender != owner)                  revert NotOwner();
        if (newImplementation.code.length == 0)   revert NotContract();
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        owner = newOwner;
    }
}

/// @title BeaconProxy — reads implementation from beacon on every call
contract BeaconProxy {

    bytes32 private constant BEACON_SLOT =
        0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    constructor(address beacon, bytes memory initData) {
        assembly { sstore(BEACON_SLOT, beacon) }
        address impl = IBeacon(beacon).implementation();
        if (initData.length > 0) {
            (bool ok,) = impl.delegatecall(initData);
            require(ok, "Init failed");
        }
    }

    fallback() external payable {
        address beacon; assembly { beacon := sload(BEACON_SLOT) }
        address impl = IBeacon(beacon).implementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

/// @title VaultFactory — beacon proxy factory pattern
contract VaultFactory {

    UpgradeableBeacon public immutable beacon;
    mapping(address => address) public userVault;
    address[] public allVaults;

    event VaultCreated(address indexed user, address vault);

    constructor(address vaultImplementation) {
        beacon = new UpgradeableBeacon(vaultImplementation, msg.sender);
    }

    function createVault() external returns (address vault) {
        require(userVault[msg.sender] == address(0), "Already has vault");

        bytes memory initData = abi.encodeWithSignature("initialize(address)", msg.sender);
        vault = address(new BeaconProxy(address(beacon), initData));

        userVault[msg.sender] = vault;
        allVaults.push(vault);

        emit VaultCreated(msg.sender, vault);
    }

    /// @notice Upgrade ALL vaults in one tx via beacon
    function upgradeAll(address newImplementation) external {
        beacon.upgradeTo(newImplementation);
    }
}

// ============================================================
// SECTION 5: DIAMOND PATTERN (EIP-2535)
// ============================================================

/*
 * PROBLEM SOLVED:
 * - 24KB contract size limit (EIP-170)
 * - Need to upgrade individual functions without touching others
 * - Organize large protocol into logical facets
 *
 * ARCHITECTURE:
 *   Diamond ─── DiamondCut (adds/removes/replaces facets)
 *            ├── FacetA (Token functions)
 *            ├── FacetB (Governance functions)
 *            ├── FacetC (DeFi functions)
 *            └── FacetD (Admin functions)
 *
 * Each facet is a separate contract. The Diamond routes calls
 * using a mapping of function selectors to facet addresses.
 *
 * STORAGE: All facets share the Diamond's storage.
 * Use Diamond Storage (namespaced) to prevent collision.
 *
 * EIP-2535 defines a standard interface including:
 * - IDiamondCut: add/replace/remove functions
 * - IDiamondLoupe: inspect facets and selectors
 */

struct FacetCut {
    address facetAddress;
    uint8   action;         // 0=Add, 1=Replace, 2=Remove
    bytes4[] functionSelectors;
}

interface IDiamondCut {
    function diamondCut(
        FacetCut[] calldata cuts,
        address    initAddress,
        bytes      calldata initCalldata
    ) external;

    event DiamondCut(FacetCut[] cuts, address init, bytes initCalldata);
}

interface IDiamondLoupe {
    struct Facet { address facetAddress; bytes4[] functionSelectors; }
    function facets()                       external view returns (Facet[] memory);
    function facetFunctionSelectors(address) external view returns (bytes4[] memory);
    function facetAddresses()               external view returns (address[] memory);
    function facetAddress(bytes4)           external view returns (address);
}

/// @title DiamondStorage — namespaced storage layout for Diamond
library DiamondStorage {

    // Unique storage slot — prevents collision with facet storage
    bytes32 constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    struct Layout {
        // maps selector → (facetAddress packed with position)
        mapping(bytes4 => bytes32) facets;
        bytes4[]   selectors;
        address    owner;
    }

    function layout() internal pure returns (Layout storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly { ds.slot := position }
    }

    function facetAddress(bytes4 selector) internal view returns (address facet) {
        bytes32 data = layout().facets[selector];
        assembly { facet := and(data, 0xffffffffffffffffffffffffffffffffffffffff) }
    }
}

/// @title Diamond — core proxy contract
contract Diamond {

    error FunctionNotFound(bytes4 selector);

    constructor(address owner_, address diamondCutFacet) {
        DiamondStorage.layout().owner = owner_;

        // Bootstrap: add the diamondCut function from DiamondCutFacet
        bytes4 selector = IDiamondCut.diamondCut.selector;
        bytes32 packed   = bytes32(uint256(uint160(diamondCutFacet)));
        DiamondStorage.layout().facets[selector] = packed;
        DiamondStorage.layout().selectors.push(selector);
    }

    fallback() external payable {
        address facet = DiamondStorage.facetAddress(msg.sig);
        if (facet == address(0)) revert FunctionNotFound(msg.sig);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

/// @title DiamondCutFacet — manages facets (add/replace/remove)
contract DiamondCutFacet is IDiamondCut {

    uint8 constant ADD     = 0;
    uint8 constant REPLACE = 1;
    uint8 constant REMOVE  = 2;

    error NotOwner();
    error InvalidAction();
    error SelectorExists(bytes4 selector);
    error SelectorNotFound(bytes4 selector);
    error InitCallFailed();

    function diamondCut(
        FacetCut[] calldata cuts,
        address    initAddress,
        bytes      calldata initCalldata
    ) external override {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        require(msg.sender == ds.owner, "Not owner");

        for (uint256 i = 0; i < cuts.length; i++) {
            FacetCut calldata cut = cuts[i];
            for (uint256 j = 0; j < cut.functionSelectors.length; j++) {
                bytes4 selector = cut.functionSelectors[j];
                if (cut.action == ADD) {
                    if (DiamondStorage.facetAddress(selector) != address(0))
                        revert SelectorExists(selector);
                    ds.facets[selector] = bytes32(uint256(uint160(cut.facetAddress)));
                    ds.selectors.push(selector);
                } else if (cut.action == REPLACE) {
                    if (DiamondStorage.facetAddress(selector) == address(0))
                        revert SelectorNotFound(selector);
                    ds.facets[selector] = bytes32(uint256(uint160(cut.facetAddress)));
                } else if (cut.action == REMOVE) {
                    if (DiamondStorage.facetAddress(selector) == address(0))
                        revert SelectorNotFound(selector);
                    delete ds.facets[selector];
                } else {
                    revert InvalidAction();
                }
            }
        }

        emit DiamondCut(cuts, initAddress, initCalldata);

        if (initAddress != address(0)) {
            (bool ok,) = initAddress.delegatecall(initCalldata);
            if (!ok) revert InitCallFailed();
        }
    }
}

// ============================================================
// SECTION 6: ERC-7201 — NAMESPACED STORAGE
// ============================================================

/*
 * PROBLEM: In upgradeable contracts, adding a state variable in a
 * base contract shifts all derived variables → storage collision.
 *
 * ERC-7201 SOLUTION: Store each "namespace" at a fixed, randomly-chosen slot.
 * Adding variables to the namespace never affects other namespaces.
 *
 * FORMULA:
 *   slot = keccak256(keccak256(namespace) - 1) & ~0xff
 *   (subtract 1 then zero the last byte to avoid preimage attacks)
 *
 * ANNOTATION: /// @custom:storage-location erc7201:myprotocol.main
 *
 * TOOLS:
 *   forge inspect MyContract storage  → shows slot layout
 *   slither --detect uninitialized-local → catches uninitialized storage
 *   OpenZeppelin Upgrades Plugin       → validates layout between versions
 */

/// @title ERC7201Storage — namespaced storage pattern
contract ERC7201Storage {

    // -------------------------------------------------------
    // Main namespace: "myprotocol.main"
    // slot = keccak256(keccak256("myprotocol.main") - 1) & ~0xff
    // -------------------------------------------------------

    /// @custom:storage-location erc7201:myprotocol.main
    struct MainStorage {
        address owner;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        bool paused;
        // Safe to add variables here — they go to higher sub-slots
        // uint256 newField;  ← adding this NEVER collides with other namespaces
    }

    // ERC-7201 slot. Inline assembly only accepts literal constants, so the
    // derivation below is precomputed:
    //   keccak256(abi.encode(uint256(keccak256("myprotocol.main")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAIN_STORAGE_LOCATION =
        0x8df417c1575b8946a9fdccf2ade6378aa56ff1da7833c87b1533757e15459300;

    function _getMainStorage() private pure returns (MainStorage storage $) {
        assembly { $.slot := MAIN_STORAGE_LOCATION }
    }

    // -------------------------------------------------------
    // Governance namespace: "myprotocol.governance"
    // Completely independent — adding vars here never collides with main
    // -------------------------------------------------------

    /// @custom:storage-location erc7201:myprotocol.governance
    struct GovernanceStorage {
        address timelock;
        uint256 proposalCount;
        mapping(uint256 => bytes32) proposals;
        // Safe to add: uint256 quorum;
    }

    // ERC-7201 slot (precomputed; see MAIN_STORAGE_LOCATION for the formula):
    //   keccak256(abi.encode(uint256(keccak256("myprotocol.governance")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GOVERNANCE_STORAGE_LOCATION =
        0xc284b721fa3dd50bf9e2f365a741a055829d72990233adf084124b74de150900;

    function _getGovernanceStorage() private pure returns (GovernanceStorage storage $) {
        assembly { $.slot := GOVERNANCE_STORAGE_LOCATION }
    }

    // -------------------------------------------------------
    // Public API — uses namespaced storage internally
    // -------------------------------------------------------

    function initialize(address owner_) external {
        MainStorage storage $ = _getMainStorage();
        require($.owner == address(0), "Already initialized");
        $.owner = owner_;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _getMainStorage().balances[account];
    }

    function owner() external view returns (address) {
        return _getMainStorage().owner;
    }

    function pause() external {
        MainStorage storage $ = _getMainStorage();
        require(msg.sender == $.owner, "Not owner");
        $.paused = true;
    }
}

// ============================================================
// SECTION 7: STORAGE LAYOUT SAFETY & GAPS
// ============================================================

/*
 * STORAGE LAYOUT RULES FOR UPGRADEABLE CONTRACTS:
 *
 * RULE 1 — Never delete a variable
 *   BAD:  V1 has uint256 a; uint256 b;
 *         V2 has uint256 a;             ← b removed, now slot 1 is misaligned
 *   GOOD: V2 has uint256 a; uint256 deprecated_b; ← keep but mark deprecated
 *
 * RULE 2 — Never reorder variables
 *   BAD:  V1: address owner; uint256 value;
 *         V2: uint256 value; address owner;  ← swapped → reads wrong slots
 *
 * RULE 3 — Never change variable types (unless same size)
 *   BAD:  V1: uint256 x;  V2: address x;  ← different slot packing
 *   OK:   V1: uint128 a; uint128 b; (packed)  V2: same
 *
 * RULE 4 — Use storage gaps in base contracts
 *   Add uint256[N] __gap at the END of each base contract.
 *   When you add a variable, reduce __gap by the same slots.
 *   This preserves derived contract slot alignment.
 *
 * RULE 5 — Use ERC-7201 namespaced storage (Section 6) instead of gaps
 *   More robust, no counting required, Solidity-native annotation.
 */

/// @title StorageGapPattern — safe storage for upgradeable base contracts
abstract contract UpgradeableBase {

    // -------------------------------------------------------
    // V1 STATE (3 slots used)
    // -------------------------------------------------------
    address private _owner;      // slot 0
    uint256 private _value;      // slot 1
    bool    private _paused;     // slot 2 (bool = 1 byte, but occupies full slot alone)

    // -------------------------------------------------------
    // GAP: reserves slots 3-52 for future variables in this base
    // When you add `uint256 newVar` here, change __gap to [49]
    // -------------------------------------------------------
    uint256[50] private __gap;   // slots 3-52 reserved

    // V2 addition (safe — takes slot from __gap):
    // uint256 private _extraVar;    // use slot 3 (shrink __gap to [49])

    function _getOwner() internal view returns (address) { return _owner; }
    function _setOwner(address o) internal { _owner = o; }
    function _getPaused() internal view returns (bool) { return _paused; }
    function _setPaused(bool p) internal { _paused = p; }
}

abstract contract UpgradeableDerived is UpgradeableBase {

    // Derived contract starts at slot 53 (after base + gap)
    // Even if base adds variables (consuming gap), derived is safe
    uint256 private _derivedVar; // slot 53
    uint256[50] private __gap;   // reserve for derived base too
}

// ============================================================
// SECTION 8: INITIALIZER SECURITY
// ============================================================

/*
 * ATTACK 1 — UNPROTECTED INITIALIZER:
 * If initialize() has no guard, an attacker calls it before you do.
 * Result: attacker becomes owner of your proxy.
 *
 * ATTACK 2 — IMPLEMENTATION SELF-DESTRUCT:
 * If implementation has no constructor guard, attacker initializes it,
 * becomes owner, calls a self-destruct function.
 * Result: proxy's delegatecall returns empty bytecode → bricked.
 * Fixed by EIP-6780 (SELFDESTRUCT restriction), but still relevant.
 *
 * ATTACK 3 — DOUBLE INITIALIZATION:
 * If you forget to disable reinitialization between versions,
 * someone calls initializeV2() and overwrites critical state.
 *
 * ATTACK 4 — CROSS-CHAIN REPLAY:
 * Initialization transaction on mainnet replayed on a fork.
 * Include chainId in the initializer check.
 */

/// @title InitializerSecurity — all initializer patterns and guards
contract InitializerSecurity {

    uint64 private _initVersion;

    error AlreadyInitialized(uint64 currentVersion, uint64 requestedVersion);
    error NotInitialized();

    event Initialized(uint64 version);

    // -------------------------------------------------------
    // PATTERN 1: Simple one-time initializer
    // -------------------------------------------------------
    modifier initializer() {
        if (_initVersion >= 1) revert AlreadyInitialized(_initVersion, 1);
        _initVersion = 1;
        _;
        emit Initialized(1);
    }

    // -------------------------------------------------------
    // PATTERN 2: Versioned reinitializer (for V2, V3...)
    // -------------------------------------------------------
    modifier reinitializer(uint64 version) {
        if (_initVersion >= version) revert AlreadyInitialized(_initVersion, version);
        _initVersion = version;
        _;
        emit Initialized(version);
    }

    // -------------------------------------------------------
    // PATTERN 3: Disable all future initialization
    // Call in constructor of implementation to lock it
    // -------------------------------------------------------
    function _disableInitializers() internal {
        if (_initVersion != type(uint64).max) {
            _initVersion = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    // -------------------------------------------------------
    // CORRECT implementation contract constructor
    // -------------------------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // CRITICAL: prevents attack on bare implementation
    }

    // -------------------------------------------------------
    // CORRECT initializers
    // -------------------------------------------------------
    address private _owner;
    address private _admin;
    uint256 private _cap;

    function initialize(address owner_) external /* initializer */ {
        // In real code: add `initializer` modifier
        _owner = owner_;
    }

    function initializeV2(address admin_) external /* reinitializer(2) */ {
        // In real code: add `reinitializer(2)` modifier
        _admin = admin_;
    }

    function initializeV3(uint256 cap_) external /* reinitializer(3) */ {
        // In real code: add `reinitializer(3)` modifier
        _cap = cap_;
    }
}

// ============================================================
// SECTION 9: FUNCTION SELECTOR CLASHING
// ============================================================

/*
 * PROBLEM: Two different function signatures can have the same 4-byte selector.
 * In a proxy (especially Diamond), this creates unpredictable routing.
 *
 * EXAMPLES OF REAL COLLISIONS:
 *   transfer(bytes4,bytes)   == clash with (theoretical) other function
 *   burn(uint256)            == could clash in multi-facet Diamond
 *
 * ATTACK SCENARIO (Transparent Proxy):
 *   Implementation has a function whose selector matches `upgradeTo(address)`.
 *   Regular users calling the innocent function accidentally trigger upgrades.
 *   → Transparent Proxy prevents this by admin-gating all admin selectors.
 *
 * DIAMOND SPECIFIC:
 *   When adding a facet, always check for selector collisions.
 *   DiamondCutFacet should revert if a selector is already registered.
 *
 * DETECTION:
 *   forge inspect MyContract methods  → lists all selectors
 *   cast sig "functionName(type)"     → compute selector
 *   4byte.directory                   → reverse lookup known selectors
 */

/// @title SelectorClashDetector — utility to find selector collisions
library SelectorClashDetector {

    /// @notice Returns true if two function signatures share a 4-byte selector
    function clash(string memory sig1, string memory sig2) internal pure returns (bool) {
        return bytes4(keccak256(bytes(sig1))) == bytes4(keccak256(bytes(sig2)));
    }

    /// @notice Compute selector for a given signature
    function selector(string memory sig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(sig)));
    }
}

/// @title ClashAwareDiamond — Diamond that checks for selector collisions on add
contract ClashAwareDiamondCut {

    mapping(bytes4 => address) private _selectorToFacet;

    error SelectorCollision(bytes4 selector, address existingFacet, address newFacet);

    function addFacet(address facet, bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 sel = selectors[i];
            address existing = _selectorToFacet[sel];
            if (existing != address(0) && existing != facet)
                revert SelectorCollision(sel, existing, facet);
            _selectorToFacet[sel] = facet;
        }
    }
}

// ============================================================
// SECTION 10: STORAGE COLLISION ATTACKS (DEEP DIVE)
// ============================================================

/*
 * TYPE 1 — CLASSIC STORAGE COLLISION (Parity Wallet 2017):
 * Proxy and Implementation both use slot 0.
 * Proxy stores admin at slot 0.
 * Implementation stores owner at slot 0.
 * Writing to owner overwrites admin → proxy hijacked.
 *
 * TYPE 2 — EIP-1967 BYPASS:
 * If the implementation has a function that writes to the exact
 * EIP-1967 slot (0x360894...), it can overwrite the implementation pointer.
 * Protection: use keccak256-derived slots, not sequential slots.
 *
 * TYPE 3 — DIAMOND STORAGE COLLISION:
 * Two facets use the same namespace string → same slot.
 * Protection: use globally unique namespace strings per team/protocol.
 *
 * TYPE 4 — INITIALIZER STORAGE POLLUTION:
 * Initializer writes to storage before the real initialize() runs
 * (via constructor of an abstract base that is not disabled).
 * Protection: _disableInitializers() in all implementation constructors.
 */

/// @notice Demonstrates a storage collision vulnerability
/// @dev FOR EDUCATIONAL PURPOSES ONLY — never deploy CollisionVulnerable
contract CollisionVulnerable {

    // BAD: slot 0 = implementation (in a proxy context)
    // BAD: slot 0 = owner (in the implementation)
    // These COLLIDE if used via delegatecall
    address public owner; // slot 0 — same as implementation address in some proxies!

    function initialize() external {
        owner = msg.sender; // DANGER: overwrites implementation pointer if this IS the proxy
    }
}

/// @notice Safe pattern — uses EIP-1967 slot
contract CollisionSafe {

    // Implementation address stored at keccak-derived slot — no collision
    bytes32 private constant IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // Regular state starts at slot 0 — doesn't conflict with IMPL_SLOT
    address public owner; // slot 0 — safe, far from IMPL_SLOT

    function getImplementation() public view returns (address impl) {
        assembly { impl := sload(IMPL_SLOT) }
    }
}

// ============================================================
// SECTION 11: UPGRADE AUTHORIZATION PATTERNS
// ============================================================

/*
 * AUTHORIZATION STRATEGIES (from weakest to strongest):
 *
 * 1. EOA owner          — single key, high risk (key loss = frozen)
 * 2. Multisig (Safe)    — N-of-M, industry standard for production
 * 3. Timelock           — delay gives community time to react
 * 4. Governance vote    — decentralized, slow (days to weeks)
 * 5. Optimistic upgrade — propose → wait → execute if no veto
 *
 * RECOMMENDED FOR HIGH-VALUE PROTOCOLS:
 * Governance → Timelock (48h min) → Multisig executes
 */

/// @title TimelockUpgradeController — upgrade authorization with delay
contract TimelockUpgradeController {

    address public immutable multisig;
    uint256 public immutable delay;  // minimum 48 hours for production

    struct UpgradeProposal {
        address newImplementation;
        uint256 proposedAt;
        bool    executed;
        bool    cancelled;
    }

    mapping(bytes32 => UpgradeProposal) public proposals;

    event UpgradeProposed(bytes32 indexed id, address newImplementation, uint256 executeAfter);
    event UpgradeExecuted(bytes32 indexed id, address newImplementation);
    event UpgradeCancelled(bytes32 indexed id);

    error NotMultisig();
    error TooEarly(uint256 executeAfter, uint256 current);
    error AlreadyExecuted();
    error Cancelled();
    error NotFound();

    constructor(address _multisig, uint256 _delay) {
        require(_delay >= 2 days, "Delay too short");
        multisig = _multisig;
        delay    = _delay;
    }

    modifier onlyMultisig() {
        if (msg.sender != multisig) revert NotMultisig();
        _;
    }

    function propose(address newImplementation) external onlyMultisig returns (bytes32 id) {
        require(newImplementation.code.length > 0, "Not a contract");
        id = keccak256(abi.encode(newImplementation, block.timestamp));

        proposals[id] = UpgradeProposal({
            newImplementation: newImplementation,
            proposedAt:        block.timestamp,
            executed:          false,
            cancelled:         false
        });

        emit UpgradeProposed(id, newImplementation, block.timestamp + delay);
    }

    function execute(bytes32 id, address proxy) external onlyMultisig {
        UpgradeProposal storage p = proposals[id];
        if (p.proposedAt == 0)                          revert NotFound();
        if (p.executed)                                 revert AlreadyExecuted();
        if (p.cancelled)                                revert Cancelled();
        if (block.timestamp < p.proposedAt + delay)
            revert TooEarly(p.proposedAt + delay, block.timestamp);

        p.executed = true;

        // Execute upgrade on proxy
        (bool ok,) = proxy.call(
            abi.encodeWithSignature("upgradeTo(address)", p.newImplementation)
        );
        require(ok, "Upgrade failed");

        emit UpgradeExecuted(id, p.newImplementation);
    }

    function cancel(bytes32 id) external onlyMultisig {
        UpgradeProposal storage p = proposals[id];
        require(p.proposedAt != 0, "Not found");
        require(!p.executed,       "Already executed");
        p.cancelled = true;
        emit UpgradeCancelled(id);
    }
}

// ============================================================
// SECTION 12: STORAGE LAYOUT VERIFICATION TOOLS
// ============================================================

/*
 * FOUNDRY — inspect storage layout:
 *   forge inspect MyContract storage
 *   forge inspect MyContract storage --json | jq '.storage[] | {name, slot, type}'
 *
 * COMPARE V1 vs V2 layouts (must be compatible):
 *   forge inspect TokenV1 storage --json > v1.json
 *   forge inspect TokenV2 storage --json > v2.json
 *   diff v1.json v2.json
 *   → New variables must only appear at higher slot numbers
 *
 * OPENZEPPELIN UPGRADES PLUGIN (Hardhat/Foundry):
 *   npm install @openzeppelin/hardhat-upgrades
 *   In tests:
 *     const v1 = await upgrades.deployProxy(TokenV1, [owner]);
 *     const v2 = await upgrades.upgradeProxy(v1, TokenV2);
 *     → Automatically validates storage compatibility
 *
 * SLITHER:
 *   slither MyContract.sol --detect uninitialized-local
 *   slither MyContract.sol --detect suicidal
 *   slither-check-upgradeability MyContract.sol MyContract \
 *     --new-contract MyContractV2.sol MyContractV2
 *
 * SOLIDITY STORAGE ANNOTATIONS (compiler-checked in future):
 *   /// @custom:storage-location erc7201:myprotocol.main
 *   → Documents intended storage slot for tooling
 *
 * MANUAL AUDIT CHECKLIST FOR STORAGE:
 * 1. List all state variables in V1 with their slots
 * 2. List all state variables in V2 with their slots
 * 3. Verify: V2[slot N] == V1[slot N] for all N where V1 had data
 * 4. Verify: V2 only adds at slot > max(V1 slots)
 * 5. Check: no packed variable changes size (uint128→uint256 shifts packing)
 * 6. Check: ERC-7201 namespaces remain the same string
 */

// ============================================================
// SECTION 13: MIGRATION PATTERNS
// ============================================================

/*
 * MIGRATION = running code during an upgrade to transform state.
 *
 * PATTERN 1 — INLINE MIGRATION (upgradeToAndCall):
 * Pass migration calldata to upgradeToAndCall().
 * Runs atomically with the upgrade.
 * Best for: small, bounded migrations.
 *
 * PATTERN 2 — LAZY MIGRATION:
 * Old state coexists with new state.
 * Migrate user state on first interaction after upgrade.
 * Best for: large user sets, unbounded state.
 *
 * PATTERN 3 — BATCH MIGRATION:
 * Admin calls migrate(users[]) in batches after upgrade.
 * Best for: medium-sized state with known bounds.
 *
 * PATTERN 4 — DUAL-VERSION READ:
 * New contract reads from old storage format if new format is empty.
 * Best for: backwards-compatible reads without writing.
 */

/// @title MigrationPatterns — reference implementations
contract MigrationV2 {

    // V1 storage (preserved)
    address private _owner;
    mapping(address => uint256) private _balances_v1; // old format: raw uint256

    // V2 storage (new format: scaled by 1e6 for higher precision)
    bool    private _migrated;
    mapping(address => uint256) private _balances_v2; // new format
    mapping(address => bool)    private _userMigrated;

    // -------------------------------------------------------
    // PATTERN 2: Lazy migration — convert on first access
    // -------------------------------------------------------
    function balanceOf(address user) external returns (uint256) {
        if (!_userMigrated[user] && _balances_v1[user] > 0) {
            // Migrate on read: scale up to new precision
            _balances_v2[user]    = _balances_v1[user] * 1e6;
            _balances_v1[user]    = 0;
            _userMigrated[user]   = true;
        }
        return _balances_v2[user];
    }

    // -------------------------------------------------------
    // PATTERN 3: Batch migration — admin runs after upgrade
    // -------------------------------------------------------
    function migrateUsers(address[] calldata users) external {
        require(msg.sender == _owner, "Not owner");
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!_userMigrated[user] && _balances_v1[user] > 0) {
                _balances_v2[user]  = _balances_v1[user] * 1e6;
                _balances_v1[user]  = 0;
                _userMigrated[user] = true;
            }
        }
    }

    // -------------------------------------------------------
    // PATTERN 1: Called via upgradeToAndCall in the upgrade tx
    // -------------------------------------------------------
    function migrateGlobalState(uint256 newParam) external {
        require(msg.sender == address(this), "Only via delegatecall");
        require(!_migrated, "Already migrated");
        _migrated = true;
        // Set new global state
        newParam; // placeholder: reference param to prevent unused-variable warning
    }
}

// ============================================================
// SECTION 14: UPGRADE SECURITY CHECKLIST
// ============================================================

/*
 * PRE-UPGRADE DEVELOPMENT
 * [ ] ERC-7201 namespaced storage used (or storage gaps if not)
 * [ ] Storage layout exported and compared with forge inspect
 * [ ] OpenZeppelin Upgrades Plugin validates layout compatibility
 * [ ] No variables reordered, removed, or resized
 * [ ] New variables only appended at the end (or within namespace)
 * [ ] All base contracts have __gap or use ERC-7201
 * [ ] _disableInitializers() in every implementation constructor
 * [ ] initialize() guarded against double-call
 * [ ] initializeVN() uses reinitializer(N) — versioned
 * [ ] Upgrade authorization requires multisig or governance
 * [ ] Timelock of at least 48h for non-emergency upgrades
 * [ ] Emergency upgrade path documented (if needed)
 *
 * PROXY TYPE SECURITY
 * [ ] Transparent: admin cannot call implementation functions
 * [ ] UUPS: _authorizeUpgrade() has correct access control
 * [ ] UUPS: new implementation has proxiableUUID() check
 * [ ] Beacon: beacon owner is multisig, not EOA
 * [ ] Diamond: selector collision check in diamondCut
 * [ ] Diamond: unique namespace strings per facet storage
 *
 * PRE-MAINNET TESTING
 * [ ] Full upgrade flow tested on testnet fork
 * [ ] State after upgrade matches expected values
 * [ ] All existing functions still work after upgrade
 * [ ] New functions work as expected
 * [ ] Migration ran correctly (batch or lazy)
 * [ ] Gas costs of upgraded functions within budget
 * [ ] Slither upgradeability check passes
 *
 * DEPLOYMENT
 * [ ] Upgrade proposed via Timelock (with delay)
 * [ ] Community notified of upcoming upgrade
 * [ ] Delay period passed (no emergency veto)
 * [ ] Multisig executes upgrade
 * [ ] Immediately verify implementation address on Etherscan
 * [ ] Re-verify all contract functions work post-upgrade
 * [ ] Monitor for anomalous activity for 24h after upgrade
 *
 * KNOWN RISKS TO DOCUMENT
 * [ ] Who controls the upgrade key? (multisig composition documented)
 * [ ] Is there a timelock? What is the delay?
 * [ ] Can upgrades be stopped by governance/veto?
 * [ ] What happens if the upgrade key is compromised?
 * [ ] Is there a bug bounty active during the upgrade window?
 */
