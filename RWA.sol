// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// =============================================================================
// REAL WORLD ASSETS (RWA) ON-CHAIN
// =============================================================================
// Real World Assets (RWA) are traditional financial instruments tokenized
// on the blockchain: treasury bills, bonds, real estate, private credit,
// commodities, receivables, and equity.
//
// Key market context (2025-2026):
//   - BlackRock BUIDL fund ($500M+) on Ethereum
//   - Franklin Templeton BENJI on Polygon/Stellar
//   - Ondo Finance (OUSG, USDY) — tokenized treasuries
//   - Maple Finance — private credit
//   - Centrifuge — invoice and asset financing
//   - Total RWA market: $10B+ on-chain (ex-stablecoins)
//
// Core technical requirements:
//   1. IDENTITY REGISTRY — KYC/AML: only verified investors can hold tokens
//   2. COMPLIANCE MODULES — transfer restrictions (geography, investor type)
//   3. TOKEN STANDARDS — ERC-3643 (T-REX, Section 3), ERC-1400 (Section 8), wrapped ERC-20
//   4. FORCED TRANSFERS — regulatory recovery (court orders, key loss)
//   5. DIVIDEND DISTRIBUTION — on-chain income to token holders
//   6. DELIVERY vs PAYMENT (DvP) — atomic settlement with stablecoins
//   7. FRACTIONAL OWNERSHIP — divide illiquid assets into small units
// =============================================================================

// =============================================================================
// SECTION 1 — IDENTITY REGISTRY (KYC/AML)
// =============================================================================
// Before any token transfer, both sender and receiver must be in the registry.
// The registry stores investor claims (e.g., "accredited investor in US").

interface IClaimVerifier {
    // Returns true if the identity has a valid claim of the given topic
    function hasValidClaim(address identity, uint256 claimTopic) external view returns (bool);
}

contract IdentityRegistry {
    // Claim topics (ERC-735 compatible)
    uint256 public constant KYC_APPROVED    = 1;
    uint256 public constant ACCREDITED_INV  = 2;
    uint256 public constant US_RESIDENT     = 3;
    uint256 public constant EU_RESIDENT     = 4;
    uint256 public constant PROFESSIONAL_INV = 5;

    struct Identity {
        address wallet;
        bool    registered;
        uint256 country;      // ISO 3166-1 numeric code
        mapping(uint256 => ClaimRecord) claims;
    }

    struct ClaimRecord {
        bool    valid;
        uint256 expiresAt;    // 0 = no expiry
        address issuer;       // trusted claim issuer
    }

    mapping(address => Identity) private _identities;
    mapping(address => bool)     public trustedIssuers;
    address public owner;
    address public agent;    // KYC agent can register identities

    event IdentityRegistered(address indexed wallet, uint256 country);
    event ClaimAdded(address indexed wallet, uint256 topic, address issuer);
    event ClaimRevoked(address indexed wallet, uint256 topic);
    event IssuerTrusted(address indexed issuer);
    event IssuerRevoked(address indexed issuer);

    error NotOwner();
    error NotAgent();
    error NotRegistered();
    error ClaimExpired();
    error UntrustedIssuer();

    constructor() {
        owner = msg.sender;
        agent = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAgent() {
        if (msg.sender != agent && msg.sender != owner) revert NotAgent();
        _;
    }

    function setAgent(address _agent) external onlyOwner {
        agent = _agent;
    }

    function trustIssuer(address issuer) external onlyOwner {
        trustedIssuers[issuer] = true;
        emit IssuerTrusted(issuer);
    }

    function revokeTrust(address issuer) external onlyOwner {
        trustedIssuers[issuer] = false;
        emit IssuerRevoked(issuer);
    }

    // Register a new investor identity
    function registerIdentity(address wallet, uint256 country) external onlyAgent {
        _identities[wallet].wallet = wallet;
        _identities[wallet].registered = true;
        _identities[wallet].country = country;
        emit IdentityRegistered(wallet, country);
    }

    // Add a claim to an identity (KYC, accredited status, etc.)
    function addClaim(
        address wallet,
        uint256 topic,
        uint256 expiresAt,
        address issuer
    ) external {
        if (!trustedIssuers[msg.sender] && msg.sender != agent) revert UntrustedIssuer();
        if (!_identities[wallet].registered) revert NotRegistered();

        _identities[wallet].claims[topic] = ClaimRecord({
            valid:     true,
            expiresAt: expiresAt,
            issuer:    issuer
        });
        emit ClaimAdded(wallet, topic, issuer);
    }

    function revokeClaim(address wallet, uint256 topic) external onlyAgent {
        _identities[wallet].claims[topic].valid = false;
        emit ClaimRevoked(wallet, topic);
    }

    // Check if a wallet is registered and has a valid, unexpired claim
    function hasValidClaim(address wallet, uint256 topic) external view returns (bool) {
        if (!_identities[wallet].registered) return false;
        ClaimRecord storage claim = _identities[wallet].claims[topic];
        if (!claim.valid) return false;
        if (claim.expiresAt != 0 && block.timestamp > claim.expiresAt) return false;
        return true;
    }

    function isRegistered(address wallet) external view returns (bool) {
        return _identities[wallet].registered;
    }

    function getCountry(address wallet) external view returns (uint256) {
        return _identities[wallet].country;
    }
}

// =============================================================================
// SECTION 2 — COMPLIANCE MODULES
// =============================================================================
// Modular transfer restriction rules. Each module implements IComplianceModule.
// Multiple modules can be stacked (e.g., country check AND investor check).

interface IComplianceModule {
    // Returns true if the transfer from → to of amount is allowed
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);
    function name() external view returns (string memory);
}

// Module 1: Country restriction (block certain countries from holding)
contract CountryRestrictionModule is IComplianceModule {
    IdentityRegistry public immutable registry;
    mapping(uint256 => bool) public blockedCountries;
    address public owner;

    constructor(address _registry) {
        registry = IdentityRegistry(_registry);
        owner = msg.sender;
    }

    function blockCountry(uint256 countryCode) external {
        require(msg.sender == owner, "Not owner");
        blockedCountries[countryCode] = true;
    }

    function unblockCountry(uint256 countryCode) external {
        require(msg.sender == owner, "Not owner");
        blockedCountries[countryCode] = false;
    }

    function canTransfer(address from, address to, uint256) external view override returns (bool) {
        uint256 fromCountry = registry.getCountry(from);
        uint256 toCountry   = registry.getCountry(to);
        return !blockedCountries[fromCountry] && !blockedCountries[toCountry];
    }

    function name() external pure override returns (string memory) {
        return "CountryRestriction";
    }
}

// Module 2: Accredited investor requirement
contract AccreditedInvestorModule is IComplianceModule {
    IdentityRegistry public immutable registry;

    constructor(address _registry) {
        registry = IdentityRegistry(_registry);
    }

    function canTransfer(address, address to, uint256) external view override returns (bool) {
        // Recipient must be KYC approved AND accredited investor
        return registry.hasValidClaim(to, 1) && // KYC_APPROVED
               registry.hasValidClaim(to, 2);   // ACCREDITED_INV
    }

    function name() external pure override returns (string memory) {
        return "AccreditedInvestor";
    }
}

// Module 3: Maximum investor cap (US Reg D max 2000 non-accredited holders)
contract MaxInvestorCapModule is IComplianceModule {
    uint256 public maxInvestors;
    uint256 public currentInvestors;
    mapping(address => bool) public isInvestor;
    address public immutable token; // only the token can call update

    constructor(uint256 _maxInvestors, address _token) {
        maxInvestors = _maxInvestors;
        token = _token;
    }

    function canTransfer(address from, address to, uint256) external view override returns (bool) {
        // If 'to' is a new investor and we're at cap, deny
        if (!isInvestor[to] && currentInvestors >= maxInvestors) return false;
        return true;
    }

    // Called by the token after a successful transfer to track investors
    function afterTransfer(address from, address to, uint256 fromBalance) external {
        require(msg.sender == token, "Not token");
        if (!isInvestor[to]) {
            isInvestor[to] = true;
            currentInvestors++;
        }
        if (fromBalance == 0 && isInvestor[from]) {
            isInvestor[from] = false;
            currentInvestors--;
        }
    }

    function name() external pure override returns (string memory) {
        return "MaxInvestorCap";
    }
}

// =============================================================================
// SECTION 3 — ERC-3643 (T-REX) TOKEN
// =============================================================================
// ERC-3643 is the industry standard for compliant security tokens.
// It extends ERC-20 with:
//   - Identity registry checks on every transfer
//   - Compliance module hooks
//   - Forced transfers (regulatory recovery)
//   - Freeze functionality (freeze specific accounts)
//   - Pause (pause all transfers)
//   - Agent role for operational tasks

contract ERC3643Token {
    // ERC-20 state
    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Compliance state
    IdentityRegistry  public immutable identityRegistry;
    IComplianceModule[] public complianceModules;
    mapping(address => bool) public frozen;    // frozen accounts cannot transfer
    bool public paused;                        // pause all transfers

    // Access control
    address public owner;
    address public agent;  // can freeze, force-transfer, mint/burn

    // Events (ERC-20 + ERC-3643 extensions)
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AddressFrozen(address indexed addr, bool isFrozen);
    event Paused();
    event Unpaused();
    event ForcedTransfer(address indexed from, address indexed to, uint256 value);
    event ComplianceModuleAdded(address indexed module);
    event ComplianceModuleRemoved(address indexed module);

    error NotOwner();
    error NotAgent();
    error TransferPaused();
    error AccountFrozen();
    error IdentityNotVerified();
    error ComplianceCheckFailed(string module);
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(
        string memory _name,
        string memory _symbol,
        address _identityRegistry
    ) {
        name = _name;
        symbol = _symbol;
        identityRegistry = IdentityRegistry(_identityRegistry);
        owner = msg.sender;
        agent = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    modifier onlyAgent() {
        if (msg.sender != agent && msg.sender != owner) revert NotAgent();
        _;
    }
    modifier whenNotPaused() {
        if (paused) revert TransferPaused();
        _;
    }

    // ==========================================================================
    // Compliance management
    // ==========================================================================
    function addComplianceModule(address module) external onlyOwner {
        complianceModules.push(IComplianceModule(module));
        emit ComplianceModuleAdded(module);
    }

    function removeComplianceModule(uint256 index) external onlyOwner {
        emit ComplianceModuleRemoved(address(complianceModules[index]));
        complianceModules[index] = complianceModules[complianceModules.length - 1];
        complianceModules.pop();
    }

    // ==========================================================================
    // ERC-20 transfer with compliance checks
    // ==========================================================================
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _complianceCheck(msg.sender, to, amount);
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = currentAllowance - amount;
        _complianceCheck(from, to, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ==========================================================================
    // Internal compliance check — runs before every transfer
    // ==========================================================================
    function _complianceCheck(address from, address to, uint256 amount) internal view {
        // Skip checks for mint/burn (from or to = address(0))
        if (from == address(0) || to == address(0)) return;

        // Both parties must be in the identity registry
        if (!identityRegistry.isRegistered(from)) revert IdentityNotVerified();
        if (!identityRegistry.isRegistered(to))   revert IdentityNotVerified();

        // Neither party can be frozen
        if (frozen[from]) revert AccountFrozen();
        if (frozen[to])   revert AccountFrozen();

        // All compliance modules must approve
        for (uint256 i = 0; i < complianceModules.length; i++) {
            IComplianceModule module = complianceModules[i];
            if (!module.canTransfer(from, to, amount)) {
                revert ComplianceCheckFailed(module.name());
            }
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from != address(0)) {
            if (balanceOf[from] < amount) revert InsufficientBalance();
            balanceOf[from] -= amount;
        }
        if (to != address(0)) {
            balanceOf[to] += amount;
        }
        if (from == address(0)) totalSupply += amount;
        if (to   == address(0)) totalSupply -= amount;
        emit Transfer(from, to, amount);
    }

    // ==========================================================================
    // Agent operations (regulatory/operational)
    // ==========================================================================

    // Mint to verified investor
    function mint(address to, uint256 amount) external onlyAgent {
        _complianceCheck(address(0), to, amount);
        _transfer(address(0), to, amount);
    }

    // Burn from verified investor
    function burn(address from, uint256 amount) external onlyAgent {
        _transfer(from, address(0), amount);
    }

    // Force transfer for regulatory recovery (court order, sanctions, key loss)
    function forcedTransfer(address from, address to, uint256 amount)
        external
        onlyAgent
        returns (bool)
    {
        _transfer(from, to, amount);
        emit ForcedTransfer(from, to, amount);
        return true;
    }

    // Freeze/unfreeze specific address
    function setAddressFrozen(address addr, bool isFrozen) external onlyAgent {
        frozen[addr] = isFrozen;
        emit AddressFrozen(addr, isFrozen);
    }

    // Pause/unpause all transfers
    function pause() external onlyAgent {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyAgent {
        paused = false;
        emit Unpaused();
    }
}

// =============================================================================
// SECTION 4 — DIVIDEND DISTRIBUTION
// =============================================================================
// Distribute yield (e.g., treasury bill coupon) to all token holders.
// Uses the "dividend per share" pattern for O(1) claims (no iteration needed).

contract DividendDistributor {
    ERC3643Token public immutable token;

    // Accumulated dividends per token unit (scaled by PRECISION)
    uint256 public dividendPerShare;
    uint256 public constant PRECISION = 1e18;

    // Per-investor snapshot of dividendPerShare at last claim/update
    mapping(address => uint256) public dividendCreditedPerShare;
    // Unclaimed dividends pending claim
    mapping(address => uint256) public unclaimedDividends;

    address public immutable distributionToken; // e.g., USDC for the coupon
    address public owner;

    event DividendDistributed(uint256 amount, uint256 perShare);
    event DividendClaimed(address indexed investor, uint256 amount);

    constructor(address _token, address _distributionToken) {
        token = ERC3643Token(_token);
        distributionToken = _distributionToken;
        owner = msg.sender;
    }

    // Called by the issuer to push dividends to all holders at once.
    // No loop needed — O(1) regardless of holder count.
    function distributeDividend(uint256 totalAmount) external {
        require(msg.sender == owner, "Not owner");
        require(token.totalSupply() > 0, "No supply");

        // Pull distribution tokens from owner
        IERC20(distributionToken).transferFrom(msg.sender, address(this), totalAmount);

        // Increase per-share dividend
        dividendPerShare += totalAmount * PRECISION / token.totalSupply();
        emit DividendDistributed(totalAmount, dividendPerShare);
    }

    // Called by token contract on every transfer to update snapshots
    function updateAccount(address account) external {
        require(msg.sender == address(token), "Not token");
        _updateAccount(account);
    }

    function _updateAccount(address account) internal {
        uint256 owed = token.balanceOf(account) *
            (dividendPerShare - dividendCreditedPerShare[account]) / PRECISION;
        unclaimedDividends[account] += owed;
        dividendCreditedPerShare[account] = dividendPerShare;
    }

    // Investor claims their accumulated dividends
    function claimDividend() external {
        _updateAccount(msg.sender);
        uint256 amount = unclaimedDividends[msg.sender];
        require(amount > 0, "Nothing to claim");
        unclaimedDividends[msg.sender] = 0;
        IERC20(distributionToken).transfer(msg.sender, amount);
        emit DividendClaimed(msg.sender, amount);
    }

    function pendingDividend(address account) external view returns (uint256) {
        uint256 owed = token.balanceOf(account) *
            (dividendPerShare - dividendCreditedPerShare[account]) / PRECISION;
        return unclaimedDividends[account] + owed;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// =============================================================================
// SECTION 5 — DELIVERY vs PAYMENT (DvP) ATOMIC SETTLEMENT
// =============================================================================
// DvP is the gold standard for securities settlement: the token is delivered
// if and only if the payment is received — in the same transaction.
// Eliminates counterparty risk vs legacy T+2 settlement.

contract DVPSettlement {
    enum State { Created, Active, Completed, Cancelled }

    struct Deal {
        address seller;         // delivers the RWA token
        address buyer;          // pays in stablecoin
        address rwaToken;       // ERC3643 token address
        uint256 tokenAmount;    // amount of RWA token to deliver
        address paymentToken;   // e.g., USDC
        uint256 paymentAmount;  // price in stablecoin
        uint256 expiresAt;      // deadline for buyer to fund
        State   state;
    }

    mapping(bytes32 => Deal) public deals;
    uint256 private _dealNonce;

    event DealCreated(bytes32 indexed dealId, address seller, address buyer);
    event DealFunded(bytes32 indexed dealId);
    event DealSettled(bytes32 indexed dealId);
    event DealCancelled(bytes32 indexed dealId);

    error DealExpired();
    error WrongState();
    error NotBuyer();
    error NotSeller();

    // Seller creates a deal by depositing the RWA token
    function createDeal(
        address buyer,
        address rwaToken,
        uint256 tokenAmount,
        address paymentToken,
        uint256 paymentAmount,
        uint256 duration
    ) external returns (bytes32 dealId) {
        dealId = keccak256(abi.encode(msg.sender, buyer, ++_dealNonce, block.timestamp));

        deals[dealId] = Deal({
            seller:        msg.sender,
            buyer:         buyer,
            rwaToken:      rwaToken,
            tokenAmount:   tokenAmount,
            paymentToken:  paymentToken,
            paymentAmount: paymentAmount,
            expiresAt:     block.timestamp + duration,
            state:         State.Created
        });

        // Seller deposits RWA token into escrow
        ERC3643Token(rwaToken).transferFrom(msg.sender, address(this), tokenAmount);
        deals[dealId].state = State.Active;

        emit DealCreated(dealId, msg.sender, buyer);
    }

    // Buyer funds the deal — triggers atomic settlement
    function settle(bytes32 dealId) external {
        Deal storage deal = deals[dealId];
        if (deal.state != State.Active)           revert WrongState();
        if (block.timestamp > deal.expiresAt)     revert DealExpired();
        if (msg.sender != deal.buyer)             revert NotBuyer();

        deal.state = State.Completed;

        // Atomic: pull payment from buyer + deliver token to buyer
        IERC20(deal.paymentToken).transferFrom(msg.sender, deal.seller, deal.paymentAmount);
        ERC3643Token(deal.rwaToken).transfer(deal.buyer, deal.tokenAmount);

        emit DealSettled(dealId);
    }

    // Seller cancels if buyer didn't fund before expiry
    function cancel(bytes32 dealId) external {
        Deal storage deal = deals[dealId];
        if (deal.state != State.Active)       revert WrongState();
        if (msg.sender != deal.seller)        revert NotSeller();
        if (block.timestamp <= deal.expiresAt) revert DealExpired(); // must be expired

        deal.state = State.Cancelled;
        ERC3643Token(deal.rwaToken).transfer(deal.seller, deal.tokenAmount);

        emit DealCancelled(dealId);
    }
}

// =============================================================================
// SECTION 6 — FRACTIONAL REAL ESTATE (ERC-20 WRAPPER)
// =============================================================================
// Wraps a non-fungible RWA asset into fungible ERC-20 shares.
// Example: $1M commercial property → 1,000,000 shares at $1 each.

contract FractionalRWA {
    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;

    uint256 public totalShares;
    uint256 public totalValueUSD;         // appraised value in USD (6 dec)
    mapping(address => uint256) public balanceOf;

    IdentityRegistry public immutable registry;
    address public manager;

    // Off-chain asset metadata
    string  public assetIdentifier;       // e.g., "US-NY-PROP-12345"
    string  public legalDocumentURI;      // IPFS or HTTPS link to legal docs
    uint256 public lastAppraisalDate;
    string  public propertyType;          // "commercial", "residential", etc.

    event SharesMinted(address indexed to, uint256 shares);
    event AssetAppraised(uint256 newValue, uint256 date);
    event IncomePaid(uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalShares,
        uint256 _initialValueUSD,
        address _registry,
        string memory _assetId,
        string memory _legalURI
    ) {
        name = _name;
        symbol = _symbol;
        totalShares = _totalShares;
        totalValueUSD = _initialValueUSD;
        registry = IdentityRegistry(_registry);
        manager = msg.sender;
        assetIdentifier = _assetId;
        legalDocumentURI = _legalURI;
        lastAppraisalDate = block.timestamp;
    }

    // Net Asset Value per share (USD, 6 decimals)
    function navPerShare() external view returns (uint256) {
        return totalValueUSD / totalShares;
    }

    // Manager mints shares to verified investors (e.g., during primary offering)
    function mint(address to, uint256 shares) external {
        require(msg.sender == manager, "Not manager");
        require(registry.isRegistered(to), "Not KYC verified");
        balanceOf[to] += shares;
        emit SharesMinted(to, shares);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(registry.isRegistered(to), "Recipient not KYC");
        require(balanceOf[msg.sender] >= amount, "Insufficient shares");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    // Manager updates the appraised value (based on independent appraisal)
    function updateAppraisal(uint256 newValueUSD) external {
        require(msg.sender == manager, "Not manager");
        totalValueUSD = newValueUSD;
        lastAppraisalDate = block.timestamp;
        emit AssetAppraised(newValueUSD, block.timestamp);
    }
}

// =============================================================================
// SECTION 7 — ORACLE PRICE FEED FOR RWA
// =============================================================================
// Off-chain assets need oracles to report NAV/price on-chain.
// For RWAs: daily NAV updates, proof-of-reserve, off-chain attestations.

interface IAggregatorV3 {
    function latestRoundData() external view returns (
        uint80 roundId, int256 answer, uint256 startedAt,
        uint256 updatedAt, uint80 answeredInRound
    );
}

contract RWAOracle {
    // For regulated assets: a custodian/auditor signs NAV attestations
    address public immutable attester;  // e.g., fund administrator's wallet
    uint256 public constant MAX_STALENESS = 24 hours; // NAV updated daily

    struct NAVData {
        uint256 navPerShare;    // USD value per share (18 decimals)
        uint256 totalAUM;       // total assets under management (18 decimals)
        uint256 timestamp;      // when this NAV was computed
        uint256 reportedAt;     // when this attestation was submitted on-chain
    }

    NAVData public latestNAV;

    event NAVUpdated(uint256 navPerShare, uint256 totalAUM, uint256 timestamp);

    error NotAttester();
    error StaleData();
    error FutureTimestamp();

    constructor(address _attester) {
        attester = _attester;
    }

    // Attester pushes daily NAV update with a signed attestation
    function updateNAV(
        uint256 navPerShare,
        uint256 totalAUM,
        uint256 navTimestamp,
        bytes calldata signature
    ) external {
        // Verify attester signed the NAV data
        bytes32 hash = keccak256(abi.encodePacked(
            navPerShare, totalAUM, navTimestamp, block.chainid, address(this)
        ));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        address recovered = _recover(ethHash, signature);
        if (recovered != attester) revert NotAttester();
        if (navTimestamp > block.timestamp) revert FutureTimestamp();

        latestNAV = NAVData({
            navPerShare: navPerShare,
            totalAUM:    totalAUM,
            timestamp:   navTimestamp,
            reportedAt:  block.timestamp
        });
        emit NAVUpdated(navPerShare, totalAUM, navTimestamp);
    }

    // Returns the NAV, reverts if stale
    function getNAV() external view returns (uint256 navPerShare, uint256 totalAUM) {
        if (block.timestamp - latestNAV.timestamp > MAX_STALENESS) revert StaleData();
        return (latestNAV.navPerShare, latestNAV.totalAUM);
    }

    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "Bad sig");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(hash, v, r, s);
    }
}

// =============================================================================
// SECTION 8 — ERC-1400 SECURITY TOKEN (PARTITIONS, DOCUMENTS, CONTROLLER)
// =============================================================================
// ERC-1400 is the Polymath family of security token standards — an ALTERNATIVE
// to the ERC-3643 token in Section 3. Both enforce compliant transfers, but the
// design philosophy differs:
//
//   ERC-3643 (Section 3)         ERC-1400 (this section)
//   --------------------         -----------------------
//   identity-centric             token-centric / partition-centric
//   "WHO can receive?"           "HOW is the balance structured?"
//   KYC + compliance built in    KYC left open; structure built in
//   reverts on failure           returns ERC-1066 reason codes (try before send)
//   dominant in EU/Tokeny        flexible for complex tranche structures
//
// ERC-1400 is itself a bundle of EIPs:
//   - ERC-1410: PARTITIONS (tranches) — one balance split into named buckets
//               (e.g., locked vs. unlocked, share class A vs. B)
//   - ERC-1594: CORE — issue/redeem instead of mint/burn; canTransfer* returns a
//               reason code so a caller knows WHY a transfer would fail in advance
//   - ERC-1643: DOCUMENTS — legal documents (prospectus, terms) anchored on-chain
//   - ERC-1644: CONTROLLER — forced transfer/redeem for regulatory recovery
//
// ERC-1066 status codes (returned by canTransferByPartition):
//   0x50 transfer failure   0x51 transfer success   0x52 insufficient balance
//   0x54 insufficient allowance   0x55 funds locked
//   0x56 invalid sender     0x57 invalid receiver   0x59 invalid operator

contract ERC1400Token {
    // ---- ERC-20-style metadata ----
    string public name;
    string public symbol;
    uint8  public constant decimals = 18;
    uint256 public totalSupply;

    // ---- ERC-1410: balances are split into PARTITIONS (tranches) ----
    // A holder has a separate balance per partition. The aggregate balanceOf is
    // the sum across partitions and is what ERC-20 consumers see.
    mapping(address => uint256) public balanceOf;                          // aggregate
    mapping(address => mapping(bytes32 => uint256)) public balanceOfByPartition;
    mapping(address => bytes32[]) internal _partitionsOf;                  // partitions a holder touched
    mapping(address => mapping(bytes32 => bool)) internal _knownPartition; // dedupe helper

    // Example partitions (any bytes32 works; commonly ASCII-encoded labels)
    bytes32 public constant LOCKED   = "locked";   // e.g., under lock-up / vesting
    bytes32 public constant UNLOCKED = "unlocked"; // freely transferable

    // ---- ERC-1410/1594: operators (delegates allowed to move tokens) ----
    mapping(address => mapping(address => bool)) internal _operators;      // global operators
    mapping(bytes32 => mapping(address => mapping(address => bool))) internal _operatorsByPartition;

    // ---- ERC-1643: on-chain document registry ----
    struct Document {
        string  uri;        // IPFS/HTTPS link to the legal document
        bytes32 docHash;    // keccak256 of the document contents (integrity)
        uint256 timestamp;  // last update
    }
    mapping(bytes32 => Document) internal _documents;  // name => document
    bytes32[] internal _documentNames;

    // ---- Compliance / access control ----
    IdentityRegistry public immutable identityRegistry; // shared with Section 1
    address public owner;
    address public controller;   // ERC-1644 regulatory controller
    bool    public isControllable; // can be turned off permanently to reassure holders
    bool    public isIssuable;     // once false, no more tokens can ever be issued

    // ---- Events ----
    event TransferByPartition(
        bytes32 indexed partition, address operator,
        address indexed from, address indexed to, uint256 value, bytes data
    );
    event IssuedByPartition(bytes32 indexed partition, address indexed to, uint256 value);
    event RedeemedByPartition(bytes32 indexed partition, address operator, address indexed from, uint256 value);
    event AuthorizedOperator(address indexed operator, address indexed holder);
    event RevokedOperator(address indexed operator, address indexed holder);
    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 docHash);
    event ControllerTransfer(address controller, address indexed from, address indexed to, uint256 value, bytes data);
    event ControllerRedemption(address controller, address indexed from, uint256 value, bytes data);

    error NotOwner();
    error NotController();
    error NotIssuable();
    error TransferRejected(bytes1 code);

    constructor(string memory _name, string memory _symbol, address _identityRegistry) {
        name = _name;
        symbol = _symbol;
        identityRegistry = IdentityRegistry(_identityRegistry);
        owner = msg.sender;
        controller = msg.sender;
        isControllable = true;
        isIssuable = true;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ==========================================================================
    // ERC-1594: canTransferByPartition — DRY-RUN a transfer, NO state change.
    // Wallets/exchanges call this first to show the user WHY a transfer would
    // fail, instead of broadcasting a tx that reverts. Returns:
    //   code         ERC-1066 status byte (0x51 = success)
    //   reason       extra application data (here: a human-readable label)
    //   destination  partition the tokens land in (may differ from source)
    // ==========================================================================
    function canTransferByPartition(
        address from,
        address to,
        bytes32 partition,
        uint256 value,
        bytes calldata /* data */
    ) public view returns (bytes1 code, bytes32 reason, bytes32 destination) {
        if (to == address(0))                              return (0x57, "invalid receiver", partition);
        if (value == 0 || balanceOfByPartition[from][partition] < value)
                                                           return (0x52, "insufficient balance", partition);
        if (!identityRegistry.isRegistered(to))            return (0x57, "receiver not KYC'd", partition);
        if (!identityRegistry.isRegistered(from))          return (0x56, "sender not KYC'd", partition);
        if (partition == LOCKED)                           return (0x55, "funds locked", partition);
        // Success: locked partition would route to UNLOCKED, others stay put.
        destination = partition;
        return (0x51, "transferable", destination);
    }

    // ==========================================================================
    // ERC-1410: transferByPartition — move tokens within a specific tranche.
    // ==========================================================================
    function transferByPartition(bytes32 partition, address to, uint256 value, bytes calldata data)
        external
        returns (bytes32)
    {
        return _transferByPartition(partition, msg.sender, msg.sender, to, value, data);
    }

    // Operator-driven transfer (delegate authorized by the holder).
    function operatorTransferByPartition(
        bytes32 partition, address from, address to, uint256 value, bytes calldata data
    ) external returns (bytes32) {
        require(_isOperatorFor(partition, msg.sender, from), "not authorized operator");
        return _transferByPartition(partition, msg.sender, from, to, value, data);
    }

    function _transferByPartition(
        bytes32 partition, address operator, address from, address to, uint256 value, bytes calldata data
    ) internal returns (bytes32) {
        // Enforce the same rule the dry-run reports. Reverting keeps state safe.
        (bytes1 code,, bytes32 dest) = canTransferByPartition(from, to, partition, value, data);
        if (code != 0x51) revert TransferRejected(code);

        balanceOfByPartition[from][partition] -= value;
        balanceOf[from] -= value;
        _creditPartition(to, dest, value);

        emit TransferByPartition(partition, operator, from, to, value, data);
        return dest;
    }

    // ==========================================================================
    // ERC-1594: issue / redeem (the security-token equivalent of mint / burn).
    // ==========================================================================
    function issueByPartition(bytes32 partition, address to, uint256 value, bytes calldata /* data */)
        external
        onlyOwner
    {
        if (!isIssuable) revert NotIssuable();
        require(identityRegistry.isRegistered(to), "receiver not KYC'd");
        _creditPartition(to, partition, value);
        totalSupply += value;
        emit IssuedByPartition(partition, to, value);
    }

    function redeemByPartition(bytes32 partition, uint256 value, bytes calldata /* data */) external {
        balanceOfByPartition[msg.sender][partition] -= value;
        balanceOf[msg.sender] -= value;
        totalSupply -= value;
        emit RedeemedByPartition(partition, msg.sender, msg.sender, value);
    }

    // Permanently disable issuance — a strong signal to investors (fixed supply).
    function finalizeIssuance() external onlyOwner {
        isIssuable = false;
    }

    // ==========================================================================
    // ERC-1410: operator management
    // ==========================================================================
    function authorizeOperator(address operator) external {
        _operators[msg.sender][operator] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }

    function revokeOperator(address operator) external {
        _operators[msg.sender][operator] = false;
        emit RevokedOperator(operator, msg.sender);
    }

    function authorizeOperatorByPartition(bytes32 partition, address operator) external {
        _operatorsByPartition[partition][msg.sender][operator] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }

    function isOperator(address operator, address holder) external view returns (bool) {
        return _operators[holder][operator];
    }

    function _isOperatorFor(bytes32 partition, address operator, address holder) internal view returns (bool) {
        return operator == holder
            || _operators[holder][operator]
            || _operatorsByPartition[partition][holder][operator];
    }

    // ==========================================================================
    // ERC-1643: document management (legal docs anchored on-chain)
    // ==========================================================================
    function setDocument(bytes32 docName, string calldata uri, bytes32 docHash) external onlyOwner {
        if (_documents[docName].timestamp == 0) _documentNames.push(docName);
        _documents[docName] = Document(uri, docHash, block.timestamp);
        emit DocumentUpdated(docName, uri, docHash);
    }

    function getDocument(bytes32 docName) external view returns (string memory, bytes32, uint256) {
        Document storage d = _documents[docName];
        return (d.uri, d.docHash, d.timestamp);
    }

    function getAllDocuments() external view returns (bytes32[] memory) {
        return _documentNames;
    }

    // ==========================================================================
    // ERC-1644: controller operations (regulatory forced transfer / redemption).
    // Holders can verify isControllable() — if false, no forced moves are possible.
    // ==========================================================================
    function controllerTransfer(
        bytes32 partition, address from, address to, uint256 value, bytes calldata data, bytes calldata /* opData */
    ) external {
        if (msg.sender != controller || !isControllable) revert NotController();
        balanceOfByPartition[from][partition] -= value;
        balanceOf[from] -= value;
        _creditPartition(to, partition, value);
        emit ControllerTransfer(msg.sender, from, to, value, data);
        emit TransferByPartition(partition, msg.sender, from, to, value, data);
    }

    function controllerRedeem(
        bytes32 partition, address from, uint256 value, bytes calldata data, bytes calldata /* opData */
    ) external {
        if (msg.sender != controller || !isControllable) revert NotController();
        balanceOfByPartition[from][partition] -= value;
        balanceOf[from] -= value;
        totalSupply -= value;
        emit ControllerRedemption(msg.sender, from, value, data);
    }

    // Renounce control permanently (token becomes non-controllable forever).
    function renounceControl() external onlyOwner {
        isControllable = false;
        controller = address(0);
    }

    // ==========================================================================
    // Views & helpers
    // ==========================================================================
    function partitionsOf(address holder) external view returns (bytes32[] memory) {
        return _partitionsOf[holder];
    }

    function _creditPartition(address to, bytes32 partition, uint256 value) internal {
        if (!_knownPartition[to][partition]) {
            _knownPartition[to][partition] = true;
            _partitionsOf[to].push(partition);
        }
        balanceOfByPartition[to][partition] += value;
        balanceOf[to] += value;
    }
}

// =============================================================================
// PROFESSIONAL CHECKLIST: RWA AUDIT POINTS
// =============================================================================
//
// [ ] Identity registry: both sender and receiver verified before transfer
// [ ] Claim expiry: KYC claims have expiry dates, expired = transfer denied
// [ ] Trusted issuers: only whitelisted KYC providers can issue claims
// [ ] Compliance modules: all modules checked on every transfer (even mint/burn?)
// [ ] Forced transfer: only agent role, emits ForcedTransfer event for auditability
// [ ] Freeze: frozen accounts cannot send or receive
// [ ] Pause: emergency stop works correctly for all transfer paths
// [ ] Dividend: per-share accounting avoids iteration over holders
// [ ] DvP: atomicity guaranteed — if payment fails, token stays in escrow
// [ ] DvP: expiry allows seller to reclaim if buyer defaults
// [ ] Oracle: NAV staleness check prevents stale price manipulation
// [ ] Oracle: attester signature verified on every NAV update
// [ ] Fractional: all share transfers require KYC check
// [ ] Legal compliance: legalDocumentURI points to binding legal docs on IPFS
// [ ] Role separation: owner (governance) vs agent (operations) vs attester (oracle)
// [ ] ERC-1400 partitions: per-partition balances always sum to aggregate balanceOf
// [ ] ERC-1400 canTransferByPartition: dry-run logic matches the revert path exactly
// [ ] ERC-1400 reason codes: ERC-1066 byte returned for every failure case
// [ ] ERC-1400 operators: per-partition and global operator authority checked
// [ ] ERC-1400 documents: docHash matches off-chain file (integrity, not just URI)
// [ ] ERC-1400 controller: forced moves gated by isControllable; renounce is permanent
// [ ] ERC-1400 issuance: finalizeIssuance() makes supply fixed and irreversible
