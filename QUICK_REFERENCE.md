# ⚡ SOLIDITY QUICK REFERENCE GUIDE
## Essential Commands, Patterns & Best Practices

---

## 🎯 DEVELOPMENT SETUP

### Hardhat Quick Start
```bash
npm init -y
npm install --save-dev hardhat
npx hardhat init
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts
```

### Foundry Quick Start
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge init my-project
forge install OpenZeppelin/openzeppelin-contracts
forge build
forge test
```

---

## 🔒 SECURITY CHECKLIST (Copy-Paste for PRs)

```markdown
## Security Checklist

- [ ] All external calls follow Checks-Effects-Interactions
- [ ] ReentrancyGuard on functions with external calls
- [ ] Zero address validation on all address inputs
- [ ] Amount validation (non-zero, within bounds)
- [ ] Access control (onlyOwner/roles) on admin functions
- [ ] Events emitted for all state changes
- [ ] Custom errors instead of require strings
- [ ] SafeERC20 used for all token transfers
- [ ] No timestamp == comparisons
- [ ] No unbounded loops
- [ ] Pull over push for payments
- [ ] Storage packed for gas efficiency
- [ ] Upgrade path defined
- [ ] Emergency pause mechanism
- [ ] All return values checked
```

---

## 🛠️ ESSENTIAL PATTERNS

### 1. Safe External Calls
```solidity
// ✅ GOOD
(bool success, bytes memory data) = target.call{value: amount}("");
require(success, "Call failed");

// ✅ BETTER with custom error
error CallFailed(address target, bytes data);
(bool success, bytes memory returnData) = target.call{value: amount}("");
if (!success) revert CallFailed(target, returnData);
```

### 2. Custom Errors (Gas Efficient)
```solidity
// ❌ BAD (expensive)
require(amount > 0, "Amount must be greater than zero");

// ✅ GOOD (saves gas)
error InvalidAmount(uint256 amount);
if (amount == 0) revert InvalidAmount(amount);
```

### 3. Checks-Effects-Interactions
```solidity
function withdraw(uint256 amount) external {
    // 1. CHECKS
    require(balances[msg.sender] >= amount, "Insufficient balance");
    
    // 2. EFFECTS
    balances[msg.sender] -= amount;
    emit Withdrawal(msg.sender, amount);
    
    // 3. INTERACTIONS
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

### 4. Access Control
```solidity
// Simple owner pattern
modifier onlyOwner() {
    require(msg.sender == owner, "Not owner");
    _;
}

// Role-based (OpenZeppelin)
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyContract is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function adminFunction() external onlyRole(ADMIN_ROLE) {
        // Protected function
    }
}
```

### 5. ReentrancyGuard
```solidity
// OpenZeppelin pattern
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MyContract is ReentrancyGuard {
    function withdraw() external nonReentrant {
        // Safe from reentrancy
    }
}

// Manual implementation
uint256 private locked = 1;
modifier nonReentrant() {
    require(locked == 1, "Reentrant call");
    locked = 2;
    _;
    locked = 1;
}
```

---

## ⚡ GAS OPTIMIZATION QUICK WINS

### Storage Packing
```solidity
// BAD: 3 slots (96 bytes)
uint8 a;    // slot 0
uint256 b;  // slot 1
uint8 c;    // slot 2

// GOOD: 2 slots (64 bytes)
uint8 a;    // slot 0
uint8 c;    // slot 0
uint256 b;  // slot 1
```

### Calldata vs Memory
```solidity
// ❌ EXPENSIVE
function process(uint256[] memory data) external {
    // Copies to memory
}

// ✅ CHEAPER
function process(uint256[] calldata data) external {
    // No copy, read-only
}
```

### Cache Storage Variables
```solidity
// ❌ EXPENSIVE: Multiple SLOAD operations
function bad() external view returns (uint256) {
    return storageVar * 2 + storageVar + storageVar;
}

// ✅ CHEAP: One SLOAD
function good() external view returns (uint256) {
    uint256 cached = storageVar;
    return cached * 2 + cached + cached;
}
```

### Use Immutable for Constants Set in Constructor
```solidity
// ✅ BEST
address public immutable token; // Set once, cheaper to read

constructor(address _token) {
    token = _token;
}
```

---

## 🧪 TESTING COMMANDS

### Hardhat
```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/MyContract.test.js

# Gas reporting
REPORT_GAS=true npx hardhat test

# Coverage
npx hardhat coverage

# Console log debugging
npx hardhat test --logs
```

### Foundry
```bash
# Run all tests
forge test

# Verbose output
forge test -vvv

# Gas reporting
forge test --gas-report

# Test specific contract
forge test --match-contract MyContractTest

# Test specific function
forge test --match-test testWithdraw

# Coverage
forge coverage

# Fuzz testing (built-in)
forge test --fuzz-runs 10000
```

---

## 🔍 DEBUGGING & ANALYSIS

### Slither (Static Analysis)
```bash
# Install
pip3 install slither-analyzer

# Run analysis
slither .

# Specific contract
slither contracts/MyContract.sol

# Save report
slither . --json slither-report.json
```

### Mythril (Security Scanner)
```bash
# Install
pip3 install mythril

# Analyze contract
myth analyze contracts/MyContract.sol

# With specific timeout
myth analyze contracts/MyContract.sol --execution-timeout 300
```

### Echidna (Fuzzing)
```bash
# Install
docker pull trailofbits/eth-security-toolbox

# Run fuzzing
echidna-test contracts/MyContract.sol --contract MyContract
```

---

## 📝 USEFUL CODE SNIPPETS

### Safe Math (Built-in 0.8.0+)
```solidity
// Automatic overflow/underflow protection
uint256 result = a + b; // Reverts on overflow

// Explicit unchecked (use carefully!)
unchecked {
    uint256 result = a + b; // No revert, wraps around
}
```

### Safe ERC20 Transfers
```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

function transferTokens(address token, address to, uint256 amount) external {
    IERC20(token).safeTransfer(to, amount);
    // Handles non-standard ERC20 tokens
}
```

### Signature Verification
```solidity
function verifySignature(
    bytes32 messageHash,
    bytes memory signature,
    address expectedSigner
) public pure returns (bool) {
    bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    address recovered = ECDSA.recover(ethSignedHash, signature);
    return recovered == expectedSigner;
}
```

### Merkle Proof Verification
```solidity
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

function verifyWhitelist(
    bytes32[] calldata proof,
    bytes32 root,
    address account
) public pure returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(account));
    return MerkleProof.verify(proof, root, leaf);
}
```

---

## 🚀 DEPLOYMENT COMMANDS

### Hardhat Deploy
```javascript
// scripts/deploy.js
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with:", deployer.address);
    
    const MyContract = await ethers.getContractFactory("MyContract");
    const contract = await MyContract.deploy(arg1, arg2);
    await contract.deployed();
    
    console.log("Contract deployed to:", contract.address);
    
    // Verify on Etherscan
    await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: [arg1, arg2],
    });
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
```

```bash
# Deploy to network
npx hardhat run scripts/deploy.js --network sepolia

# Verify contract
npx hardhat verify --network sepolia CONTRACT_ADDRESS "arg1" "arg2"
```

### Foundry Deploy
```bash
# Deploy with verification
forge create \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify \
  contracts/MyContract.sol:MyContract \
  --constructor-args arg1 arg2

# Script-based deployment
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

---

## 📊 GAS OPTIMIZATION CHECKLIST

```markdown
## Gas Optimization Review

Storage:
- [ ] Variables packed (<32 bytes together)
- [ ] Use uint256 for calculations (even if smaller values)
- [ ] Constants marked as constant
- [ ] Immutables used for constructor-set values
- [ ] Minimize storage writes

Functions:
- [ ] Use calldata instead of memory for external functions
- [ ] Cache storage variables in memory loops
- [ ] Short-circuit boolean expressions (&&, ||)
- [ ] Remove dead code
- [ ] Use unchecked for safe arithmetic

Loops:
- [ ] Cache array.length outside loop
- [ ] Use ++i instead of i++
- [ ] Avoid storage operations inside loops
- [ ] Consider batching

Events & Errors:
- [ ] Use indexed for filterable parameters (max 3)
- [ ] Custom errors instead of require strings
- [ ] Events for state changes (cheaper than storage reads)
```

---

## 🎓 LEARNING RESOURCES QUICK LINKS

**Must-Do Challenges:**
1. [Ethernaut](https://ethernaut.openzeppelin.com) - 28 security levels
2. [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz) - DeFi hacking
3. [Capture The Ether](https://capturetheether.com) - Classic CTF

**Best Video Courses:**
1. [Patrick Collins 32h Course](https://www.youtube.com/watch?v=gyMwXuJrbJQ) - Free & comprehensive
2. [Smart Contract Programmer](https://www.youtube.com/@smartcontractprogrammer) - Bite-sized topics
3. [Cyfrin Updraft](https://updraft.cyfrin.io) - Professional grade

**Essential Reading:**
1. [Solidity Docs](https://docs.soliditylang.org) - Official docs
2. [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices)
3. [OpenZeppelin Docs](https://docs.openzeppelin.com)
4. [Audit Reports on Solodit](https://solodit.xyz)

**Earn While Learning:**
- [Code4rena](https://code4rena.com) - Audit contests 💰
- [Sherlock](https://www.sherlock.xyz) - Security competitions 💰
- [Immunefi](https://immunefi.com) - Bug bounties 💰💰💰

---

## 🆘 COMMON ERRORS & SOLUTIONS

### "Transaction reverted without a reason"
```solidity
// Add detailed error messages or custom errors
error InsufficientBalance(uint256 requested, uint256 available);

if (balance < amount) {
    revert InsufficientBalance(amount, balance);
}
```

### "Out of gas"
- Optimize storage packing
- Remove unnecessary storage operations
- Batch operations
- Use events instead of storage for historical data

### "Contract size exceeds limit"
- Split into multiple contracts
- Use libraries
- Remove unused code
- Optimize imports

### "Stack too deep"
- Reduce local variables
- Use structs to group variables
- Split into smaller functions

---

## 💡 PRO TIPS

1. **Always use latest stable Solidity version** (currently 0.8.24)
2. **Use OpenZeppelin contracts** instead of writing from scratch
3. **Write tests first** (TDD approach)
4. **Get code audited** before mainnet deployment
5. **Use multi-sig wallets** for admin functions
6. **Implement pause mechanism** for emergencies
7. **Test on testnets** extensively (Sepolia, Goerli)
8. **Monitor with Tenderly** or Defender after deployment
9. **Read audit reports** to learn common vulnerabilities
10. **Join Discord communities** for real-time help

---

## 📌 KEYBOARD SHORTCUTS (Remix IDE)

- `Ctrl + S` - Compile
- `Ctrl + Shift + F` - Format code
- `Ctrl + /` - Toggle comment
- `Ctrl + F` - Find
- `Ctrl + H` - Find and replace

---

**Keep this guide handy! Bookmark for quick reference during development.**

*Last updated: February 2026*
