// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ============================================================
//  DEPLOY.SOL - Foundry Scripting & Deployment: Complete Reference
// ============================================================
//
//  This file covers professional deployment workflows using
//  Foundry Script. In a real project, scripts live in script/
//  with the *.s.sol extension.
//
//  ESSENTIAL COMMANDS:
//  forge script script/Deploy.s.sol                    Dry run (no broadcast)
//  forge script script/Deploy.s.sol --broadcast        Broadcast transactions
//  forge script script/Deploy.s.sol --broadcast \
//    --verify                                          Broadcast + verify on Etherscan
//  forge script script/Deploy.s.sol --broadcast \
//    --verify --resume                                 Resume a failed verification
//
//  SIMULATION (no wallet required):
//  forge script script/Deploy.s.sol --rpc-url $RPC_URL
//
//  LIVE DEPLOY (requires wallet):
//  forge script script/Deploy.s.sol \
//    --rpc-url $RPC_URL \
//    --private-key $PRIVATE_KEY \
//    --broadcast \
//    --verify \
//    --etherscan-api-key $ETHERSCAN_API_KEY
//
//  HARDWARE WALLET (Ledger/Trezor):
//  forge script script/Deploy.s.sol --ledger --broadcast
//
//  KEYSTORE FILE:
//  forge script script/Deploy.s.sol \
//    --keystore ~/.foundry/keystores/deployer \
//    --broadcast
//
//  ENVIRONMENT (.env):
//  source .env && forge script script/Deploy.s.sol \
//    --rpc-url $MAINNET_RPC_URL --broadcast --verify
//
// ============================================================

// ---------------------------------------------------------------------------
// IMPORTS (in a real .s.sol file)
// ---------------------------------------------------------------------------
// import {Script, console} from "forge-std/Script.sol";
// import {ERC20Token}       from "../src/Standards.sol";
// import {ERC721Token}      from "../src/Standards.sol";
// import {ERC1155Token}     from "../src/Standards.sol";
// import {Factory}          from "../src/Patterns.sol";
// import {SimpleProxy}      from "../src/Patterns.sol";
// import {SimpleSmartAccount, SimplePaymaster} from "../src/Testing.sol";

// ============================================================
// SECTION 1: FOUNDRY SCRIPT FUNDAMENTALS
// ============================================================

/*
 * A Script contract inherits from Script (forge-std).
 * The entry point is run() — Foundry calls it automatically.
 *
 * KEY CONCEPTS:
 * - vm.startBroadcast() / vm.stopBroadcast()
 *     Everything between these calls is sent as real transactions.
 *     Outside broadcast, calls are simulations (free).
 * - vm.broadcast()
 *     Broadcasts only the very next call.
 * - Returned contract addresses are logged automatically.
 * - Scripts run sequentially; use separate scripts for parallelism.
 */

// contract DeployBasic is Script {
//
//     function run() external returns (ERC20Token token) {
//         // Read deployer key from environment
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//         address deployer    = vm.addr(deployerKey);
//
//         console.log("Deployer:", deployer);
//         console.log("Balance: ", deployer.balance);
//         console.log("Chain ID:", block.chainid);
//
//         vm.startBroadcast(deployerKey);
//
//         token = new ERC20Token("MyToken", "MTK", 1_000_000e18);
//
//         vm.stopBroadcast();
//
//         console.log("ERC20Token deployed at:", address(token));
//         console.log("Total supply:", token.totalSupply());
//     }
// }

// ============================================================
// SECTION 2: CONFIGURATION — PER-NETWORK DEPLOYMENT CONFIG
// ============================================================

/*
 * A dedicated Config contract centralizes all deployment parameters.
 * This keeps scripts clean and makes multi-chain deployments trivial.
 *
 * Pattern: read from JSON file or environment variables,
 * fall back to sensible defaults for local/test environments.
 */

// struct NetworkConfig {
//     string  tokenName;
//     string  tokenSymbol;
//     uint256 initialSupply;
//     address owner;
//     uint256 deployerKey;
// }

// contract DeployConfig is Script {
//
//     uint256 constant MAINNET  = 1;
//     uint256 constant SEPOLIA  = 11155111;
//     uint256 constant ARBITRUM = 42161;
//     uint256 constant BASE     = 8453;
//     uint256 constant LOCAL    = 31337; // Anvil / forge test
//
//     // Default Anvil test key — never use on mainnet
//     uint256 constant ANVIL_KEY =
//         0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
//
//     function getConfig() public view returns (NetworkConfig memory) {
//         if (block.chainid == MAINNET)  return _mainnetConfig();
//         if (block.chainid == SEPOLIA)  return _sepoliaConfig();
//         if (block.chainid == ARBITRUM) return _arbitrumConfig();
//         if (block.chainid == BASE)     return _baseConfig();
//         return _localConfig(); // default: Anvil
//     }
//
//     function _mainnetConfig() internal view returns (NetworkConfig memory) {
//         return NetworkConfig({
//             tokenName:     "MyToken",
//             tokenSymbol:   "MTK",
//             initialSupply: 100_000_000e18,
//             owner:         vm.envAddress("MAINNET_OWNER"),
//             deployerKey:   vm.envUint("MAINNET_PRIVATE_KEY")
//         });
//     }
//
//     function _sepoliaConfig() internal view returns (NetworkConfig memory) {
//         return NetworkConfig({
//             tokenName:     "MyToken Testnet",
//             tokenSymbol:   "MTK-TEST",
//             initialSupply: 1_000_000e18,
//             owner:         vm.envAddress("TESTNET_OWNER"),
//             deployerKey:   vm.envUint("TESTNET_PRIVATE_KEY")
//         });
//     }
//
//     function _arbitrumConfig() internal view returns (NetworkConfig memory) {
//         return NetworkConfig({
//             tokenName:     "MyToken",
//             tokenSymbol:   "MTK",
//             initialSupply: 100_000_000e18,
//             owner:         vm.envAddress("ARB_OWNER"),
//             deployerKey:   vm.envUint("ARB_PRIVATE_KEY")
//         });
//     }
//
//     function _baseConfig() internal view returns (NetworkConfig memory) {
//         return NetworkConfig({
//             tokenName:     "MyToken",
//             tokenSymbol:   "MTK",
//             initialSupply: 100_000_000e18,
//             owner:         vm.envAddress("BASE_OWNER"),
//             deployerKey:   vm.envUint("BASE_PRIVATE_KEY")
//         });
//     }
//
//     function _localConfig() internal pure returns (NetworkConfig memory) {
//         return NetworkConfig({
//             tokenName:     "TestToken",
//             tokenSymbol:   "TTK",
//             initialSupply: 1_000_000e18,
//             owner:         vm.addr(ANVIL_KEY),
//             deployerKey:   ANVIL_KEY
//         });
//     }
// }

// ============================================================
// SECTION 3: MULTI-CONTRACT DEPLOYMENT SCRIPT
// ============================================================

/*
 * Most production projects deploy multiple interdependent contracts.
 * The pattern: deploy in dependency order, wire references, verify state.
 */

// contract DeployProtocol is Script {
//
//     // Emitted so CI/CD can grep the addresses from logs
//     event Deployed(string name, address addr);
//
//     struct Deployment {
//         ERC20Token    token;
//         Factory       factory;
//         SimplePaymaster paymaster;
//         SimpleSmartAccount accountImpl;
//     }
//
//     function run() external returns (Deployment memory d) {
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//         address deployer    = vm.addr(deployerKey);
//
//         _printDeploymentContext(deployer);
//
//         vm.startBroadcast(deployerKey);
//
//         // 1. Deploy core token
//         d.token = new ERC20Token("ProtocolToken", "PTKN", 500_000_000e18);
//         emit Deployed("ERC20Token", address(d.token));
//
//         // 2. Deploy factory (no dependencies)
//         d.factory = new Factory();
//         emit Deployed("Factory", address(d.factory));
//
//         // 3. Deploy ERC-4337 components
//         //    EntryPoint address varies per network — read from config
//         address entryPoint = _getEntryPoint();
//         d.accountImpl = new SimpleSmartAccount(entryPoint, deployer);
//         d.paymaster   = new SimplePaymaster(entryPoint);
//         emit Deployed("SmartAccountImpl", address(d.accountImpl));
//         emit Deployed("Paymaster",        address(d.paymaster));
//
//         // 4. Post-deploy configuration
//         d.token.transfer(address(d.factory), 10_000_000e18); // seed factory
//         d.paymaster.depositToEntryPoint{value: 0.1 ether}();  // fund paymaster
//
//         vm.stopBroadcast();
//
//         _printDeploymentSummary(d);
//         _saveDeploymentAddresses(d);
//     }
//
//     function _getEntryPoint() internal view returns (address) {
//         if (block.chainid == 1 || block.chainid == 11155111) {
//             return 0x0000000071727De22E5E9d8BAf0edAc6f37da032; // v0.7 mainnet/sepolia
//         }
//         if (block.chainid == 42161) {
//             return 0x0000000071727De22E5E9d8BAf0edAc6f37da032; // v0.7 arbitrum
//         }
//         return vm.envOr("ENTRY_POINT", address(0)); // local mock
//     }
//
//     function _printDeploymentContext(address deployer) internal view {
//         console.log("============================================");
//         console.log("Deployer:  ", deployer);
//         console.log("Balance:   ", deployer.balance / 1e18, "ETH");
//         console.log("Chain ID:  ", block.chainid);
//         console.log("Block:     ", block.number);
//         console.log("============================================");
//     }
//
//     function _printDeploymentSummary(Deployment memory d) internal pure {
//         console.log("\n=== DEPLOYMENT SUMMARY ===");
//         console.log("ERC20Token:      ", address(d.token));
//         console.log("Factory:         ", address(d.factory));
//         console.log("SmartAccountImpl:", address(d.accountImpl));
//         console.log("Paymaster:       ", address(d.paymaster));
//     }
//
//     // Saves addresses to a JSON file for frontend/other scripts to consume
//     function _saveDeploymentAddresses(Deployment memory d) internal {
//         string memory json = string.concat(
//             '{"chainId":', vm.toString(block.chainid), ',',
//             '"token":"',        vm.toString(address(d.token)),       '",',
//             '"factory":"',      vm.toString(address(d.factory)),     '",',
//             '"accountImpl":"',  vm.toString(address(d.accountImpl)), '",',
//             '"paymaster":"',    vm.toString(address(d.paymaster)),   '"}'
//         );
//         string memory path = string.concat(
//             "deployments/", vm.toString(block.chainid), ".json"
//         );
//         vm.writeFile(path, json);
//         console.log("Addresses saved to:", path);
//     }
// }

// ============================================================
// SECTION 4: DETERMINISTIC DEPLOYMENT WITH CREATE2
// ============================================================

/*
 * CREATE2 deploys a contract at a predictable address:
 *   address = keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))
 *
 * Use cases:
 * - Same address on every chain (cross-chain protocols)
 * - Pre-compute address before deployment (frontend can know the address in advance)
 * - Counterfactual deployment (ERC-4337 account creation)
 *
 * Foundry's `new Contract{salt: bytes32}(args)` uses CREATE2 automatically.
 */

// contract DeployDeterministic is Script {
//
//     // Shared salt — same salt = same address on every chain
//     bytes32 constant SALT = keccak256("myprotocol.v1.token");
//
//     function run() external {
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//
//         // Pre-compute address before deploying (no transaction needed)
//         address predicted = _predictAddress(SALT, "MyToken", "MTK", 1_000_000e18);
//         console.log("Predicted address:", predicted);
//
//         vm.startBroadcast(deployerKey);
//
//         // Deploy at deterministic address
//         ERC20Token token = new ERC20Token{salt: SALT}("MyToken", "MTK", 1_000_000e18);
//
//         vm.stopBroadcast();
//
//         // Verify prediction was correct
//         require(address(token) == predicted, "Address mismatch");
//         console.log("Deployed at predicted address:", address(token));
//     }
//
//     function _predictAddress(
//         bytes32 salt,
//         string memory name,
//         string memory symbol,
//         uint256 supply
//     ) internal view returns (address) {
//         bytes memory initCode = abi.encodePacked(
//             type(ERC20Token).creationCode,
//             abi.encode(name, symbol, supply)
//         );
//         bytes32 initCodeHash = keccak256(initCode);
//         return address(uint160(uint256(keccak256(abi.encodePacked(
//             bytes1(0xff),
//             address(this),        // deployer (the Script contract)
//             salt,
//             initCodeHash
//         )))));
//     }
// }

// ============================================================
// SECTION 5: UPGRADEABLE PROXY DEPLOYMENT (UUPS / Transparent)
// ============================================================

/*
 * Upgradeable contracts use a proxy pattern:
 *   Proxy ──delegatecall──> Implementation
 *
 * Storage lives in the Proxy, logic lives in the Implementation.
 * Upgrading = pointing the proxy to a new implementation.
 *
 * PATTERNS:
 * - Transparent Proxy (OpenZeppelin) — admin cannot call implementation
 * - UUPS (ERC-1822)                 — upgrade logic inside implementation
 * - Beacon Proxy                    — one beacon controls many proxies
 *
 * SECURITY WARNING: upgradeable contracts require extreme care.
 * - Never leave implementation uninitialized
 * - Use initializer instead of constructor
 * - Lock the implementation contract (call _disableInitializers)
 */

// contract TokenV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
//
//     string  public name;
//     string  public symbol;
//     uint256 public totalSupply;
//     mapping(address => uint256) public balanceOf;
//
//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() { _disableInitializers(); } // lock implementation
//
//     function initialize(
//         string memory _name,
//         string memory _symbol,
//         uint256 _supply,
//         address _owner
//     ) external initializer {
//         __Ownable_init(_owner);
//         __UUPSUpgradeable_init();
//         name        = _name;
//         symbol      = _symbol;
//         totalSupply = _supply;
//         balanceOf[_owner] = _supply;
//     }
//
//     // Required by UUPS — only owner can upgrade
//     function _authorizeUpgrade(address) internal override onlyOwner {}
// }

// contract DeployUpgradeable is Script {
//
//     function run() external returns (address proxy, address impl) {
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//         address deployer    = vm.addr(deployerKey);
//
//         vm.startBroadcast(deployerKey);
//
//         // 1. Deploy implementation (no constructor args — uses initializer)
//         TokenV1 implementation = new TokenV1();
//
//         // 2. Encode initializer call
//         bytes memory initData = abi.encodeCall(
//             TokenV1.initialize,
//             ("MyToken", "MTK", 1_000_000e18, deployer)
//         );
//
//         // 3. Deploy UUPS proxy wrapping the implementation
//         ERC1967Proxy proxyContract = new ERC1967Proxy(
//             address(implementation),
//             initData
//         );
//
//         vm.stopBroadcast();
//
//         proxy = address(proxyContract);
//         impl  = address(implementation);
//
//         console.log("Implementation:", impl);
//         console.log("Proxy:         ", proxy);
//
//         // Interact through proxy (all calls go via delegatecall)
//         TokenV1 token = TokenV1(proxy);
//         console.log("Token name:    ", token.name());
//         console.log("Total supply:  ", token.totalSupply());
//     }
// }

// contract DeployUpgradeV2 is Script {
//
//     function run() external {
//         address proxyAddress = vm.envAddress("PROXY_ADDRESS");
//         uint256 deployerKey  = vm.envUint("PRIVATE_KEY");
//
//         vm.startBroadcast(deployerKey);
//
//         // Deploy new implementation
//         TokenV2 newImpl = new TokenV2();
//
//         // Upgrade proxy to point to new implementation
//         TokenV1(proxyAddress).upgradeToAndCall(
//             address(newImpl),
//             abi.encodeCall(TokenV2.initializeV2, ("Extra state"))
//         );
//
//         vm.stopBroadcast();
//
//         console.log("Upgraded to V2:", address(newImpl));
//         console.log("Proxy unchanged:", proxyAddress);
//     }
// }

// ============================================================
// SECTION 6: VERIFICATION — ETHERSCAN AND ALTERNATIVES
// ============================================================

/*
 * AUTOMATIC VERIFICATION (recommended):
 * Add --verify and --etherscan-api-key to the deploy command.
 * Foundry handles the rest: uploads source, detects compiler settings, etc.
 *
 * MANUAL VERIFICATION:
 * forge verify-contract \
 *   --chain-id 1 \
 *   --compiler-version v0.8.24+commit.e11b9ed9 \
 *   --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "MyToken" "MTK" 1000000000000000000000000) \
 *   <CONTRACT_ADDRESS> \
 *   src/Standards.sol:ERC20Token \
 *   --etherscan-api-key $ETHERSCAN_API_KEY
 *
 * VERIFY ON ALTERNATIVE EXPLORERS:
 * Blockscout (no API key needed):
 * forge verify-contract \
 *   --verifier blockscout \
 *   --verifier-url https://gnosis.blockscout.com/api \
 *   <ADDRESS> src/Token.sol:Token
 *
 * Sourcify:
 * forge verify-contract \
 *   --verifier sourcify \
 *   <ADDRESS> src/Token.sol:Token
 *
 * VERIFY PROXY + IMPLEMENTATION:
 * After verifying the implementation, use Etherscan UI to
 * "Set Proxy Implementation" — links the proxy ABI automatically.
 *
 * COMMON ISSUES:
 * - Mismatch in optimizer runs: ensure foundry.toml matches what's on-chain
 * - via_ir: must be same at verify time as at compile time
 * - Missing constructor args: use cast abi-encode to build the hex
 * - Flattened source: forge flatten src/Token.sol > Token.flat.sol
 */

// contract DeployAndVerify is Script {
//
//     function run() external {
//         uint256 deployerKey     = vm.envUint("PRIVATE_KEY");
//         string memory rpcUrl    = vm.envString("RPC_URL");
//         string memory apiKey    = vm.envString("ETHERSCAN_API_KEY");
//
//         vm.startBroadcast(deployerKey);
//         ERC20Token token = new ERC20Token("MyToken", "MTK", 1_000_000e18);
//         vm.stopBroadcast();
//
//         // Foundry handles verification automatically when --verify is passed.
//         // The script itself does not need verification code.
//         // This is just logging for reference:
//         console.log("Contract:", address(token));
//         console.log("Verify with:");
//         console.log(
//             string.concat(
//                 "forge verify-contract ",
//                 vm.toString(address(token)),
//                 " src/Standards.sol:ERC20Token",
//                 " --chain-id ", vm.toString(block.chainid),
//                 " --etherscan-api-key <KEY>"
//             )
//         );
//     }
// }

// ============================================================
// SECTION 7: MULTI-CHAIN DEPLOYMENT
// ============================================================

/*
 * Deploy to multiple chains using a shell script or Makefile.
 * Each chain gets its own RPC_URL and optional API keys.
 *
 * Makefile example:
 *
 * deploy-all: deploy-mainnet deploy-arbitrum deploy-base deploy-optimism
 *
 * deploy-mainnet:
 *     forge script script/Deploy.s.sol \
 *       --rpc-url $(MAINNET_RPC)       \
 *       --private-key $(PRIVATE_KEY)   \
 *       --broadcast --verify           \
 *       --etherscan-api-key $(ETHERSCAN_KEY)
 *
 * deploy-arbitrum:
 *     forge script script/Deploy.s.sol \
 *       --rpc-url $(ARBITRUM_RPC)      \
 *       --private-key $(PRIVATE_KEY)   \
 *       --broadcast --verify           \
 *       --etherscan-api-key $(ARBISCAN_KEY)
 *
 * deploy-base:
 *     forge script script/Deploy.s.sol \
 *       --rpc-url $(BASE_RPC)          \
 *       --private-key $(PRIVATE_KEY)   \
 *       --broadcast --verify           \
 *       --etherscan-api-key $(BASESCAN_KEY)
 *
 * deploy-optimism:
 *     forge script script/Deploy.s.sol \
 *       --rpc-url $(OPTIMISM_RPC)      \
 *       --private-key $(PRIVATE_KEY)   \
 *       --broadcast --verify           \
 *       --etherscan-api-key $(OPSCAN_KEY)
 *
 * IMPORTANT:
 * Use CREATE2 with a shared salt for identical addresses on all chains.
 * Verify CREATE2 factory is available on the target chain.
 */

// contract DeployMultiChain is Script {
//
//     bytes32 constant SALT = keccak256("myprotocol.production.v1");
//
//     function run() external {
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//
//         vm.startBroadcast(deployerKey);
//
//         // Deterministic address — same across all EVM chains
//         ERC20Token token = new ERC20Token{salt: SALT}(
//             "MyToken",
//             "MTK",
//             _supplyForChain()
//         );
//
//         vm.stopBroadcast();
//
//         console.log("Deployed on chain", block.chainid, "at:", address(token));
//     }
//
//     function _supplyForChain() internal view returns (uint256) {
//         // Different supply caps per chain — governance decision
//         if (block.chainid == 1)     return 100_000_000e18; // mainnet: full supply
//         if (block.chainid == 42161) return  50_000_000e18; // arbitrum: 50%
//         if (block.chainid == 8453)  return  20_000_000e18; // base: 20%
//         return 1_000_000e18;                               // testnets: minimal
//     }
// }

// ============================================================
// SECTION 8: ENVIRONMENT & SECRETS MANAGEMENT
// ============================================================

/*
 * NEVER hardcode private keys or API keys in scripts.
 * Always read from environment variables.
 *
 * .env FILE STRUCTURE:
 *   PRIVATE_KEY=0x...
 *   MAINNET_RPC_URL=https://...
 *   SEPOLIA_RPC_URL=https://...
 *   ARBITRUM_RPC_URL=https://...
 *   ETHERSCAN_API_KEY=...
 *   ARBISCAN_API_KEY=...
 *   BASESCAN_API_KEY=...
 *
 * LOAD ENV IN SHELL:
 *   source .env
 *
 * FOUNDRY NATIVE ENV LOADING (foundry.toml):
 *   [profile.default]
 *   dotenv = ".env"           # auto-loads .env before every command
 *
 * .GITIGNORE — always exclude:
 *   .env
 *   deployments/*.json        # optional: if they contain sensitive data
 *   broadcast/               # contains raw transactions with gas prices
 *
 * vm.envOr — safe fallback for optional variables:
 *   address owner = vm.envOr("OWNER", deployer);
 *   uint256 supply = vm.envOr("INITIAL_SUPPLY", uint256(1_000_000e18));
 *
 * KEYSTORE (more secure than raw private key):
 *   cast wallet import deployer --interactive
 *   forge script ... --account deployer --password $KEYSTORE_PASSWORD
 *
 * HARDWARE WALLET (most secure):
 *   forge script ... --ledger --hd-paths "m/44'/60'/0'/0/0"
 */

// contract SecureDeployment is Script {
//
//     function run() external {
//         // Prefer keystore or hardware wallet over PRIVATE_KEY
//         // If PRIVATE_KEY is set, use it; otherwise assume Ledger/keystore via CLI
//         uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));
//
//         if (deployerKey != 0) {
//             vm.startBroadcast(deployerKey);
//         } else {
//             // Ledger/keystore: CLI handles signing, no key in script
//             vm.startBroadcast();
//         }
//
//         // Optional config from env with safe defaults
//         address owner  = vm.envOr("TOKEN_OWNER",   msg.sender);
//         uint256 supply = vm.envOr("INITIAL_SUPPLY", uint256(1_000_000e18));
//         string memory name   = vm.envOr("TOKEN_NAME",   "MyToken");
//         string memory symbol = vm.envOr("TOKEN_SYMBOL", "MTK");
//
//         ERC20Token token = new ERC20Token(name, symbol, supply);
//
//         if (token.owner() != owner) {
//             token.transferOwnership(owner);
//         }
//
//         vm.stopBroadcast();
//
//         console.log("Token:", address(token));
//         console.log("Owner:", token.owner());
//     }
// }

// ============================================================
// SECTION 9: DEPLOYMENT ARTIFACTS & BROADCAST FILES
// ============================================================

/*
 * After every broadcast, Foundry writes artifacts to:
 *   broadcast/<ScriptName.s.sol>/<chainId>/run-latest.json
 *   broadcast/<ScriptName.s.sol>/<chainId>/run-<timestamp>.json
 *
 * READING BROADCAST FILE:
 *   jq '.transactions[] | {contractName, contractAddress}' \
 *       broadcast/Deploy.s.sol/1/run-latest.json
 *
 * EXTRACT ADDRESS OF DEPLOYED CONTRACT:
 *   jq -r '.transactions[0].contractAddress' \
 *       broadcast/Deploy.s.sol/11155111/run-latest.json
 *
 * CUSTOM DEPLOYMENT TRACKING (in-script):
 * Write a JSON file with addresses after each deployment
 * so your frontend and other scripts always know where contracts are.
 *
 * READING A DEPLOYMENT FILE IN ANOTHER SCRIPT:
 *   string memory raw = vm.readFile("deployments/11155111.json");
 *   address token = abi.decode(vm.parseJson(raw, ".token"), (address));
 */

// contract DeployWithTracking is Script {
//
//     string constant DEPLOYMENTS_DIR = "deployments/";
//
//     function run() external {
//         uint256 key = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(key);
//
//         ERC20Token token = new ERC20Token("MyToken", "MTK", 1_000_000e18);
//
//         vm.stopBroadcast();
//
//         // Write deployment record
//         _writeRecord("ERC20Token", address(token));
//     }
//
//     function _writeRecord(string memory name, address addr) internal {
//         string memory chainDir = string.concat(
//             DEPLOYMENTS_DIR,
//             vm.toString(block.chainid),
//             "/"
//         );
//         // vm.createDir is available in forge-std ≥ v1.7
//         vm.createDir(chainDir, true);
//
//         string memory filePath = string.concat(chainDir, name, ".json");
//         string memory content  = string.concat(
//             '{"address":"', vm.toString(addr), '",',
//             '"block":', vm.toString(block.number), ',',
//             '"chainId":', vm.toString(block.chainid), '}'
//         );
//         vm.writeFile(filePath, content);
//         console.log("Saved:", filePath);
//     }
// }

// ============================================================
// SECTION 10: SAFE (MULTISIG) DEPLOYMENT
// ============================================================

/*
 * For production mainnet deployments, using a multisig (Gnosis Safe)
 * as the deployer or owner is the industry standard.
 *
 * OPTIONS:
 * A) Deploy from EOA, transfer ownership to Safe immediately
 * B) Deploy via Safe transaction (requires Safe SDK or propose-to-safe flow)
 * C) Use SafeDeployer / safe-foundry-lib
 *
 * OPTION A — simplest, most common:
 * 1. Deploy from EOA
 * 2. Call transferOwnership(safeAddress) in the same script
 * 3. Verify the Safe is owner before returning
 *
 * OPTION B — Safe as proposer:
 * Use safe-foundry-lib or Zodiac to propose transactions.
 * Owners sign off-chain, anyone can execute when threshold is reached.
 */

// contract DeployWithSafeTransfer is Script {
//
//     function run() external {
//         uint256 deployerKey  = vm.envUint("PRIVATE_KEY");
//         address safeMultisig = vm.envAddress("SAFE_ADDRESS");
//
//         vm.startBroadcast(deployerKey);
//
//         ERC20Token token = new ERC20Token("MyToken", "MTK", 1_000_000e18);
//
//         // Immediately transfer ownership to Safe — EOA has no lingering control
//         token.transferOwnership(safeMultisig);
//
//         vm.stopBroadcast();
//
//         // Verify ownership transferred correctly
//         require(token.owner() == safeMultisig, "Ownership transfer failed");
//
//         console.log("Token:     ", address(token));
//         console.log("Safe owner:", safeMultisig);
//     }
// }

// ============================================================
// SECTION 11: INTERACTION SCRIPTS (CAST + SCRIPT)
// ============================================================

/*
 * Interaction scripts perform actions on already-deployed contracts.
 * Use them for: initial configuration, parameter updates, migrations.
 *
 * CAST — CLI for quick one-off interactions:
 *
 * Read state (free):
 *   cast call $TOKEN_ADDR "totalSupply()" --rpc-url $RPC
 *   cast call $TOKEN_ADDR "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC
 *   cast call $TOKEN_ADDR "name()(string)" --rpc-url $RPC
 *
 * Send transaction:
 *   cast send $TOKEN_ADDR "transfer(address,uint256)" $RECIPIENT 1000000000000000000 \
 *     --private-key $PRIVATE_KEY --rpc-url $RPC
 *
 * Decode calldata:
 *   cast calldata-decode "transfer(address,uint256)" 0xa9059cbb...
 *
 * Decode event:
 *   cast decode-event "Transfer(address,address,uint256)" <topics> <data>
 *
 * Get storage slot:
 *   cast storage $TOKEN_ADDR 0 --rpc-url $RPC
 *
 * Compute selector:
 *   cast sig "transfer(address,uint256)"
 *
 * Convert units:
 *   cast to-wei 1.5 ether
 *   cast from-wei 1500000000000000000
 */

// contract InteractionScript is Script {
//
//     function run() external {
//         // Read deployed address from environment or deployment file
//         address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
//         uint256 key       = vm.envUint("PRIVATE_KEY");
//
//         ERC20Token token = ERC20Token(tokenAddr);
//
//         console.log("Token name:   ", token.name());
//         console.log("Total supply: ", token.totalSupply());
//         console.log("Owner:        ", token.owner());
//
//         // Example: mint to a list of recipients from a JSON file
//         string memory raw  = vm.readFile("config/airdrop.json");
//         address[] memory recipients = abi.decode(
//             vm.parseJson(raw, ".recipients"),
//             (address[])
//         );
//         uint256[] memory amounts = abi.decode(
//             vm.parseJson(raw, ".amounts"),
//             (uint256[])
//         );
//
//         vm.startBroadcast(key);
//
//         for (uint256 i = 0; i < recipients.length; i++) {
//             token.mint(recipients[i], amounts[i]);
//             console.log("Minted", amounts[i], "to", recipients[i]);
//         }
//
//         vm.stopBroadcast();
//     }
// }

// ============================================================
// SECTION 12: GAS ESTIMATION & COST ANALYSIS BEFORE DEPLOYING
// ============================================================

/*
 * Always estimate deployment costs before going live.
 *
 * SIMULATE DEPLOYMENT COST:
 *   forge script script/Deploy.s.sol --rpc-url $RPC_URL
 *   (no --broadcast — shows gas without sending)
 *
 * GAS PRICE STRATEGIES:
 *   --gas-price <WEI>            Fixed gas price (legacy)
 *   --priority-gas-price <WEI>   EIP-1559 tip
 *   --with-gas-price <WEI>       Legacy + EIP-1559
 *
 * CHECK CURRENT GAS PRICE:
 *   cast gas-price --rpc-url $RPC
 *   cast base-fee --rpc-url $RPC
 *
 * ESTIMATE CONTRACT SIZE:
 *   forge build --sizes
 *   (contracts > 24KB hit the EIP-170 size limit — split or optimize)
 *
 * SIZE OPTIMIZATION:
 *   optimizer_runs = 1        # minimize deployment size (more expensive per call)
 *   optimizer_runs = 200      # balanced (default)
 *   optimizer_runs = 1000000  # minimize call cost (larger bytecode)
 *   via_ir = true             # Yul IR pipeline — best for complex contracts
 */

// contract DeployWithGasAnalysis is Script {
//
//     function run() external {
//         uint256 gasBefore  = gasleft();
//         uint256 deployerKey = vm.envUint("PRIVATE_KEY");
//
//         vm.startBroadcast(deployerKey);
//         ERC20Token token = new ERC20Token("MyToken", "MTK", 1_000_000e18);
//         vm.stopBroadcast();
//
//         uint256 gasUsed = gasBefore - gasleft();
//         console.log("Deployment gas used:", gasUsed);
//         console.log("At 30 gwei:  ", (gasUsed * 30e9) / 1e18, "ETH");
//         console.log("At 10 gwei:  ", (gasUsed * 10e9) / 1e18, "ETH");
//         console.log("Contract size:", address(token).code.length, "bytes");
//     }
// }

// ============================================================
// SECTION 13: CI/CD PIPELINE FOR DEPLOYMENTS
// ============================================================

/*
 * Professional CI/CD using GitHub Actions:
 *
 * .github/workflows/deploy.yml:
 *
 * name: Deploy to Testnet
 * on:
 *   push:
 *     branches: [main]
 *
 * jobs:
 *   deploy:
 *     runs-on: ubuntu-latest
 *     steps:
 *       - uses: actions/checkout@v3
 *         with: { submodules: recursive }
 *
 *       - name: Install Foundry
 *         uses: foundry-rs/foundry-toolchain@v1
 *         with: { version: nightly }
 *
 *       - name: Run tests
 *         run: forge test --fork-url ${{ secrets.SEPOLIA_RPC_URL }}
 *
 *       - name: Check gas snapshot
 *         run: forge snapshot --diff          # fails if gas increased
 *
 *       - name: Check contract sizes
 *         run: forge build --sizes            # fails if > 24KB
 *
 *       - name: Deploy to Sepolia
 *         run: |
 *           forge script script/Deploy.s.sol \
 *             --rpc-url ${{ secrets.SEPOLIA_RPC_URL }} \
 *             --private-key ${{ secrets.DEPLOY_PRIVATE_KEY }} \
 *             --broadcast \
 *             --verify \
 *             --etherscan-api-key ${{ secrets.ETHERSCAN_API_KEY }}
 *         env:
 *           TOKEN_NAME:    "MyToken Testnet"
 *           TOKEN_SYMBOL:  "MTK-TEST"
 *
 *       - name: Upload deployment artifacts
 *         uses: actions/upload-artifact@v3
 *         with:
 *           name: deployments
 *           path: |
 *             broadcast/
 *             deployments/
 *
 * SECRETS TO ADD IN GITHUB:
 *   SEPOLIA_RPC_URL
 *   DEPLOY_PRIVATE_KEY   (use a dedicated deploy wallet with minimal ETH)
 *   ETHERSCAN_API_KEY
 */

// ============================================================
// SECTION 14: DEPLOYMENT CHECKLIST
// ============================================================

/*
 * PRE-DEPLOYMENT
 * [ ] All tests pass: forge test
 * [ ] Gas snapshot clean: forge snapshot --diff
 * [ ] No contracts over 24KB: forge build --sizes
 * [ ] Code reviewed by at least one other person
 * [ ] External audit completed (if applicable)
 * [ ] No sensitive data in scripts or .env committed to git
 * [ ] .env in .gitignore
 *
 * BEFORE MAINNET — TESTNET FIRST
 * [ ] Deployed to Sepolia or matching testnet
 * [ ] All contract functions tested manually via cast/frontend
 * [ ] Verified on Etherscan (testnet)
 * [ ] Proxy upgrade flow tested end-to-end (if applicable)
 * [ ] Multisig ownership transfer tested
 *
 * MAINNET DEPLOYMENT
 * [ ] Use hardware wallet or keystore (never raw private key in CI for mainnet)
 * [ ] Confirm gas price before broadcasting
 * [ ] Dry run first: forge script ... (no --broadcast)
 * [ ] Broadcast: add --broadcast
 * [ ] Verify: add --verify
 * [ ] Check explorer — contract source visible
 * [ ] Call key read functions to confirm correct state
 * [ ] Transfer ownership to multisig immediately after deploy
 * [ ] Confirm multisig is owner: cast call $ADDR "owner()(address)" --rpc-url $RPC
 *
 * POST-DEPLOYMENT
 * [ ] Commit broadcast/ and deployments/ to git
 * [ ] Tag the release: git tag v1.0.0 && git push --tags
 * [ ] Update frontend with new addresses
 * [ ] Set up monitoring (Tenderly, OpenZeppelin Defender, custom alerts)
 * [ ] Document deployment in changelog
 * [ ] Announce to community (if public protocol)
 *
 * EMERGENCY PLAN
 * [ ] Pause mechanism tested and ready
 * [ ] Emergency contact list prepared
 * [ ] Upgrade path validated (if upgradeable)
 * [ ] Timelock configured for admin functions
 */
