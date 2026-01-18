// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY IMPORTS AND PROJECT STRUCTURE - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. BASIC IMPORT SYNTAX
// ============================================================================

// Import entire file (all symbols available)
// import "./MyContract.sol";

// Import specific symbols
// import {MyContract, MyLibrary} from "./MyFile.sol";

// Import and rename (aliasing)
// import {MyContract as MC} from "./MyFile.sol";

// Import with wildcard and namespace
// import * as MyModule from "./MyFile.sol";
// Usage: MyModule.MyContract

// ============================================================================
// 2. RELATIVE IMPORTS
// ============================================================================

// Same directory
// import "./Token.sol";

// Parent directory
// import "../interfaces/IToken.sol";

// Multiple levels up
// import "../../lib/SafeMath.sol";

// Nested directories
// import "./utils/helpers/Math.sol";

// ============================================================================
// 3. ABSOLUTE IMPORTS (NPM PACKAGES)
// ============================================================================

// OpenZeppelin imports (most common)
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Chainlink imports
// import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Uniswap imports
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// ============================================================================
// 4. PRACTICAL EXAMPLES WITH IMPORTS
// ============================================================================

// Example 1: Importing interfaces
interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Example 2: Importing libraries
library MathLib {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function multiply(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
}

// Example 3: Importing and using
contract MyContract {
    using MathLib for uint256;

    IToken public token;

    constructor(address tokenAddress) {
        token = IToken(tokenAddress);
    }

    function useLibrary(uint256 a, uint256 b) external pure returns (uint256) {
        return a.add(b);
    }
}

// ============================================================================
// 5. RECOMMENDED PROJECT STRUCTURE
// ============================================================================

/*
project-root/
├── contracts/
│   ├── core/
│   │   ├── Token.sol              # Main token contract
│   │   ├── Staking.sol            # Staking logic
│   │   └── Governance.sol         # DAO governance
│   │
│   ├── interfaces/
│   │   ├── IToken.sol             # Token interface
│   │   ├── IStaking.sol           # Staking interface
│   │   └── IGovernance.sol        # Governance interface
│   │
│   ├── libraries/
│   │   ├── SafeMath.sol           # Math library
│   │   ├── Arrays.sol             # Array utilities
│   │   └── Strings.sol            # String utilities
│   │
│   ├── abstracts/
│   │   ├── Ownable.sol            # Ownership pattern
│   │   ├── Pausable.sol           # Pause pattern
│   │   └── ReentrancyGuard.sol    # Reentrancy protection
│   │
│   ├── utils/
│   │   ├── Constants.sol          # Global constants
│   │   └── Errors.sol             # Custom errors
│   │
│   └── mocks/
│       ├── MockToken.sol          # For testing
│       └── MockOracle.sol         # For testing
│
├── scripts/
│   ├── deploy.js                  # Deployment script
│   └── verify.js                  # Verification script
│
├── test/
│   ├── Token.test.js              # Token tests
│   └── Staking.test.js            # Staking tests
│
├── hardhat.config.js              # Hardhat configuration
├── remappings.txt                 # Import remappings
├── package.json                   # NPM dependencies
└── README.md                      # Documentation
*/

// ============================================================================
// 6. INTERFACE SEPARATION
// ============================================================================

// interfaces/IMyToken.sol
interface IMyToken {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

// contracts/MyToken.sol
// import "./interfaces/IMyToken.sol";

contract MyToken is IMyToken {
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
}

// ============================================================================
// 7. LIBRARY SEPARATION
// ============================================================================

// libraries/AddressUtils.sol
library AddressUtils {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// Usage in contracts
contract UsingLibrary {
    using AddressUtils for address;

    function checkIfContract(address addr) external view returns (bool) {
        return addr.isContract();
    }
}

// ============================================================================
// 8. ABSTRACT CONTRACTS SEPARATION
// ============================================================================

// abstracts/AccessControl.sol
abstract contract AccessControl {
    address public owner;
    mapping(address => bool) public admins;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Not admin");
        _;
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addAdmin(address account) external onlyOwner {
        admins[account] = true;
        emit AdminAdded(account);
    }

    function removeAdmin(address account) external onlyOwner {
        admins[account] = false;
        emit AdminRemoved(account);
    }
}

// Using abstract contract
contract MyProtectedContract is AccessControl {
    uint256 public value;

    function setValue(uint256 newValue) external onlyAdmin {
        value = newValue;
    }
}

// ============================================================================
// 9. CONSTANTS AND ERRORS SEPARATION
// ============================================================================

// utils/Constants.sol
library Constants {
    uint256 constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 constant DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 100_000 * 10 ** 18;

    address constant ZERO_ADDRESS = address(0);
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 constant SECONDS_PER_DAY = 86400;
    uint256 constant SECONDS_PER_YEAR = 31536000;
}

// utils/Errors.sol
library Errors {
    error Unauthorized(address caller);
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidAddress(address addr);
    error TransferFailed();
    error AlreadyInitialized();
}

// Usage
contract UsingConstantsAndErrors {
    uint256 public totalSupply = Constants.MAX_SUPPLY;

    function transfer(address to, uint256 amount) external {
        if (to == Constants.ZERO_ADDRESS) {
            revert Errors.InvalidAddress(to);
        }

        // Transfer logic
    }
}

// ============================================================================
// 10. REMAPPINGS (FOUNDRY/HARDHAT)
// ============================================================================

// remappings.txt (Foundry)
/*
@openzeppelin/=lib/openzeppelin-contracts/
@chainlink/=lib/chainlink/
@uniswap/=lib/uniswap/
ds-test/=lib/ds-test/src/
forge-std/=lib/forge-std/src/
*/

// hardhat.config.js (Hardhat)
/*
module.exports = {
  solidity: "0.8.24",
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
*/

// ============================================================================
// 11. MULTI-FILE CONTRACT EXAMPLE
// ============================================================================

// Step 1: Create interface
// File: interfaces/IVault.sol
interface IVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

// Step 2: Create library
// File: libraries/VaultMath.sol
library VaultMath {
    function calculateShares(
        uint256 amount,
        uint256 totalShares,
        uint256 totalAssets
    ) internal pure returns (uint256) {
        if (totalShares == 0) return amount;
        return (amount * totalShares) / totalAssets;
    }
}

// Step 3: Create main contract
// File: contracts/Vault.sol
// import "./interfaces/IVault.sol";
// import "./libraries/VaultMath.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Simple IERC20 interface for demonstration
interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Vault is IVault {
    using VaultMath for uint256;

    IERC20 public immutable asset;

    mapping(address => uint256) private _balances;
    uint256 public totalShares;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount) external override {
        uint256 shares = VaultMath.calculateShares(
            amount,
            totalShares,
            asset.balanceOf(address(this))
        );

        _balances[msg.sender] += shares;
        totalShares += shares;

        asset.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external override {
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        totalShares -= amount;

        asset.transfer(msg.sender, amount);
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return _balances[account];
    }
}

// ============================================================================
// 12. BEST PRACTICES FOR IMPORTS
// ============================================================================

contract ImportBestPractices {
    // ✅ DO: Import specific symbols
    // import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    // ❌ DON'T: Import everything unless necessary
    // import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    // ✅ DO: Use interfaces for external contracts
    // import {IERC20} from "./interfaces/IERC20.sol";
    // ✅ DO: Organize imports by category
    /*
    // OpenZeppelin imports
    import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
    import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
    
    // Local interfaces
    import {IVault} from "./interfaces/IVault.sol";
    
    // Local libraries
    import {VaultMath} from "./libraries/VaultMath.sol";
    */
    // ✅ DO: Use relative paths for local files
    // import "./Token.sol";
    // ✅ DO: Use package imports for external dependencies
    // import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
}

// ============================================================================
// 13. VERSIONING AND PACKAGE MANAGEMENT
// ============================================================================

// package.json
/*
{
  "name": "my-solidity-project",
  "version": "1.0.0",
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@chainlink/contracts": "^0.8.0",
    "hardhat": "^2.19.0"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "solidity-coverage": "^0.8.5"
  }
}
*/

// ============================================================================
// KEY IMPORT TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Imports: Use specific imports {Symbol} instead of wildcards
// 2. Structure: Separate interfaces, libraries, abstracts, and contracts
// 3. Interfaces: Always create interfaces for external interactions
// 4. Libraries: Extract reusable logic into libraries
// 5. Abstracts: Use for common patterns (Ownable, Pausable, etc.)
// 6. Constants: Centralize constants and errors
// 7. Relative Paths: Use for local files within project
// 8. Absolute Paths: Use for NPM packages (@openzeppelin, etc.)
// 9. Remappings: Configure in remappings.txt or hardhat.config.js
// 10. Organization: Group imports by category (external, local, etc.)
// 11. Naming: Use clear, descriptive names for files/folders
// 12. Documentation: Document complex imports and dependencies
// 13. Testing: Create mocks in separate directory
// 14. Versioning: Pin package versions in package.json
// 15. Standards: Follow community standards (OpenZeppelin structure)
// ============================================================================
