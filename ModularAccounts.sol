// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// =============================================================================
// ERC-7579: MINIMAL MODULAR SMART ACCOUNTS
// =============================================================================
//
//  By 2026 ERC-7579 is the de-facto standard for modular smart accounts,
//  implemented by Safe, ZeroDev (Kernel V3), Biconomy (Nexus), Rhinestone and
//  the OpenZeppelin modular-account preset. It standardizes HOW modules plug
//  into an account so a validator/executor written once works across vendors.
//
//  WHERE IT SITS IN THE STACK:
//  - ERC-4337  → the EntryPoint / UserOperation mempool (see Testing.sol)
//  - EIP-7702  → lets a plain EOA delegate to account code (see EIP7702.sol)
//  - ERC-7579  → the module interface an account exposes (THIS FILE)
//  7702 + 7579 is the 2026 meta: upgrade an EOA into a modular smart account.
//
//  MODULE TYPES (an account is a thin core; behavior lives in modules):
//   1. Validator  — decides if a UserOperation / 1271 signature is valid
//   2. Executor   — can call `executeFromExecutor` to act on the account
//   3. Fallback   — handles specific selectors (e.g. token callbacks)
//   4. Hook       — runs before/after every execution (policies, spending caps)
//
//  SECTIONS:
//   1. Execution mode encoding (ModeCode / CallType / ExecType)
//   2. Core interfaces (modules + IERC7579Account)
//   3. A minimal modular account (validators + executors, single & batch)
//   4. ECDSA validator module
//   5. Session-key validator module (the #1 requested module category)
// =============================================================================

// -----------------------------------------------------------------------------
// SECTION 1 — EXECUTION MODE ENCODING
// -----------------------------------------------------------------------------
// A 32-byte ModeCode packs how `execute` should run:
//   [ CallType(1) | ExecType(1) | unused(4) | ModeSelector(4) | Payload(22) ]
// We only use the first two bytes here; selector/payload are for extensions.

type ModeCode is bytes32;
type CallType is bytes1;
type ExecType is bytes1;

// CallType: how the calldata is shaped
CallType constant CALLTYPE_SINGLE       = CallType.wrap(0x00);
CallType constant CALLTYPE_BATCH        = CallType.wrap(0x01);
CallType constant CALLTYPE_DELEGATECALL = CallType.wrap(0xff);

// ExecType: what happens on a failed sub-call
ExecType constant EXECTYPE_DEFAULT = ExecType.wrap(0x00); // revert the whole tx
ExecType constant EXECTYPE_TRY     = ExecType.wrap(0x01); // keep going, emit event

function _eq(CallType a, CallType b) pure returns (bool) {
    return CallType.unwrap(a) == CallType.unwrap(b);
}
function _eq(ExecType a, ExecType b) pure returns (bool) {
    return ExecType.unwrap(a) == ExecType.unwrap(b);
}

library ModeLib {
    function getCallType(ModeCode mode) internal pure returns (CallType) {
        return CallType.wrap(ModeCode.unwrap(mode)[0]);
    }
    function getExecType(ModeCode mode) internal pure returns (ExecType) {
        return ExecType.wrap(ModeCode.unwrap(mode)[1]);
    }
    // Helpers to build common modes off-chain or in tests
    function encodeSingle() internal pure returns (ModeCode) {
        return ModeCode.wrap(bytes32(0)); // single + default
    }
    function encodeBatch() internal pure returns (ModeCode) {
        return ModeCode.wrap(bytes32(uint256(1) << 248)); // first byte = 0x01
    }
}

// A single element of a batch execution
struct Execution {
    address target;
    uint256 value;
    bytes   callData;
}

// ERC-4337 v0.7+ packed user operation (gas fields packed into bytes32 pairs)
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes   initCode;
    bytes   callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes   paymasterAndData;
    bytes   signature;
}

// -----------------------------------------------------------------------------
// SECTION 2 — CORE INTERFACES
// -----------------------------------------------------------------------------

// Module type IDs
uint256 constant MODULE_TYPE_VALIDATOR = 1;
uint256 constant MODULE_TYPE_EXECUTOR  = 2;
uint256 constant MODULE_TYPE_FALLBACK  = 3;
uint256 constant MODULE_TYPE_HOOK      = 4;

/// @notice Every module implements this base lifecycle interface.
interface IModule {
    function onInstall(bytes calldata data) external;
    function onUninstall(bytes calldata data) external;
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}

/// @notice Validators gate UserOperations and ERC-1271 signatures.
interface IValidator is IModule {
    // Returns 0 on success, 1 on failure (ERC-4337 validation data convention;
    // upper bits may pack validAfter/validUntil — omitted here for clarity).
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256);

    function isValidSignatureWithSender(address sender, bytes32 hash, bytes calldata data)
        external
        view
        returns (bytes4);
}

/// @notice Executors can drive the account via `executeFromExecutor`.
interface IExecutor is IModule {}

/// @notice The minimal surface an ERC-7579 account exposes.
interface IERC7579Account {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function execute(ModeCode mode, bytes calldata executionCalldata) external payable;

    function executeFromExecutor(ModeCode mode, bytes calldata executionCalldata)
        external
        payable
        returns (bytes[] memory returnData);

    function installModule(uint256 moduleTypeId, address module, bytes calldata initData)
        external
        payable;

    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData)
        external
        payable;

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata additionalContext)
        external
        view
        returns (bool);

    function accountId() external view returns (string memory);
    function supportsExecutionMode(ModeCode mode) external view returns (bool);
    function supportsModule(uint256 moduleTypeId) external view returns (bool);
}

// -----------------------------------------------------------------------------
// SECTION 3 — A MINIMAL MODULAR ACCOUNT
// -----------------------------------------------------------------------------

/// @title ModularSmartAccount
/// @notice Educational ERC-7579 core: installs validator/executor modules and
///         routes ERC-4337 validation to the validator named in the nonce.
contract ModularSmartAccount is IERC7579Account {
    using ModeLib for ModeCode;

    address public immutable ENTRY_POINT;

    mapping(address => bool) internal _validators;
    mapping(address => bool) internal _executors;

    event TryExecuteUnsuccessful(address target, bytes callData);

    error NotFromEntryPointOrSelf();
    error NotInstalledExecutor();
    error UnsupportedModuleType(uint256 moduleTypeId);
    error UnsupportedCallType(CallType callType);
    error InvalidValidator(address validator);

    constructor(address entryPoint) {
        ENTRY_POINT = entryPoint;
    }

    modifier onlyEntryPointOrSelf() {
        if (msg.sender != ENTRY_POINT && msg.sender != address(this)) {
            revert NotFromEntryPointOrSelf();
        }
        _;
    }

    // --- ERC-4337 entry: route validation to the validator packed in the nonce ---
    // nonce layout: [ validator address in key | 64-bit sequence ]. We read the
    // validator from the low 160 bits of the 192-bit key (nonce >> 64).
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        if (msg.sender != ENTRY_POINT) revert NotFromEntryPointOrSelf();

        address validator = address(uint160(userOp.nonce >> 64));
        if (!_validators[validator]) revert InvalidValidator(validator);

        validationData = IValidator(validator).validateUserOp(userOp, userOpHash);

        if (missingAccountFunds > 0) {
            (bool ok, ) = ENTRY_POINT.call{value: missingAccountFunds}("");
            ok; // best-effort prefund; EntryPoint reverts later if underpaid
        }
    }

    // --- Execution ---
    function execute(ModeCode mode, bytes calldata executionCalldata)
        external
        payable
        onlyEntryPointOrSelf
    {
        _execute(mode, executionCalldata);
    }

    function executeFromExecutor(ModeCode mode, bytes calldata executionCalldata)
        external
        payable
        returns (bytes[] memory returnData)
    {
        if (!_executors[msg.sender]) revert NotInstalledExecutor();
        return _execute(mode, executionCalldata);
    }

    function _execute(ModeCode mode, bytes calldata executionCalldata)
        internal
        returns (bytes[] memory returnData)
    {
        ExecType execType = mode.getExecType();
        CallType callType = mode.getCallType();

        if (_eq(callType, CALLTYPE_SINGLE)) {
            (address target, uint256 value, bytes calldata callData) =
                _decodeSingle(executionCalldata);
            returnData = new bytes[](1);
            returnData[0] = _call(target, value, callData, execType);
        } else if (_eq(callType, CALLTYPE_BATCH)) {
            Execution[] memory execs = abi.decode(executionCalldata, (Execution[]));
            returnData = new bytes[](execs.length);
            for (uint256 i; i < execs.length; ++i) {
                returnData[i] = _call(execs[i].target, execs[i].value, execs[i].callData, execType);
            }
        } else {
            revert UnsupportedCallType(callType);
        }
    }

    function _decodeSingle(bytes calldata ec)
        private
        pure
        returns (address target, uint256 value, bytes calldata callData)
    {
        // packed: 20-byte target | 32-byte value | remaining calldata
        assembly {
            target := shr(96, calldataload(ec.offset))
            value := calldataload(add(ec.offset, 20))
            callData.offset := add(ec.offset, 52)
            callData.length := sub(ec.length, 52)
        }
    }

    function _call(address target, uint256 value, bytes memory data, ExecType execType)
        private
        returns (bytes memory result)
    {
        bool ok;
        (ok, result) = target.call{value: value}(data);
        if (!ok) {
            if (_eq(execType, EXECTYPE_DEFAULT)) {
                assembly { revert(add(result, 0x20), mload(result)) } // bubble revert reason
            }
            emit TryExecuteUnsuccessful(target, data); // EXECTYPE_TRY: swallow & log
        }
    }

    // --- Module management ---
    function installModule(uint256 moduleTypeId, address module, bytes calldata initData)
        external
        payable
        onlyEntryPointOrSelf
    {
        if (!IModule(module).isModuleType(moduleTypeId)) revert UnsupportedModuleType(moduleTypeId);

        if (moduleTypeId == MODULE_TYPE_VALIDATOR)      _validators[module] = true;
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR)  _executors[module] = true;
        else revert UnsupportedModuleType(moduleTypeId);

        IModule(module).onInstall(initData);
        emit ModuleInstalled(moduleTypeId, module);
    }

    function uninstallModule(uint256 moduleTypeId, address module, bytes calldata deInitData)
        external
        payable
        onlyEntryPointOrSelf
    {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR)      delete _validators[module];
        else if (moduleTypeId == MODULE_TYPE_EXECUTOR)  delete _executors[module];
        else revert UnsupportedModuleType(moduleTypeId);

        IModule(module).onUninstall(deInitData);
        emit ModuleUninstalled(moduleTypeId, module);
    }

    function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata)
        external
        view
        returns (bool)
    {
        if (moduleTypeId == MODULE_TYPE_VALIDATOR) return _validators[module];
        if (moduleTypeId == MODULE_TYPE_EXECUTOR)  return _executors[module];
        return false;
    }

    // --- Introspection ---
    function accountId() external pure returns (string memory) {
        return "reference.modular-account.v1";
    }

    function supportsExecutionMode(ModeCode mode) external pure returns (bool) {
        CallType ct = mode.getCallType();
        return _eq(ct, CALLTYPE_SINGLE) || _eq(ct, CALLTYPE_BATCH);
    }

    function supportsModule(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR || moduleTypeId == MODULE_TYPE_EXECUTOR;
    }

    receive() external payable {}
}

// -----------------------------------------------------------------------------
// SECTION 4 — ECDSA VALIDATOR MODULE
// -----------------------------------------------------------------------------
// The simplest validator: one owner key per account. Written once, it works in
// any ERC-7579 account (Safe, Kernel, Nexus, ...).

library ECDSA {
    function recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
        // reject malleable upper-range s values
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }
        return ecrecover(hash, v, r, s);
    }
}

contract ECDSAValidator is IValidator {
    using ECDSA for bytes32;

    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;
    uint256 internal constant SIG_OK   = 0;
    uint256 internal constant SIG_FAIL = 1;

    // one owner per installing account (the account is msg.sender on install)
    mapping(address account => address owner) public owners;

    function onInstall(bytes calldata data) external {
        owners[msg.sender] = address(bytes20(data[0:20]));
    }

    function onUninstall(bytes calldata) external {
        delete owners[msg.sender];
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        returns (uint256)
    {
        address signer = userOpHash.recover(userOp.signature);
        return signer == owners[userOp.sender] && signer != address(0) ? SIG_OK : SIG_FAIL;
    }

    function isValidSignatureWithSender(address sender, bytes32 hash, bytes calldata data)
        external
        view
        returns (bytes4)
    {
        address signer = hash.recover(data);
        return (signer == owners[sender] && signer != address(0)) ? ERC1271_MAGIC : bytes4(0xffffffff);
    }
}

// -----------------------------------------------------------------------------
// SECTION 5 — SESSION-KEY VALIDATOR MODULE
// -----------------------------------------------------------------------------
// Session keys are the most requested module category in 2026: a temporary key
// that may call ONE target/selector until it expires — perfect for games, bots
// and "approve once, act many times" UX without exposing the owner key.

contract SessionKeyValidator is IValidator {
    using ECDSA for bytes32;

    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;
    uint256 internal constant SIG_OK   = 0;
    uint256 internal constant SIG_FAIL = 1;

    struct Session {
        address key;          // the session signer
        address target;       // the only contract it may call
        bytes4  selector;     // the only function it may call
        uint48  validUntil;   // expiry (unix seconds)
        bool    enabled;
    }

    // account => session
    mapping(address account => Session) public sessions;

    event SessionEnabled(address indexed account, address key, address target, uint48 validUntil);

    function onInstall(bytes calldata data) external {
        (address key, address target, bytes4 selector, uint48 validUntil) =
            abi.decode(data, (address, address, bytes4, uint48));
        sessions[msg.sender] =
            Session({key: key, target: target, selector: selector, validUntil: validUntil, enabled: true});
        emit SessionEnabled(msg.sender, key, target, validUntil);
    }

    function onUninstall(bytes calldata) external {
        delete sessions[msg.sender];
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        returns (uint256)
    {
        Session storage s = sessions[userOp.sender];
        if (!s.enabled || block.timestamp > s.validUntil) return SIG_FAIL;

        address signer = userOpHash.recover(userOp.signature);
        if (signer != s.key || signer == address(0)) return SIG_FAIL;

        // Enforce the session policy: callData must be execute(single) to the
        // allowed target+selector. We inspect the account's `execute` payload.
        if (!_callMatchesPolicy(userOp.callData, s.target, s.selector)) return SIG_FAIL;

        return SIG_OK;
    }

    function isValidSignatureWithSender(address, bytes32, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        // Session keys are for execution, not off-chain 1271 signing.
        return bytes4(0xffffffff);
    }

    // Decodes execute(ModeCode, bytes) and checks the inner single-call policy.
    function _callMatchesPolicy(bytes calldata accountCalldata, address target, bytes4 selector)
        private
        pure
        returns (bool)
    {
        // accountCalldata = execute.selector ++ abi.encode(ModeCode, bytes execData)
        if (accountCalldata.length < 4) return false;
        if (bytes4(accountCalldata[0:4]) != IERC7579Account.execute.selector) return false;

        (, bytes memory execData) = abi.decode(accountCalldata[4:], (bytes32, bytes));
        // execData (single) = 20-byte target | 32-byte value | inner calldata
        if (execData.length < 56) return false;

        address callTarget;
        bytes4  innerSelector;
        assembly {
            callTarget := shr(96, mload(add(execData, 0x20)))      // first 20 bytes
            innerSelector := mload(add(execData, 0x6C))            // byte 52..56 (after 20+32)
        }
        return callTarget == target && innerSelector == selector;
    }
}
