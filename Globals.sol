// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY GLOBAL VARIABLES - Complete Reference
// From Zero to Professional
// ============================================================================

// Interface ID example
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Globals {
    // ============================================================================
    // 1. BLOCK PROPERTIES
    // ============================================================================
    // Information about the current block
    // Available globally in all functions

    function getBlockInfo()
        public
        view
        returns (
            uint256 blockNumber,
            uint256 timestamp,
            uint256 difficulty,
            uint256 gasLimit,
            address coinbase,
            uint256 chainId,
            uint256 baseFee
        )
    {
        // Current block number
        blockNumber = block.number;

        // Current block timestamp (Unix timestamp in seconds)
        // WARNING: Can be manipulated by miners within ~15 seconds
        timestamp = block.timestamp;

        // Current block difficulty (deprecated in PoS, returns PREVRANDAO)
        difficulty = block.difficulty;

        // Current block gas limit
        gasLimit = block.gaslimit;

        // Current block miner's address (coinbase)
        coinbase = block.coinbase;

        // Chain ID (1 for Ethereum mainnet)
        chainId = block.chainid;

        // Base fee of current block (EIP-1559)
        baseFee = block.basefee;
    }

    // block.prevrandao - Random number from beacon chain (Ethereum PoS)
    // Replaces block.difficulty after The Merge
    function getRandomness() public view returns (uint256) {
        return block.prevrandao; // Same as block.difficulty but semantically different
    }

    // ============================================================================
    // 2. MESSAGE PROPERTIES
    // ============================================================================
    // Information about the current message/transaction
    // Changes with each external call

    function getMsgInfo()
        public
        payable
        returns (
            address sender,
            uint256 value,
            bytes memory data,
            bytes4 sig,
            uint256 gasLeft
        )
    {
        // Address of the caller (immediate caller, not origin)
        sender = msg.sender;

        // Amount of wei sent with message
        value = msg.value;

        // Complete calldata
        data = msg.data;

        // First four bytes of calldata (function selector)
        sig = msg.sig;

        // Remaining gas
        gasLeft = gasleft();

        return (sender, value, data, sig, gasLeft);
    }

    // ============================================================================
    // 3. TRANSACTION PROPERTIES
    // ============================================================================
    // Information about the transaction

    function getTxInfo()
        public
        view
        returns (address origin, uint256 gasPrice)
    {
        // Original external account that started the transaction
        // WARNING: Never use for authorization (security risk)
        origin = tx.origin;

        // Gas price of the transaction
        gasPrice = tx.gasprice;

        return (origin, gasPrice);
    }

    // Demonstrating tx.origin vs msg.sender
    // tx.origin: Always the EOA that started the transaction
    // msg.sender: Immediate caller (can be contract or EOA)
    function originVsSender()
        public
        view
        returns (address origin, address sender, bool isDirectCall)
    {
        origin = tx.origin;
        sender = msg.sender;
        isDirectCall = (tx.origin == msg.sender);

        return (origin, sender, isDirectCall);
    }

    // ============================================================================
    // 4. ADDRESS PROPERTIES
    // ============================================================================
    // Properties available on address types

    function addressProperties(
        address payable addr
    )
        public
        view
        returns (uint256 balance, bytes memory code, bytes32 codeHash)
    {
        // Get balance of address in wei
        balance = addr.balance;

        // Get contract code (empty for EOA)
        code = addr.code;

        // Get hash of contract code
        codeHash = addr.codehash;

        return (balance, code, codeHash);
    }

    // Check if address is a contract
    function isContract(address addr) public view returns (bool) {
        // If code size > 0, it's a contract
        return addr.code.length > 0;
    }

    // Get this contract's balance
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // ============================================================================
    // 5. ETHER UNITS
    // ============================================================================
    // Built-in denominations for Ether
    // 1 wei = 1
    // 1 gwei = 10^9 wei
    // 1 ether = 10^18 wei

    function etherUnitsDemo()
        public
        pure
        returns (uint256 oneWei, uint256 oneGwei, uint256 oneEther)
    {
        oneWei = 1 wei; // 1
        oneGwei = 1 gwei; // 1000000000 (10^9)
        oneEther = 1 ether; // 1000000000000000000 (10^18)

        return (oneWei, oneGwei, oneEther);
    }

    // Common conversions
    function etherConversions()
        public
        pure
        returns (uint256 weiInEther, uint256 gweiInEther, uint256 etherInGwei)
    {
        weiInEther = 1 ether / 1 wei; // 10^18
        gweiInEther = 1 ether / 1 gwei; // 10^9
        etherInGwei = 1 ether / 1 gwei; // 10^9

        return (weiInEther, gweiInEther, etherInGwei);
    }

    // Practical ether calculations
    function calculateGasCost(
        uint256 gasUsed,
        uint256 gasPriceGwei
    ) public pure returns (uint256 costWei, uint256 costEther) {
        // Convert gwei to wei
        uint256 gasPriceWei = gasPriceGwei * 1 gwei;

        // Calculate cost in wei
        costWei = gasUsed * gasPriceWei;

        // Cost in ether (for display)
        costEther = costWei / 1 ether;

        return (costWei, costEther);
    }

    // ============================================================================
    // 6. TIME UNITS
    // ============================================================================
    // Built-in time denominations
    // seconds, minutes, hours, days, weeks
    // All time units convert to uint256 in seconds

    function timeUnitsDemo()
        public
        pure
        returns (
            uint256 oneSecond,
            uint256 oneMinute,
            uint256 oneHour,
            uint256 oneDay,
            uint256 oneWeek
        )
    {
        oneSecond = 1 seconds; // 1
        oneMinute = 1 minutes; // 60
        oneHour = 1 hours; // 3600
        oneDay = 1 days; // 86400
        oneWeek = 1 weeks; // 604800

        return (oneSecond, oneMinute, oneHour, oneDay, oneWeek);
    }

    // Time-based logic
    uint256 public creationTime;

    constructor() {
        creationTime = block.timestamp;
    }

    function hasOneDayPassed() public view returns (bool) {
        return block.timestamp >= creationTime + 1 days;
    }

    function hasOneWeekPassed() public view returns (bool) {
        return block.timestamp >= creationTime + 1 weeks;
    }

    function timeElapsed() public view returns (uint256) {
        return block.timestamp - creationTime;
    }

    // Deadline checking
    function isBeforeDeadline(uint256 deadline) public view returns (bool) {
        return block.timestamp < deadline;
    }

    function isAfterDeadline(uint256 deadline) public view returns (bool) {
        return block.timestamp > deadline;
    }

    // ============================================================================
    // 7. ABI ENCODING FUNCTIONS
    // ============================================================================
    // Global functions for ABI encoding/decoding

    function abiEncodingExamples(
        address addr,
        uint256 amount
    )
        public
        pure
        returns (
            bytes memory encoded,
            bytes memory encodePacked,
            bytes memory encodeWithSignature,
            bytes memory encodeWithSelector
        )
    {
        // Standard ABI encoding (with padding)
        encoded = abi.encode(addr, amount);

        // Packed encoding (no padding, more compact)
        encodePacked = abi.encodePacked(addr, amount);

        // Encode with function signature
        encodeWithSignature = abi.encodeWithSignature(
            "transfer(address,uint256)",
            addr,
            amount
        );

        // Encode with function selector
        bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
        encodeWithSelector = abi.encodeWithSelector(selector, addr, amount);

        return (encoded, encodePacked, encodeWithSignature, encodeWithSelector);
    }

    // ABI decoding
    function abiDecodingExample(
        bytes memory data
    ) public pure returns (address, uint256) {
        (address addr, uint256 amount) = abi.decode(data, (address, uint256));
        return (addr, amount);
    }

    // ============================================================================
    // 8. CRYPTOGRAPHIC FUNCTIONS
    // ============================================================================
    // Global cryptographic hash functions

    function hashingExamples(
        string memory text
    )
        public
        pure
        returns (
            bytes32 keccak256Hash,
            bytes32 sha256Hash,
            bytes20 ripemd160Hash
        )
    {
        bytes memory data = bytes(text);

        // Keccak256 (most common in Ethereum)
        keccak256Hash = keccak256(data);

        // SHA256
        sha256Hash = sha256(data);

        // RIPEMD160
        ripemd160Hash = ripemd160(data);

        return (keccak256Hash, sha256Hash, ripemd160Hash);
    }

    // Hash multiple values
    function hashMultiple(
        address addr,
        uint256 amount,
        string memory message
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr, amount, message));
    }

    // ============================================================================
    // 9. SIGNATURE VERIFICATION
    // ============================================================================
    // Recover signer from signature

    function recoverSigner(
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        // Recover signer address from signature
        return ecrecover(messageHash, v, r, s);
    }

    // Verify signature
    function verifySignature(
        address signer,
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bool) {
        address recoveredSigner = ecrecover(messageHash, v, r, s);
        return recoveredSigner == signer;
    }

    // ============================================================================
    // 10. TYPE INFORMATION
    // ============================================================================
    // Get information about types

    function typeInfo()
        public
        pure
        returns (
            uint256 maxUint256,
            int256 maxInt256,
            int256 minInt256,
            uint8 maxUint8
        )
    {
        // Maximum values
        maxUint256 = type(uint256).max; // 2^256 - 1
        maxInt256 = type(int256).max; // 2^255 - 1
        minInt256 = type(int256).min; // -2^255
        maxUint8 = type(uint8).max; // 255

        return (maxUint256, maxInt256, minInt256, maxUint8);
    }

    // Interface ID
    function getInterfaceId() public pure returns (bytes4) {
        return type(IERC20).interfaceId;
    }

    // ============================================================================
    // 11. ERROR HANDLING GLOBALS
    // ============================================================================

    // gasleft() - remaining gas
    function checkGasRemaining() public view returns (uint256 gasRemaining) {
        uint256 gasBefore = gasleft();

        // Some operations
        uint256 result = 0;
        for (uint256 i = 0; i < 100; i++) {
            result += i;
        }

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;

        return gasAfter;
    }

    // ============================================================================
    // 12. SPECIAL VARIABLES
    // ============================================================================

    // this - current contract instance
    function getThisAddress() public view returns (address) {
        return address(this);
    }

    // selfdestruct - destroy contract (deprecated, will be removed)
    // Shown for educational purposes only
    // function destroyContract() public {
    //     selfdestruct(payable(msg.sender));
    // }

    // ============================================================================
    // 13. PRACTICAL EXAMPLES
    // ============================================================================

    // Time-locked withdrawal
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lockTime;

    function deposit(uint256 lockDuration) public payable {
        require(msg.value > 0, "Must send ether");
        deposits[msg.sender] += msg.value;
        lockTime[msg.sender] = block.timestamp + lockDuration;
    }

    function withdraw() public {
        require(block.timestamp >= lockTime[msg.sender], "Still locked");
        require(deposits[msg.sender] > 0, "No balance");

        uint256 amount = deposits[msg.sender];
        deposits[msg.sender] = 0;

        payable(msg.sender).transfer(amount);
    }

    // Rate limiting
    mapping(address => uint256) public lastActionTime;
    uint256 public constant RATE_LIMIT = 1 minutes;

    function rateLimitedAction() public {
        require(
            block.timestamp >= lastActionTime[msg.sender] + RATE_LIMIT,
            "Rate limit exceeded"
        );

        lastActionTime[msg.sender] = block.timestamp;

        // Perform action
    }

    // Expirable offers
    struct Offer {
        address seller;
        uint256 price;
        uint256 expiresAt;
    }

    mapping(uint256 => Offer) public offers;

    function createOffer(
        uint256 offerId,
        uint256 price,
        uint256 duration
    ) public {
        offers[offerId] = Offer({
            seller: msg.sender,
            price: price,
            expiresAt: block.timestamp + duration
        });
    }

    function isOfferValid(uint256 offerId) public view returns (bool) {
        return block.timestamp < offers[offerId].expiresAt;
    }

    // ============================================================================
    // 14. SECURITY CONSIDERATIONS
    // ============================================================================

    // NEVER use tx.origin for authorization
    // Bad example (vulnerable to phishing):
    // function badAuthorization() public {
    //     require(tx.origin == owner, "Not owner");
    //     // This is vulnerable!
    // }

    // Good example (use msg.sender):
    address public owner;

    function goodAuthorization() public view {
        require(msg.sender == owner, "Not owner");
        // This is secure
    }

    // Be careful with block.timestamp
    // Miners can manipulate it by ~15 seconds
    function timestampVulnerable() public view returns (bool) {
        // Don't rely on exact timestamp for critical logic
        // Use block.number for more predictable timing
        return block.timestamp % 2 == 0; // Vulnerable to manipulation
    }

    // Better: use block.number
    function blockNumberSafe() public view returns (bool) {
        return block.number % 2 == 0; // More predictable
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. block.timestamp can be manipulated by miners (~15 seconds)
    // 2. Use block.number for more predictable timing
    // 3. NEVER use tx.origin for authorization (security vulnerability)
    // 4. gasleft() is useful for gas optimization and testing
    // 5. Ether units: 1 ether = 10^18 wei, 1 gwei = 10^9 wei
    // 6. Time units: 1 days = 86400, 1 weeks = 604800
    // 7. block.prevrandao replaces block.difficulty (post-Merge)
    // 8. msg.sender vs tx.origin: msg.sender is immediate caller
    // 9. Use address(this).balance to check contract balance
    // 10. type(T).max/min for type boundaries
    // 11. keccak256 is most common hash function in Ethereum
    // 12. ecrecover for signature verification
    // 13. abi.encode vs abi.encodePacked: packed is more compact
    // 14. Always validate timestamps and block numbers in critical logic
    // ============================================================================
}
