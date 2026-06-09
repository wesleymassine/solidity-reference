// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ============================================================
//  L2.SOL - Layer 2 & Cross-Chain: Complete Reference
// ============================================================
//
//  Covers everything a professional developer needs to build
//  on and across Layer 2 networks: opcode differences, gas
//  models, native bridges, messaging protocols, and patterns
//  specific to Optimistic Rollups and ZK Rollups.
//
//  SECTIONS:
//  1.  L2 Architecture Overview
//  2.  Opcode Differences by Chain
//  3.  Gas Model Differences
//  4.  Chain Detection & Multi-Chain Patterns
//  5.  Native Bridges — Optimism / Base (OP Stack)
//  6.  Native Bridges — Arbitrum (Nitro)
//  7.  Chainlink CCIP — Cross-Chain Messaging
//  8.  LayerZero V2 — Omnichain Messaging
//  9.  Hyperlane — Permissionless Messaging
//  10. Cross-Chain Token Standards (OFT, xERC20)
//  11. ZK Rollup Specifics (zkSync Era, Polygon zkEVM)
//  12. L2 Security Considerations
//  13. Multi-Chain Deployment Patterns
//  14. L2 Developer Checklist
//
// ============================================================

// ============================================================
// SECTION 1: L2 ARCHITECTURE OVERVIEW
// ============================================================

/*
 * ROLLUP TAXONOMY:
 *
 * OPTIMISTIC ROLLUPS (assume valid, prove if disputed)
 * ├── Optimism (OP Stack)   — EVM equivalent, 7-day fraud proof window
 * ├── Base                  — OP Stack fork by Coinbase
 * ├── Zora Network          — OP Stack fork
 * ├── Mode                  — OP Stack fork
 * └── Arbitrum One (Nitro)  — EVM compatible, ArbOS on WASM, 7-day window
 *
 * ZK ROLLUPS (validity proofs, no challenge period)
 * ├── zkSync Era            — zkEVM, custom opcodes, native AA
 * ├── Polygon zkEVM         — Type 2 zkEVM (EVM equivalent)
 * ├── Scroll                — Type 2 zkEVM, EVM bytecode compatible
 * ├── Linea                 — Type 2 zkEVM by Consensys
 * └── Starknet              — Cairo VM, not EVM (different language)
 *
 * VALIDIUMS / VOLITIONS (ZK proofs + off-chain data)
 * └── Immutable X, Sorare  — NFT-focused, not EVM
 *
 * KEY DISTINCTION:
 * EVM Equivalent (Type 2): all opcodes produce identical results to mainnet
 * EVM Compatible (Type 3): most opcodes work, small differences exist
 * EVM-Inspired (Type 4): different VM, Solidity compiles but runs differently
 *
 * FINALITY:
 * Optimistic: ~7 days for withdrawals to mainnet (fraud proof window)
 * ZK:         ~minutes to hours (proof generation time)
 * Bridge:     near-instant with liquidity networks (Across, Stargate)
 *
 * SEQUENCER:
 * - Centralized today on most L2s (risk: censorship, downtime)
 * - Decentralized sequencer: in progress for Arbitrum, Optimism
 * - If sequencer is down, users can force-include txs directly on L1
 */

// ============================================================
// SECTION 2: OPCODE DIFFERENCES BY CHAIN
// ============================================================

/*
 * CRITICAL OPCODES TO AUDIT ON EVERY L2 DEPLOYMENT:
 *
 * ┌──────────────────┬───────────┬──────────┬──────────┬────────────┐
 * │ Opcode           │ Mainnet   │ Arbitrum │ OP Stack │ zkSync Era │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ block.number     │ L1 block  │ L2 block │ L2 block │ L2 block   │
 * │                  │           │ (~0.25s) │ (2s)     │ (~1s)      │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ block.timestamp  │ L1 time   │ L2 time  │ L2 time  │ L2 time    │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ block.difficulty │ PREVRANDAO│ constant │ constant │ constant   │
 * │ / block.prevrandao│ (L1)     │ = 1      │ = 0      │ = 0        │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ block.basefee    │ EIP-1559  │ L2 fee   │ L2 fee   │ L2 fee     │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ block.coinbase   │ validator │ sequencer│ sequencer│ sequencer  │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ SELFDESTRUCT     │ works     │ works    │ works    │ deprecated │
 * │                  │           │          │          │ (no-op)    │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ PUSH0            │ yes       │ yes      │ yes      │ yes        │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ tx.gasprice      │ effective │ L2 price │ L2 price │ L2 price   │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ TSTORE/TLOAD     │ yes       │ yes      │ yes      │ yes*       │
 * │ (EIP-1153)       │           │          │          │ *recent    │
 * ├──────────────────┼───────────┼──────────┼──────────┼────────────┤
 * │ CREATE2          │ yes       │ yes      │ yes      │ yes*       │
 * │                  │           │          │          │ *diff addr │
 * └──────────────────┴───────────┴──────────┴──────────┴────────────┘
 *
 * CRITICAL NOTE — CREATE2 on zkSync Era:
 * The address derivation formula is DIFFERENT from mainnet.
 * zkSync uses: keccak256(0x2020...||deployer||salt||keccak256(bytecode)||keccak256(constructorArgs))
 * This means CREATE2 addresses computed off-chain (mainnet formula) will NOT match.
 * Use the zkSync SDK for address prediction.
 *
 * PREVRANDAO / DIFFICULTY:
 * - Never use block.prevrandao as a source of randomness on L2
 * - On Arbitrum it is always 1 — completely predictable
 * - Use Chainlink VRF for any on-chain randomness
 */

/// @title OpcodeAudit — demonstrates dangerous opcode assumptions on L2
contract OpcodeAudit {

    // -------------------------------------------------------
    // DANGER: block.number has different semantics on every chain
    // -------------------------------------------------------

    // BAD — assumes block.number ≈ time (only true on mainnet ~12s/block)
    function badTimelock(uint256 blocksToWait) external view returns (bool) {
        // On Arbitrum: blocks ~0.25s → 48h = 691,200 blocks (vs 14,400 on mainnet)
        // On OP Stack: blocks ~2s → 48h = 86,400 blocks
        // This creates completely different timelocks per chain!
        return block.number > blocksToWait;
    }

    // GOOD — always use block.timestamp for time-based logic
    function goodTimelock(uint256 unlockTime) external view returns (bool) {
        return block.timestamp >= unlockTime;
    }

    // -------------------------------------------------------
    // DANGER: block.prevrandao / block.difficulty as randomness
    // -------------------------------------------------------

    // BAD — completely predictable on L2
    function badRandom() external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.prevrandao,  // = 1 on Arbitrum, = 0 on OP Stack
            block.timestamp,   // known to sequencer before tx
            msg.sender
        )));
        // Sequencer or miner can manipulate this
    }

    // GOOD — use Chainlink VRF (or commit-reveal for lower stakes)
    // See Cryptography.sol for commit-reveal pattern

    // -------------------------------------------------------
    // DANGER: tx.gasprice on L2 is not the full cost
    // -------------------------------------------------------

    // BAD — tx.gasprice on L2 only reflects L2 execution cost
    // It does NOT include the L1 data posting fee (calldata cost)
    function badGasCheck() external view returns (bool) {
        return tx.gasprice < 1 gwei; // meaningless on L2
    }

    // GOOD — check gas costs using chain-specific precompiles or oracles

    // -------------------------------------------------------
    // DANGER: SELFDESTRUCT on zkSync Era
    // -------------------------------------------------------

    // On zkSync Era, SELFDESTRUCT is a no-op (does nothing, does not revert)
    // Contracts that rely on SELFDESTRUCT to sweep ETH will silently fail
    // BAD: function destroy() external { selfdestruct(payable(owner)); }

    // GOOD — use explicit withdrawal pattern instead
    function safeWithdraw(address payable to) external {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool ok,) = to.call{value: balance}("");
        require(ok, "Transfer failed");
    }

    // -------------------------------------------------------
    // DANGER: msg.sender on L2 with cross-chain messages
    // -------------------------------------------------------

    // When receiving a cross-chain message, msg.sender is the BRIDGE contract,
    // not the original user. Always validate the original sender via the bridge API.

    address public immutable bridge;

    modifier onlyFromL1(address expectedL1Sender) {
        require(msg.sender == bridge, "Not bridge");
        // OP Stack: get original sender via alias
        address l1Sender = AddressAliasHelper.undoL1ToL2Alias(msg.sender);
        require(l1Sender == expectedL1Sender, "Wrong L1 sender");
        _;
    }
}

/// @notice OP Stack address aliasing — L1 → L2 message sender transformation
library AddressAliasHelper {
    uint160 constant OFFSET = uint160(0x1111000000000000000000000000000000001111);

    /// @notice Convert L1 contract address to its L2 alias
    function applyL1ToL2Alias(address l1Address) internal pure returns (address l2Alias) {
        unchecked { l2Alias = address(uint160(l1Address) + OFFSET); }
    }

    /// @notice Recover original L1 address from L2 alias
    function undoL1ToL2Alias(address l2Alias) internal pure returns (address l1Address) {
        unchecked { l1Address = address(uint160(l2Alias) - OFFSET); }
    }
}

// ============================================================
// SECTION 3: GAS MODEL DIFFERENCES
// ============================================================

/*
 * L2 TRANSACTION COST = L2 execution cost + L1 data posting cost
 *
 * OP STACK GAS MODEL:
 *   totalCost = l2GasUsed × l2GasPrice
 *             + l1DataCost
 *   l1DataCost = (compressedTxBytes + fixedOverhead) × l1BaseFee × scalar
 *
 *   Access via precompile at 0x420000000000000000000000000000000000000F:
 *   - getL1Fee(bytes)    → wei cost to post tx data to L1
 *   - getL1GasUsed(bytes)→ estimated L1 gas for calldata
 *   - l1BaseFee()        → current L1 base fee
 *   - scalar()           → multiplier for profit margin
 *
 * ARBITRUM GAS MODEL:
 *   totalCost = (l2GasUsed + l1GasEstimate) × arbGasPrice
 *   - ArbGasInfo precompile at 0x000000000000000000000000000000000000006C
 *   - NodeInterface at 0x00000000000000000000000000000000000000C8
 *   - getL1BaseFeeEstimate()
 *
 * PRACTICAL IMPLICATIONS:
 * - Calldata is expensive: minimize on-chain storage, prefer events
 * - Short calldata = cheaper L1 fee (compress where possible)
 * - Batching calls saves proportionally more on L2 than L1
 * - EIP-4844 (Proto-Danksharding) reduces L1 data cost ~10x (blobs)
 *   → All major L2s adopted EIP-4844 post Dencun upgrade (March 2024)
 */

interface IGasPriceOracle { // OP Stack: 0x420...000F
    function getL1Fee(bytes memory data)      external view returns (uint256);
    function getL1GasUsed(bytes memory data)  external view returns (uint256);
    function l1BaseFee()                      external view returns (uint256);
    function baseFeeScalar()                  external view returns (uint32);
    function blobBaseFeeScalar()              external view returns (uint32);
}

interface IArbGasInfo { // Arbitrum: 0x...006C
    function getL1BaseFeeEstimate()           external view returns (uint256);
    function getMinimumGasPrice()             external view returns (uint256);
    function getPricesInWei()                 external view returns (
        uint256 gasPerL2Tx, uint256 gasPerL1CalldataByte,
        uint256 l1GasPriceEstimate, uint256 l2GasPrice,
        uint256 l1GasPrice, uint256 gasPriceInArbGas
    );
}

/// @title L2GasEstimator — utility to compute real L2 tx costs
contract L2GasEstimator {

    address constant OP_GAS_ORACLE = 0x420000000000000000000000000000000000000F;
    address constant ARB_GAS_INFO  = 0x000000000000000000000000000000000000006C;

    /// @notice Estimate total cost on OP Stack (execution + L1 data fee)
    function estimateCostOpStack(bytes calldata txData)
        external view returns (uint256 l1Fee, uint256 l2ExecutionFee, uint256 total)
    {
        l1Fee           = IGasPriceOracle(OP_GAS_ORACLE).getL1Fee(txData);
        l2ExecutionFee  = gasleft() * block.basefee; // approximate
        total           = l1Fee + l2ExecutionFee;
    }

    /// @notice Estimate L1 data fee on OP Stack for arbitrary calldata
    function getL1DataFeeOpStack(bytes calldata txData) external view returns (uint256) {
        return IGasPriceOracle(OP_GAS_ORACLE).getL1Fee(txData);
    }

    /// @notice Get current L1 base fee estimate on Arbitrum
    function getL1BaseFeeArbitrum() external view returns (uint256) {
        return IArbGasInfo(ARB_GAS_INFO).getL1BaseFeeEstimate();
    }
}

// ============================================================
// SECTION 4: CHAIN DETECTION & MULTI-CHAIN PATTERNS
// ============================================================

/*
 * CHAIN IDs (mainnet equivalents):
 *   Ethereum Mainnet:  1
 *   Optimism:          10
 *   Arbitrum One:      42161
 *   Arbitrum Nova:     42170
 *   Base:              8453
 *   Zora:              7777777
 *   zkSync Era:        324
 *   Polygon zkEVM:     1101
 *   Scroll:            534352
 *   Linea:             59144
 *   Polygon PoS:       137
 *   Avalanche C-Chain: 43114
 *   BNB Smart Chain:   56
 *   Gnosis Chain:      100
 *
 * TESTNETS:
 *   Sepolia:           11155111
 *   Optimism Sepolia:  11155420
 *   Arbitrum Sepolia:  421614
 *   Base Sepolia:      84532
 *   zkSync Sepolia:    300
 */

/// @title ChainRegistry — per-chain configuration with safe defaults
abstract contract ChainRegistry {

    uint256 constant MAINNET     = 1;
    uint256 constant OPTIMISM    = 10;
    uint256 constant ARBITRUM    = 42161;
    uint256 constant BASE        = 8453;
    uint256 constant ZKSYNC_ERA  = 324;
    uint256 constant POLYGON_ZKEVM = 1101;
    uint256 constant SCROLL      = 534352;

    struct ChainConfig {
        address wrappedNative;  // WETH on most chains
        address usdcAddress;
        address chainlinkEthUsd;
        bool    isL2;
        bool    hasEIP1559;
        uint32  blockTimeSeconds; // approximate
    }

    function getConfig() public view returns (ChainConfig memory cfg) {
        uint256 id = block.chainid;

        if (id == MAINNET) return ChainConfig({
            wrappedNative:    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            usdcAddress:      0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            chainlinkEthUsd:  0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            isL2:             false,
            hasEIP1559:       true,
            blockTimeSeconds: 12
        });

        if (id == OPTIMISM) return ChainConfig({
            wrappedNative:    0x4200000000000000000000000000000000000006,
            usdcAddress:      0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85,
            chainlinkEthUsd:  0x13e3Ee699D1909E989722E753853AE30b17e08c5,
            isL2:             true,
            hasEIP1559:       true,
            blockTimeSeconds: 2
        });

        if (id == ARBITRUM) return ChainConfig({
            wrappedNative:    0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            usdcAddress:      0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            chainlinkEthUsd:  0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            isL2:             true,
            hasEIP1559:       true,
            blockTimeSeconds: 0 // sub-second
        });

        if (id == BASE) return ChainConfig({
            wrappedNative:    0x4200000000000000000000000000000000000006,
            usdcAddress:      0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            chainlinkEthUsd:  0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
            isL2:             true,
            hasEIP1559:       true,
            blockTimeSeconds: 2
        });

        // Default fallback (testnets, unknown chains)
        return ChainConfig({
            wrappedNative:    address(0),
            usdcAddress:      address(0),
            chainlinkEthUsd:  address(0),
            isL2:             true,
            hasEIP1559:       true,
            blockTimeSeconds: 2
        });
    }

    modifier onlyL2() {
        require(getConfig().isL2, "Not an L2");
        _;
    }
}

// ============================================================
// SECTION 5: NATIVE BRIDGES — OP STACK (Optimism / Base)
// ============================================================

/*
 * OP STACK BRIDGE ARCHITECTURE:
 *
 *   L1StandardBridge  ←──────────────→  L2StandardBridge
 *   L1CrossDomainMessenger ←──────────→ L2CrossDomainMessenger
 *
 * L1 → L2 (deposits): ~1-3 minutes (included in next L2 block)
 * L2 → L1 (withdrawals): 7 days (fraud proof window)
 *
 * FAST WITHDRAWAL: Use a liquidity network (Across, Stargate)
 * that fronts the funds on L1 and is repaid after 7 days.
 *
 * IMPORTANT: When L1 contract sends a message to L2,
 * msg.sender on L2 is the L2 alias of the L1 contract,
 * NOT the original address. Use AddressAliasHelper to recover it.
 */

interface IL1CrossDomainMessenger {
    function sendMessage(
        address target,     // L2 contract to call
        bytes calldata message,
        uint32 gasLimit     // gas limit on L2 side
    ) external payable;

    function xDomainMessageSender() external view returns (address);
}

interface IL2CrossDomainMessenger {
    function sendMessage(
        address target,     // L1 contract to call
        bytes calldata message,
        uint32 gasLimit
    ) external;

    function xDomainMessageSender() external view returns (address);
}

interface IL1StandardBridge {
    function depositETH(uint32 minGasLimit, bytes calldata extraData) external payable;
    function depositERC20(
        address l1Token,
        address l2Token,
        uint256 amount,
        uint32  minGasLimit,
        bytes   calldata extraData
    ) external;
    function bridgeETHTo(address to, uint32 minGasLimit, bytes calldata extraData) external payable;
}

interface IL2StandardBridge {
    function withdraw(
        address l2Token,
        uint256 amount,
        uint32  minGasLimit,
        bytes   calldata extraData
    ) external;
    function withdrawTo(
        address l2Token,
        address to,
        uint256 amount,
        uint32  minGasLimit,
        bytes   calldata extraData
    ) external;
}

/// @title OPStackMessaging — example cross-domain contract pair
/// @dev Deploy L1Contract on mainnet, L2Contract on OP Stack chain

contract OPStackL1Contract {

    IL1CrossDomainMessenger public immutable messenger;
    address public immutable l2Contract; // counterpart on L2

    event MessageSentToL2(address indexed target, bytes message);

    constructor(address _messenger, address _l2Contract) {
        messenger   = IL1CrossDomainMessenger(_messenger);
        l2Contract  = _l2Contract;
    }

    /// @notice Send a message to the L2 counterpart
    function sendToL2(bytes calldata data, uint32 gasLimit) external payable {
        messenger.sendMessage{value: msg.value}(l2Contract, data, gasLimit);
        emit MessageSentToL2(l2Contract, data);
    }

    /// @notice Deposit ETH to L2 via native bridge
    function depositETH(uint32 gasLimit) external payable {
        IL1StandardBridge bridge = IL1StandardBridge(
            0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1 // Optimism L1 bridge
        );
        bridge.depositETH{value: msg.value}(gasLimit, "");
    }
}

contract OPStackL2Contract {

    IL2CrossDomainMessenger public immutable messenger;
    address public immutable l1Contract; // counterpart on L1

    error NotL1Contract();

    modifier onlyL1Contract() {
        require(msg.sender == address(messenger), "Not messenger");
        require(messenger.xDomainMessageSender() == l1Contract, "Not L1 contract");
        _;
    }

    constructor(address _messenger, address _l1Contract) {
        messenger  = IL2CrossDomainMessenger(_messenger);
        l1Contract = _l1Contract;
    }

    /// @notice Called by the messenger when L1 sends a message
    function receiveFromL1(address user, uint256 amount) external onlyL1Contract {
        // Process the cross-domain message
        // msg.sender here = L2CrossDomainMessenger
        // original sender = l1Contract (verified above)
        _processDeposit(user, amount);
    }

    /// @notice Initiate a withdrawal back to L1 (starts 7-day wait)
    function withdrawToL1(address l1Recipient, bytes calldata data) external {
        messenger.sendMessage(l1Contract, data, 100_000);
    }

    function _processDeposit(address user, uint256 amount) internal virtual {}
}

// ============================================================
// SECTION 6: NATIVE BRIDGES — ARBITRUM (NITRO)
// ============================================================

/*
 * ARBITRUM BRIDGE ARCHITECTURE:
 *
 *   Inbox (L1)  ←──── Retryable Tickets ────→  ArbOS (L2)
 *   Outbox (L1) ←──── Outbox Messages    ────→  ArbSys (L2 precompile)
 *
 * L1 → L2 (Retryable Tickets):
 *   - Message submitted to Inbox on L1
 *   - ArbOS automatically executes on L2 (~10 min)
 *   - If execution fails, ticket can be retried within 7 days
 *
 * L2 → L1 (Outbox):
 *   - Call ArbSys.sendTxToL1() on L2
 *   - ~7 days wait (challenge period)
 *   - Then execute the outbox message on L1
 *
 * INBOX ADDRESS (mainnet): 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f
 * ARBS YS ADDRESS (L2 precompile): 0x0000000000000000000000000000000000000064
 */

interface IInbox {
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256 ticketId);

    function calculateRetryableSubmissionFee(
        uint256 dataLength,
        uint256 baseFee
    ) external view returns (uint256);
}

interface IArbSys {
    /// @notice Initiate a withdrawal from L2 to L1
    function sendTxToL1(address destination, bytes calldata data)
        external payable returns (uint256 uniqueId);

    function arbBlockNumber() external view returns (uint256);
    function arbBlockHash(uint256 arbBlockNum) external view returns (bytes32);
}

/// @title ArbitrumMessaging — L1↔L2 messaging via Arbitrum Inbox/ArbSys
contract ArbitrumL1Sender {

    IInbox public immutable inbox;

    // Arbitrum mainnet Inbox
    address constant ARBITRUM_INBOX = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f;

    constructor() {
        inbox = IInbox(ARBITRUM_INBOX);
    }

    /// @notice Send a message to Arbitrum via Retryable Ticket
    /// @param l2Target    Contract on L2 to call
    /// @param l2CallData  Calldata for the L2 call
    /// @param gasLimit    Gas limit for L2 execution
    /// @param maxFeePerGas Current L2 gas price
    function sendToArbitrum(
        address l2Target,
        bytes calldata l2CallData,
        uint256 gasLimit,
        uint256 maxFeePerGas
    ) external payable returns (uint256 ticketId) {
        uint256 submissionCost = inbox.calculateRetryableSubmissionFee(
            l2CallData.length,
            block.basefee
        );

        ticketId = inbox.createRetryableTicket{value: msg.value}(
            l2Target,
            0,                  // l2CallValue (ETH to send with the call)
            submissionCost,
            msg.sender,         // refund address for excess ETH
            msg.sender,         // refund address for call value
            gasLimit,
            maxFeePerGas,
            l2CallData
        );
    }
}

contract ArbitrumL2Receiver {

    IArbSys constant ARBSYS = IArbSys(0x0000000000000000000000000000000000000064);

    address public immutable l1Sender;
    address public immutable l1Bridge; // Arbitrum's L1 bridge contract

    modifier onlyFromL1() {
        // On Arbitrum, messages from L1 arrive via the bridge
        // msg.sender will be the aliased L1 contract address
        address expectedAlias = AddressAliasHelper.applyL1ToL2Alias(l1Sender);
        require(msg.sender == expectedAlias, "Not L1 sender");
        _;
    }

    constructor(address _l1Sender, address _l1Bridge) {
        l1Sender  = _l1Sender;
        l1Bridge  = _l1Bridge;
    }

    /// @notice Called automatically when retryable ticket is executed
    function receiveFromL1(bytes calldata data) external onlyFromL1 {
        // Process the message from L1
        _handleMessage(data);
    }

    /// @notice Send a message back to L1 (initiates 7-day withdrawal)
    function sendToL1(address l1Target, bytes calldata data) external payable {
        ARBSYS.sendTxToL1{value: msg.value}(l1Target, data);
    }

    /// @notice Arbitrum's block number (much higher than L1 block number)
    function getArbBlockNumber() external view returns (uint256) {
        return ARBSYS.arbBlockNumber();
    }

    function _handleMessage(bytes calldata data) internal virtual {}
}

// ============================================================
// SECTION 7: CHAINLINK CCIP — CROSS-CHAIN MESSAGING
// ============================================================

/*
 * CCIP (Cross-Chain Interoperability Protocol) by Chainlink:
 * - Decentralized oracle network validates cross-chain messages
 * - Supports token transfers + arbitrary message passing
 * - Risk Management Network: separate monitoring layer
 * - Defense-in-depth: rate limits, circuit breakers
 *
 * SUPPORTED LANES (subset):
 * Ethereum ↔ Optimism, Arbitrum, Base, Polygon, Avalanche, BNB
 *
 * FEES: paid in LINK or native token (ETH/MATIC)
 *
 * INSTALL: forge install smartcontractkit/ccip
 */

interface IRouterClient {
    struct EVM2AnyMessage {
        bytes    receiver;        // abi.encode(address) on EVM chains
        bytes    data;            // arbitrary message
        TokenAmount[] tokenAmounts;
        address  feeToken;        // address(0) = pay in native (ETH)
        bytes    extraArgs;       // Client.EVMExtraArgsV1({gasLimit: N})
    }

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    function getFee(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external view returns (uint256 fee);

    function ccipSend(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external payable returns (bytes32 messageId);

    function isChainSupported(uint64 chainSelector) external view returns (bool);
}

interface IAny2EVMMessageReceiver {
    struct Any2EVMMessage {
        bytes32  messageId;
        uint64   sourceChainSelector;
        bytes    sender;           // abi.encode(address) of source contract
        bytes    data;
        IRouterClient.TokenAmount[] destTokenAmounts;
    }

    function ccipReceive(Any2EVMMessage calldata message) external;
}

/// @title CCIPBase — abstract base for CCIP sender/receiver contracts
abstract contract CCIPBase is IAny2EVMMessageReceiver {

    IRouterClient public immutable router;

    // Chainlink chain selectors
    uint64 constant ETHEREUM_SELECTOR  = 5009297550715157269;
    uint64 constant OPTIMISM_SELECTOR  = 3734403246176062136;
    uint64 constant ARBITRUM_SELECTOR  = 4949039107694359620;
    uint64 constant BASE_SELECTOR      = 15971525489660198786;
    uint64 constant POLYGON_SELECTOR   = 4051577828743386545;
    uint64 constant AVALANCHE_SELECTOR = 6433500567565415381;

    mapping(uint64 => address) public allowedSenders;  // chainSelector → trusted contract
    mapping(uint64 => bool)    public allowedChains;

    error NotRouter();
    error ChainNotAllowed(uint64 selector);
    error SenderNotAllowed(address sender);

    constructor(address _router) {
        router = IRouterClient(_router);
    }

    modifier onlyRouter() {
        if (msg.sender != address(router)) revert NotRouter();
        _;
    }

    modifier onlyAllowedChain(uint64 sourceChain) {
        if (!allowedChains[sourceChain]) revert ChainNotAllowed(sourceChain);
        _;
    }

    function ccipReceive(IAny2EVMMessageReceiver.Any2EVMMessage calldata message)
        external override onlyRouter
    {
        address sender = abi.decode(message.sender, (address));
        if (sender != allowedSenders[message.sourceChainSelector])
            revert SenderNotAllowed(sender);

        _ccipReceive(message);
    }

    function _ccipReceive(IAny2EVMMessageReceiver.Any2EVMMessage calldata message)
        internal virtual;

    function _sendMessage(
        uint64  destinationChainSelector,
        address receiver,
        bytes   memory data,
        uint256 gasLimit
    ) internal returns (bytes32 messageId) {
        IRouterClient.EVM2AnyMessage memory message = IRouterClient.EVM2AnyMessage({
            receiver:     abi.encode(receiver),
            data:         data,
            tokenAmounts: new IRouterClient.TokenAmount[](0),
            feeToken:     address(0), // pay in native ETH
            extraArgs:    abi.encode(gasLimit)
        });

        uint256 fee = router.getFee(destinationChainSelector, message);

        messageId = router.ccipSend{value: fee}(destinationChainSelector, message);
    }

    receive() external payable {}
}

/// @title CCIPTokenBridge — cross-chain token transfer via CCIP
contract CCIPTokenBridge is CCIPBase {

    address public immutable token; // local ERC20 token
    mapping(bytes32 => bool) public processedMessages;

    event TokensSent(bytes32 indexed messageId, uint64 destChain, address recipient, uint256 amount);
    event TokensReceived(bytes32 indexed messageId, uint64 srcChain, address recipient, uint256 amount);

    constructor(address _router, address _token) CCIPBase(_router) {
        token = _token;
    }

    /// @notice Lock tokens here, mint equivalent on destination chain
    function sendTokens(
        uint64  destinationChain,
        address recipient,
        uint256 amount,
        uint256 gasLimit
    ) external payable returns (bytes32 messageId) {
        require(allowedChains[destinationChain], "Chain not supported");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        bytes memory data = abi.encode(recipient, amount);
        messageId = _sendMessage(destinationChain, allowedSenders[destinationChain], data, gasLimit);

        emit TokensSent(messageId, destinationChain, recipient, amount);
    }

    function _ccipReceive(IAny2EVMMessageReceiver.Any2EVMMessage calldata message)
        internal override
    {
        require(!processedMessages[message.messageId], "Already processed");
        processedMessages[message.messageId] = true;

        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));

        // Mint on destination (or unlock if locked on this side)
        IERC20Mintable(token).mint(recipient, amount);

        emit TokensReceived(message.messageId, message.sourceChainSelector, recipient, amount);
    }
}

// ============================================================
// SECTION 8: LAYERZERO V2 — OMNICHAIN MESSAGING
// ============================================================

/*
 * LayerZero V2 architecture:
 * - Decentralized Verifier Networks (DVNs) confirm messages
 * - Executor delivers the message on destination
 * - Configurable security: choose your own DVNs
 * - OFT (Omnichain Fungible Token) standard built on top
 *
 * INSTALL: forge install LayerZero-Labs/LayerZero-v2
 */

interface ILayerZeroEndpointV2 {
    struct MessagingParams {
        uint32  dstEid;        // destination endpoint ID
        bytes32 receiver;      // recipient address as bytes32
        bytes   message;       // payload
        bytes   options;       // executor options (gas limit, value)
        bool    payInLzToken;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    function quote(MessagingParams calldata params, address sender)
        external view returns (MessagingFee memory fee);

    function send(MessagingParams calldata params, address refundAddress)
        external payable returns (bytes32 guid, uint64 nonce, MessagingFee memory fee);
}

interface ILayerZeroReceiver {
    function lzReceive(
        uint32  srcEid,
        bytes32 sender,
        uint64  nonce,
        bytes32 guid,
        bytes   calldata message,
        bytes   calldata extraData
    ) external payable;
}

/// @title LZBase — abstract base for LayerZero V2 omnichain contracts
abstract contract LZBase is ILayerZeroReceiver {

    ILayerZeroEndpointV2 public immutable endpoint;
    address public immutable owner;

    // LayerZero endpoint IDs
    uint32 constant EID_ETHEREUM  = 30101;
    uint32 constant EID_OPTIMISM  = 30111;
    uint32 constant EID_ARBITRUM  = 30110;
    uint32 constant EID_BASE      = 30184;
    uint32 constant EID_POLYGON   = 30109;
    uint32 constant EID_AVALANCHE = 30106;
    uint32 constant EID_BSC       = 30102;

    mapping(uint32 => bytes32) public peers; // eid → trusted remote contract

    error NotEndpoint();
    error NotPeer(uint32 srcEid, bytes32 sender);

    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
        owner    = msg.sender;
    }

    function setPeer(uint32 eid, bytes32 peer) external {
        require(msg.sender == owner);
        peers[eid] = peer;
    }

    function lzReceive(
        uint32  srcEid,
        bytes32 sender,
        uint64, /*nonce*/
        bytes32, /*guid*/
        bytes   calldata message,
        bytes   calldata /*extraData*/
    ) external payable override {
        if (msg.sender != address(endpoint))      revert NotEndpoint();
        if (peers[srcEid] != sender)              revert NotPeer(srcEid, sender);
        _lzReceive(srcEid, sender, message);
    }

    function _lzReceive(uint32 srcEid, bytes32 sender, bytes calldata message)
        internal virtual;

    function _lzSend(
        uint32 dstEid,
        bytes memory message,
        uint128 gasLimit,
        uint128 value        // native token to send with message
    ) internal returns (bytes32 guid) {
        bytes memory options = _buildOptions(gasLimit, value);

        ILayerZeroEndpointV2.MessagingParams memory params = ILayerZeroEndpointV2.MessagingParams({
            dstEid:       dstEid,
            receiver:     peers[dstEid],
            message:      message,
            options:      options,
            payInLzToken: false
        });

        ILayerZeroEndpointV2.MessagingFee memory fee =
            endpoint.quote(params, address(this));

        (guid,,) = endpoint.send{value: fee.nativeFee}(params, address(this));
    }

    function quoteFee(uint32 dstEid, bytes memory message, uint128 gasLimit)
        external view returns (uint256 nativeFee)
    {
        bytes memory options = _buildOptions(gasLimit, 0);
        ILayerZeroEndpointV2.MessagingParams memory params = ILayerZeroEndpointV2.MessagingParams({
            dstEid:       dstEid,
            receiver:     peers[dstEid],
            message:      message,
            options:      options,
            payInLzToken: false
        });
        nativeFee = endpoint.quote(params, address(this)).nativeFee;
    }

    /// @notice Build executor options: TYPE_3 = lzReceive gas + native drop
    function _buildOptions(uint128 gasLimit, uint128 nativeDrop)
        internal pure returns (bytes memory)
    {
        // Options encoding: type(2 bytes) | lzReceive(16 gas + 16 value) | nativeDrop(16 value + 32 receiver)
        return abi.encodePacked(
            uint16(3),       // TYPE_3
            uint8(1),        // OPTION_TYPE_LZRECEIVE
            uint16(32),      // option length
            gasLimit,
            nativeDrop
        );
    }

    receive() external payable {}
}

// ============================================================
// SECTION 9: HYPERLANE — PERMISSIONLESS MESSAGING
// ============================================================

/*
 * Hyperlane is unique: anyone can deploy it on any chain.
 * No permission required from any central authority.
 *
 * ARCHITECTURE:
 * - Mailbox: core contract, send/receive messages
 * - ISM (Interchain Security Module): pluggable validation
 *   choices: multisig, aggregation, routing, optimistic
 * - Interchain Gas Paymaster: pay for destination gas on source
 *
 * INSTALL: forge install hyperlane-xyz/hyperlane-monorepo
 */

interface IMailbox {
    function dispatch(
        uint32  destinationDomain,
        bytes32 recipientAddress,
        bytes   calldata messageBody
    ) external payable returns (bytes32 messageId);

    function quoteDispatch(
        uint32  destinationDomain,
        bytes32 recipientAddress,
        bytes   calldata messageBody
    ) external view returns (uint256 fee);

    function process(bytes calldata metadata, bytes calldata message) external;
}

interface IMessageRecipient {
    function handle(
        uint32  origin,
        bytes32 sender,
        bytes   calldata message
    ) external payable;
}

/// @title HyperlaneMessenger — omnichain messaging using Hyperlane
contract HyperlaneMessenger is IMessageRecipient {

    IMailbox public immutable mailbox;

    // Hyperlane domain IDs
    uint32 constant DOMAIN_ETHEREUM = 1;
    uint32 constant DOMAIN_OPTIMISM = 10;
    uint32 constant DOMAIN_ARBITRUM = 42161;
    uint32 constant DOMAIN_BASE     = 8453;

    mapping(uint32 => bytes32) public trustedSenders;

    event MessageSent(uint32 indexed destDomain, bytes32 indexed recipient, bytes32 messageId);
    event MessageReceived(uint32 indexed origin, bytes32 indexed sender, bytes message);

    error NotMailbox();
    error UntrustedSender(uint32 origin, bytes32 sender);

    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }

    function setTrustedSender(uint32 domain, bytes32 sender) external {
        trustedSenders[domain] = sender;
    }

    function sendMessage(
        uint32 destDomain,
        address recipient,
        bytes calldata data
    ) external payable returns (bytes32 messageId) {
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));
        uint256 fee = mailbox.quoteDispatch(destDomain, recipientBytes32, data);
        require(msg.value >= fee, "Insufficient fee");

        messageId = mailbox.dispatch{value: fee}(destDomain, recipientBytes32, data);
        emit MessageSent(destDomain, recipientBytes32, messageId);
    }

    function handle(
        uint32  origin,
        bytes32 sender,
        bytes   calldata message
    ) external payable override {
        require(msg.sender == address(mailbox), "Not mailbox");
        if (trustedSenders[origin] != bytes32(0) && trustedSenders[origin] != sender)
            revert UntrustedSender(origin, sender);

        _handleMessage(origin, sender, message);
        emit MessageReceived(origin, sender, message);
    }

    function _handleMessage(uint32 origin, bytes32 sender, bytes calldata message)
        internal virtual {}
}

// ============================================================
// SECTION 10: CROSS-CHAIN TOKEN STANDARDS
// ============================================================

/*
 * OFT (Omnichain Fungible Token) — LayerZero standard:
 * - Single token canonical across all chains
 * - Send = lock on source + mint on destination (or burn/mint)
 * - No wrapped tokens, no liquidity fragmentation
 * - Inherits ERC-20, adds send() and lzReceive() logic
 *
 * xERC20 (ERC-7281) — permissionless bridge standard:
 * - Token issuer sets per-bridge mint/burn rate limits
 * - Any bridge can be authorized independently
 * - Prevents one compromised bridge from draining entire supply
 * - Adopted by: Connext, Axelar, some CCIP routes
 */

interface IXERC20 {
    /// @notice Set mint/burn limits for a specific bridge
    function setLimits(
        address bridge,
        uint256 mintingLimit,   // max tokens bridge can mint per day
        uint256 burningLimit    // max tokens bridge can burn per day
    ) external;

    function mint(address user, uint256 amount) external;
    function burn(address user, uint256 amount) external;
    function mintingMaxLimitOf(address bridge)  external view returns (uint256);
    function burningMaxLimitOf(address bridge)  external view returns (uint256);
    function mintingCurrentLimitOf(address bridge) external view returns (uint256);
    function burningCurrentLimitOf(address bridge) external view returns (uint256);
}

/// @title xERC20Token — rate-limited cross-chain token
contract xERC20Token {

    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;
    uint256 public totalSupply;
    address public immutable owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct BridgeLimits {
        uint256 maxMint;     // max per day
        uint256 maxBurn;     // max per day
        uint256 mintedToday;
        uint256 burnedToday;
        uint256 dayStart;    // timestamp of current day window
    }

    mapping(address => BridgeLimits) public bridgeLimits;

    error BridgeNotAuthorized();
    error MintLimitExceeded(uint256 requested, uint256 remaining);
    error BurnLimitExceeded(uint256 requested, uint256 remaining);
    error NotOwner();

    event BridgeLimitsSet(address indexed bridge, uint256 mintLimit, uint256 burnLimit);

    constructor(string memory _name, string memory _symbol) {
        name   = _name;
        symbol = _symbol;
        owner  = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Authorize a bridge with daily rate limits
    function setLimits(address bridge, uint256 mintLimit, uint256 burnLimit) external onlyOwner {
        bridgeLimits[bridge].maxMint = mintLimit;
        bridgeLimits[bridge].maxBurn = burnLimit;
        emit BridgeLimitsSet(bridge, mintLimit, burnLimit);
    }

    /// @notice Bridge mints tokens on destination chain
    function mint(address to, uint256 amount) external {
        BridgeLimits storage limits = bridgeLimits[msg.sender];
        require(limits.maxMint > 0, "Bridge not authorized");

        _resetDailyLimitsIfNeeded(limits);

        uint256 remaining = limits.maxMint - limits.mintedToday;
        if (amount > remaining) revert MintLimitExceeded(amount, remaining);

        limits.mintedToday += amount;
        balanceOf[to]      += amount;
        totalSupply        += amount;
    }

    /// @notice Bridge burns tokens on source chain (before sending)
    function burn(address from, uint256 amount) external {
        BridgeLimits storage limits = bridgeLimits[msg.sender];
        require(limits.maxBurn > 0, "Bridge not authorized");

        _resetDailyLimitsIfNeeded(limits);

        uint256 remaining = limits.maxBurn - limits.burnedToday;
        if (amount > remaining) revert BurnLimitExceeded(amount, remaining);

        limits.burnedToday += amount;
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply     -= amount;
    }

    function _resetDailyLimitsIfNeeded(BridgeLimits storage limits) private {
        if (block.timestamp >= limits.dayStart + 1 days) {
            limits.mintedToday = 0;
            limits.burnedToday = 0;
            limits.dayStart    = block.timestamp;
        }
    }
}

// ============================================================
// SECTION 11: ZKSYNC ERA SPECIFICS
// ============================================================

/*
 * zkSync Era differences from mainnet (important for auditors):
 *
 * 1. ACCOUNT ABSTRACTION IS NATIVE:
 *    Every account CAN be a smart account (no ERC-4337 needed)
 *    IAccount interface is part of the protocol
 *
 * 2. SYSTEM CONTRACTS (special addresses):
 *    0x0000...0001 = Bootloader
 *    0x0000...0002 = AccountCodeStorage
 *    0x0000...0006 = NonceHolder
 *    0x0000...0008 = ContractDeployer
 *    0x0000...000A = L1Messenger
 *    0x0000...000B = MsgValueSimulator
 *
 * 3. DEPLOYING CONTRACTS:
 *    Must go through ContractDeployer system contract
 *    ContractFactory pattern works differently
 *    Use the zkSync SDK for accurate CREATE2 address prediction
 *
 * 4. msg.sender IN CONSTRUCTORS:
 *    In zkSync, msg.sender inside a constructor = ContractDeployer
 *    (not the EOA that called the deployment)
 *
 * 5. PAYMASTER (native):
 *    No need for ERC-4337 infrastructure — just implement IPaymaster
 *
 * 6. GAS TOKENS:
 *    Gas is always paid in ETH (even on zkSync)
 *    Paymasters can accept any ERC-20 but internally pay ETH
 */

interface IZkSyncPaymaster {
    enum ExecutionResult { Revert, Success }

    struct Transaction {
        uint256 txType;
        uint256 from;
        uint256 to;
        uint256 gasLimit;
        uint256 gasPerPubdataByteLimit;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        uint256 paymaster;
        uint256 nonce;
        uint256 value;
        uint256[4] reserved;
        bytes   data;
        bytes   signature;
        bytes32[] factoryDeps;
        bytes   paymasterInput;
        bytes   reservedDynamic;
    }

    function validateAndPayForPaymasterTransaction(
        bytes32 txHash,
        bytes32 suggestedSignedHash,
        Transaction calldata transaction
    ) external payable returns (bytes4 magic, bytes memory context);

    function postTransaction(
        bytes   calldata context,
        Transaction calldata transaction,
        bytes32 txHash,
        bytes32 suggestedSignedHash,
        ExecutionResult txResult,
        uint256 maxRefundedGas
    ) external payable;
}

/// @notice Minimal Chainlink price-feed interface used to convert token <> ETH.
interface ChainlinkOracle {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/// @title zkSyncERC20Paymaster — pay gas in any ERC-20 on zkSync Era
contract zkSyncERC20Paymaster is IZkSyncPaymaster {

    address public immutable allowedToken;      // ERC-20 accepted for gas
    address public immutable tokenPriceFeed;    // Chainlink feed for token price
    ChainlinkOracle public immutable oracle;

    // Magic value returned on successful validation
    bytes4 constant PAYMASTER_VALIDATION_SUCCESS = 0x8c5a3444;
    // zkSync's bootloader address
    address constant BOOTLOADER = 0x0000000000000000000000000000000000008001;

    uint256 constant TOKEN_TO_ETH_RATIO = 1000; // 1000 token = 1 ETH (use oracle in prod)

    error NotBootloader();
    error UnsupportedFlow();
    error InsufficientTokenAllowance();

    constructor(address _token, address _feed, address _oracle) {
        allowedToken   = _token;
        tokenPriceFeed = _feed;
        oracle         = ChainlinkOracle(_oracle);
    }

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER, "Not bootloader");
        _;
    }

    function validateAndPayForPaymasterTransaction(
        bytes32, /*txHash*/
        bytes32, /*suggestedSignedHash*/
        Transaction calldata transaction
    ) external payable override onlyBootloader returns (bytes4 magic, bytes memory context) {
        // Only support Approval-based paymaster flow
        require(transaction.paymasterInput.length >= 4, "Short paymasterInput");

        bytes4 selector = bytes4(transaction.paymasterInput[:4]);
        require(selector == 0x949431dc, "Unsupported flow"); // approvalBased selector

        // Decode the approval parameters from paymasterInput
        (address token, uint256 minAllowance,) =
            abi.decode(transaction.paymasterInput[4:], (address, uint256, bytes));

        require(token == allowedToken, "Wrong token");

        address user = address(uint160(transaction.from));
        uint256 allowanceAmount = IERC20(token).allowance(user, address(this));
        require(allowanceAmount >= minAllowance, "Insufficient allowance");

        // Calculate how many tokens cover the gas cost
        uint256 requiredETH    = transaction.maxFeePerGas * transaction.gasLimit;
        uint256 requiredTokens = (requiredETH * TOKEN_TO_ETH_RATIO) / 1e18;

        // Collect tokens from user
        IERC20(token).transferFrom(user, address(this), requiredTokens);

        // Pay ETH for gas to bootloader
        (bool ok,) = payable(BOOTLOADER).call{value: requiredETH}("");
        require(ok, "ETH transfer to bootloader failed");

        magic   = PAYMASTER_VALIDATION_SUCCESS;
        context = abi.encode(user, requiredTokens, requiredETH);
    }

    function postTransaction(
        bytes calldata context,
        Transaction calldata, /*transaction*/
        bytes32, /*txHash*/
        bytes32, /*suggestedSignedHash*/
        ExecutionResult txResult,
        uint256 maxRefundedGas
    ) external payable override onlyBootloader {
        // Optionally refund unused tokens if tx was cheaper than estimated
        if (txResult == ExecutionResult.Success && maxRefundedGas > 0) {
            (address user, uint256 chargedTokens, uint256 chargedETH) =
                abi.decode(context, (address, uint256, uint256));

            uint256 refundETH    = maxRefundedGas * block.basefee;
            uint256 refundTokens = (refundETH * chargedTokens) / chargedETH;

            if (refundTokens > 0 && IERC20(allowedToken).balanceOf(address(this)) >= refundTokens) {
                IERC20(allowedToken).transfer(user, refundTokens);
            }
        }
    }

    receive() external payable {}
}

// ============================================================
// SECTION 12: L2 SECURITY CONSIDERATIONS
// ============================================================

/*
 * SEQUENCER FAILURE / CENSORSHIP:
 * - If the sequencer goes down, no L2 txs are processed
 * - Users can force-include txs via L1 (slower, but censorship-resistant)
 * - OP Stack: DelayedInbox on L1
 * - Arbitrum: Inbox on L1 with ForceInclude mechanism
 * - Protocol design: never assume sequencer is always live
 *
 * CROSS-CHAIN MESSAGE REPLAY:
 * - A message that is valid on chain A might be replayed on chain B
 * - Always include chainId in message hash (or use chain-specific nonces)
 * - EIP-712 domain separator includes chainId automatically
 *
 * BRIDGE SECURITY MODEL:
 * - Native bridges: secured by L1 (most secure, slowest)
 * - Third-party bridges: trade security for speed
 *   Risk spectrum: liquidity network > oracle bridge > messaging protocol
 * - Never assume a bridged token has the same price as the original
 *   A bridge exploit can depeg the wrapped version instantly
 *
 * ADDRESS ALIASING:
 * - L1 contract addresses have a different address on L2
 * - Failing to account for aliasing is a common bug in bridge integrations
 * - Use AddressAliasHelper for OP Stack chains
 *
 * BLOCK REORGS ON L2:
 * - L2 soft confirmations can be reorganized until posted to L1
 * - Wait for L1 finalization before treating cross-chain value as final
 * - Exchanges and bridges that accept L2 deposits must account for this
 *
 * UPGRADE KEYS:
 * - Most L2s have admin keys that can upgrade system contracts
 * - Check the security council multisig before deploying high-value protocols
 * - Optimism: 2/2 multisig (Security Council + Foundation)
 * - Arbitrum: 12/12 Security Council for emergency, 9/12 for routine
 */

/// @title CrossChainReplayGuard — prevent message replay across chains
contract CrossChainReplayGuard {

    mapping(bytes32 => bool) public executed;

    error AlreadyExecuted(bytes32 messageHash);
    error WrongChain(uint256 expected, uint256 actual);

    /// @notice Execute a cross-chain action only once
    function executeOnce(
        uint256 sourceChainId,
        uint256 targetChainId,
        uint256 nonce,
        bytes calldata action
    ) external {
        // Verify this is the intended chain
        if (block.chainid != targetChainId)
            revert WrongChain(targetChainId, block.chainid);

        // Build a unique hash including all context
        bytes32 messageHash = keccak256(abi.encode(
            sourceChainId,
            targetChainId,
            nonce,
            action
        ));

        if (executed[messageHash]) revert AlreadyExecuted(messageHash);
        executed[messageHash] = true;

        // Process the action
        (bool ok,) = address(this).call(action);
        require(ok, "Action failed");
    }
}

// ============================================================
// SECTION 13: MULTI-CHAIN DEPLOYMENT PATTERNS
// ============================================================

/*
 * STRATEGY 1 — IDENTICAL CONTRACTS (CREATE2):
 * Deploy the same bytecode at the same address on every chain.
 * Use a shared salt. Works for contracts with no chain-specific logic.
 * Caveat: zkSync Era uses a different CREATE2 formula.
 *
 * STRATEGY 2 — CHAIN-AWARE CONTRACTS:
 * Single codebase, reads block.chainid at runtime to adapt.
 * Use ChainRegistry pattern (Section 4) to return correct addresses.
 *
 * STRATEGY 3 — HUB AND SPOKE:
 * Mainnet = canonical state hub.
 * L2s = spokes that sync state via bridging.
 * Example: governance on mainnet, execution on L2s.
 *
 * STRATEGY 4 — NATIVE PER-CHAIN:
 * Completely separate deployments, no cross-chain dependency.
 * Simplest but no composability.
 *
 * CANONICAL BRIDGE TOKEN vs WRAPPED TOKEN:
 * - Canonical: minted by the official bridge, no wrapping
 * - Wrapped:   locked on source, wrapped version on destination
 * - Prefer canonical bridges for tokens where the issuer controls the bridge
 *   (USDC native mint on Arbitrum, Base — not wrapped USDC)
 */

/// @title MultiChainToken — token with chain-aware behavior
contract MultiChainToken {

    string  public constant name   = "MultiToken";
    string  public constant symbol = "MTKN";
    uint8   public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public immutable owner;

    // Which chains can mint (true = spoke, false = hub that holds supply)
    mapping(uint256 => bool) public isSpokeChain;

    // On spoke chains: bridge is the only authorized minter
    mapping(uint256 => address) public authorizedBridge;

    constructor() {
        owner = msg.sender;

        // Configure chain roles
        isSpokeChain[10]    = true;  // Optimism is a spoke
        isSpokeChain[42161] = true;  // Arbitrum is a spoke
        isSpokeChain[8453]  = true;  // Base is a spoke
        isSpokeChain[1]     = false; // Mainnet is the hub
    }

    function configureChain(uint256 chainId, bool isSpoke, address bridge) external {
        require(msg.sender == owner);
        isSpokeChain[chainId]       = isSpoke;
        authorizedBridge[chainId]   = bridge;
    }

    function mint(address to, uint256 amount) external {
        if (isSpokeChain[block.chainid]) {
            // On spokes, only the authorized bridge can mint
            require(msg.sender == authorizedBridge[block.chainid], "Not bridge");
        } else {
            // On hub (mainnet), only owner can mint
            require(msg.sender == owner, "Not owner");
        }
        balanceOf[to] += amount;
        totalSupply   += amount;
    }

    function burn(address from, uint256 amount) external {
        if (isSpokeChain[block.chainid]) {
            require(msg.sender == authorizedBridge[block.chainid], "Not bridge");
        } else {
            require(msg.sender == from || allowance[from][msg.sender] >= amount);
        }
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply     -= amount;
    }
}

// ============================================================
// SECTION 14: L2 DEVELOPER CHECKLIST
// ============================================================

/*
 * PRE-DEPLOYMENT AUDIT (run for every L2 target)
 *
 * OPCODE & BEHAVIOR
 * [ ] block.number usage replaced with block.timestamp for time logic
 * [ ] block.prevrandao / block.difficulty not used for randomness
 * [ ] SELFDESTRUCT replaced with explicit withdrawal pattern (for zkSync)
 * [ ] CREATE2 address prediction uses chain-specific formula (zkSync)
 * [ ] msg.sender in constructors handled for zkSync (= ContractDeployer)
 * [ ] tx.gasprice not used as security mechanism
 *
 * CROSS-CHAIN MESSAGING
 * [ ] msg.sender validated via bridge API (not directly)
 * [ ] Address aliasing handled (OP Stack: +0x1111...1111)
 * [ ] chainId included in all cross-chain message hashes
 * [ ] Nonces or message IDs prevent replay attacks
 * [ ] Trusted sender whitelist per source chain
 * [ ] Fallback for message failure (retry or refund mechanism)
 *
 * BRIDGE SECURITY
 * [ ] Distinguishing native bridge vs third-party bridge tokens
 * [ ] Rate limits on bridge minting (xERC20 pattern)
 * [ ] Not assuming bridged asset price = canonical asset price
 * [ ] Withdrawal delay accounted for in protocol design
 *
 * GAS
 * [ ] L1 data fee considered in user-facing gas estimates
 * [ ] Calldata minimized (each byte costs L1 fee)
 * [ ] Blobs (EIP-4844) used where available for data posting
 * [ ] Gas estimation tested on target L2 (not just mainnet fork)
 *
 * SEQUENCER RISK
 * [ ] Protocol can handle sequencer downtime gracefully
 * [ ] Force-inclusion path documented for users
 * [ ] No funds permanently locked if sequencer is censoring
 *
 * FINALITY
 * [ ] Distinguish between L2 soft confirmation and L1 finalization
 * [ ] High-value transfers wait for L1 finalization
 * [ ] Fraud proof window (7 days) accounted for in withdrawal UX
 *
 * TESTING
 * [ ] Tests run on actual L2 fork (not just mainnet fork)
 * [ ] Cross-chain message tests use mocked bridge or local test setup
 * [ ] Gas tests reflect L2 pricing model (include L1 data fee)
 * [ ] Sequencer downtime scenario tested
 */

// ============================================================
// MINIMAL INTERFACES (used across sections)
// ============================================================

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
