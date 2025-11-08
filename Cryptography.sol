// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY CRYPTOGRAPHY - Complete Reference
// From Zero to Professional
// ============================================================================

contract Cryptography {
    // ============================================================================
    // 1. KECCAK256 - Most Common Hash in Ethereum
    // ============================================================================
    // - SHA-3 (Keccak) family
    // - Returns bytes32 (256 bits)
    // - Most widely used in Ethereum
    // - Deterministic: same input = same output

    function keccak256Examples()
        public
        pure
        returns (bytes32 hash1, bytes32 hash2, bytes32 hash3)
    {
        // Hash a string
        hash1 = keccak256("Hello World");

        // Hash bytes
        hash2 = keccak256(bytes("Hello World"));

        // Hash multiple values with abi.encodePacked
        hash3 = keccak256(abi.encodePacked("Hello", "World"));

        return (hash1, hash2, hash3);
    }

    // Hash numbers
    function hashNumber(uint256 num) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(num));
    }

    // Hash address
    function hashAddress(address addr) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr));
    }

    // Hash multiple values
    function hashMultiple(
        address addr,
        uint256 amount,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr, amount, nonce));
    }

    // ============================================================================
    // 2. ABI.ENCODE VS ABI.ENCODEPACKED
    // ============================================================================

    function encodingComparison(
        address addr,
        uint256 amount
    )
        public
        pure
        returns (
            bytes memory encoded,
            bytes memory encodePacked,
            bytes32 hashEncoded,
            bytes32 hashEncodePacked
        )
    {
        // abi.encode: Pads to 32 bytes, includes type info
        encoded = abi.encode(addr, amount);
        hashEncoded = keccak256(encoded); // Safe, no collisions

        // abi.encodePacked: No padding, tightly packed
        // WARNING: Can cause hash collisions!
        encodePacked = abi.encodePacked(addr, amount); // Potential collisions
        hashEncodePacked = keccak256(encodePacked); // Potential collisions

        return (encoded, encodePacked, hashEncoded, hashEncodePacked);
    }

    // ⚠️ Hash collision with encodePacked
    function hashCollisionExample() public pure returns (bool) {
        // These produce THE SAME hash (collision!)
        bytes32 hash1 = keccak256(abi.encodePacked("aa", "bb"));
        bytes32 hash2 = keccak256(abi.encodePacked("a", "abb"));

        return hash1 == hash2; // true - DANGEROUS!
    }

    // ✅ Safe: Use abi.encode to prevent collisions
    function safeHashing() public pure returns (bool) {
        bytes32 hash1 = keccak256(abi.encode("aa", "bb"));
        bytes32 hash2 = keccak256(abi.encode("a", "abb"));

        return hash1 == hash2; // false - SAFE
    }

    // ============================================================================
    // 3. SHA256
    // ============================================================================
    // - Bitcoin uses SHA256
    // - Returns bytes32
    // - More expensive than keccak256 in EVM

    function sha256Examples()
        public
        pure
        returns (bytes32 hash1, bytes32 hash2)
    {
        hash1 = sha256("Hello World");
        hash2 = sha256(abi.encodePacked("Hello", "World"));

        return (hash1, hash2);
    }

    // ============================================================================
    // 4. RIPEMD160
    // ============================================================================
    // - Returns bytes20 (160 bits)
    // - Used in Bitcoin addresses
    // - Less common in Ethereum

    function ripemd160Examples() public pure returns (bytes20) {
        return ripemd160("Hello World");
    }

    // ============================================================================
    // 5. ECRECOVER - Signature Verification
    // ============================================================================
    // Recovers signer address from signature
    // Used for verifying signatures off-chain

    function recoverSigner(
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        // Recover the signer's address
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
    // 6. EIP-191 SIGNED DATA STANDARD
    // ============================================================================
    // Ethereum Signed Message standard
    // Prevents signatures being used across different contexts

    function getEthSignedMessageHash(
        bytes32 messageHash
    ) public pure returns (bytes32) {
        // Prefix: "\x19Ethereum Signed Message:\n32"
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    messageHash
                )
            );
    }

    function verifyEthSignedMessage(
        address signer,
        string memory message,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bool) {
        // 1. Hash the message
        bytes32 messageHash = keccak256(bytes(message));

        // 2. Create Ethereum Signed Message
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // 3. Recover signer
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);

        return recoveredSigner == signer;
    }

    // ============================================================================
    // 7. EIP-712 TYPED DATA SIGNING
    // ============================================================================
    // Structured data signing (more complex but safer)

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    function getDomainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes("MyContract")),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(this)
                )
            );
    }

    function getStructHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    nonce,
                    deadline
                )
            );
    }

    function getTypedDataHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 structHash = getStructHash(
            owner,
            spender,
            value,
            nonce,
            deadline
        );
        return
            keccak256(
                abi.encodePacked("\x19\x01", getDomainSeparator(), structHash)
            );
    }

    // ============================================================================
    // 8. MERKLE PROOFS
    // ============================================================================
    // Verify membership in a Merkle tree

    function verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == root;
    }

    // ============================================================================
    // 9. COMMIT-REVEAL SCHEME
    // ============================================================================
    // Two-phase process to prevent front-running

    mapping(address => bytes32) public commitments;
    mapping(address => bool) public revealed;

    // Phase 1: Commit
    function commit(bytes32 commitment) external {
        require(commitments[msg.sender] == bytes32(0), "Already committed");
        commitments[msg.sender] = commitment;
    }

    // Phase 2: Reveal
    function reveal(uint256 value, bytes32 salt) external {
        bytes32 commitment = keccak256(abi.encodePacked(value, salt));
        require(commitments[msg.sender] == commitment, "Invalid reveal");
        require(!revealed[msg.sender], "Already revealed");

        revealed[msg.sender] = true;
        // Process the revealed value
    }

    // Generate commitment (off-chain)
    function generateCommitment(
        uint256 value,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(value, salt));
    }

    // ============================================================================
    // 10. RANDOM NUMBER GENERATION
    // ============================================================================
    // ⚠️ WARNING: These are NOT truly random on blockchain!

    // BAD: Predictable randomness
    function badRandomness() public view returns (uint256) {
        // Miners can manipulate these values
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            );
    }

    // ✅ BETTER: Use Chainlink VRF or similar oracle
    // This is just a demonstration
    function betterRandomness(uint256 nonce) public view returns (uint256) {
        // Include more variables, but still not truly random
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender,
                        nonce,
                        blockhash(block.number - 1)
                    )
                )
            );
    }

    // ============================================================================
    // 11. PRACTICAL EXAMPLES
    // ============================================================================

    // Generate unique ID
    function generateUniqueId(
        address user,
        uint256 timestamp,
        uint256 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, timestamp, nonce));
    }

    // Verify whitelist proof
    mapping(bytes32 => bool) public whitelist;

    function addToWhitelist(address[] memory addresses) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            bytes32 hash = keccak256(abi.encodePacked(addresses[i]));
            whitelist[hash] = true;
        }
    }

    function isWhitelisted(address addr) external view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(addr));
        return whitelist[hash];
    }

    // Password verification (NEVER store plain passwords!)
    mapping(address => bytes32) private passwordHashes;

    function setPassword(string memory password, bytes32 salt) external {
        bytes32 hash = keccak256(abi.encodePacked(password, salt));
        passwordHashes[msg.sender] = hash;
    }

    function verifyPassword(
        string memory password,
        bytes32 salt
    ) external view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(password, salt));
        return passwordHashes[msg.sender] == hash;
    }

    // ============================================================================
    // 12. SIGNATURE SPLITTING
    // ============================================================================

    function splitSignature(
        bytes memory signature
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(signature.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // Adjust v if necessary
        if (v < 27) {
            v += 27;
        }

        return (v, r, s);
    }

    // ============================================================================
    // 13. HASH COMPARISON
    // ============================================================================

    function compareHashes()
        public
        pure
        returns (bool same1, bool same2, bool same3)
    {
        // String comparison using hashes
        same1 = keccak256(bytes("hello")) == keccak256(bytes("hello"));
        same2 = keccak256(bytes("hello")) == keccak256(bytes("world"));

        // Multiple values
        same3 =
            keccak256(abi.encode(1, 2, 3)) == keccak256(abi.encode(1, 2, 3));

        return (same1, same2, same3);
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. keccak256 is most common hash in Ethereum
    // 2. Use abi.encode (not encodePacked) to prevent hash collisions
    // 3. ecrecover verifies signatures, returns signer address
    // 4. EIP-191 for standard signed messages
    // 5. EIP-712 for structured typed data (safer, more complex)
    // 6. Merkle proofs for efficient membership verification
    // 7. Commit-reveal prevents front-running
    // 8. ⚠️ block.timestamp/difficulty NOT secure for randomness
    // 9. Use Chainlink VRF for true randomness
    // 10. Never store plain passwords, always hash with salt
    // 11. Signatures are 65 bytes: v (1 byte) + r (32 bytes) + s (32 bytes)
    // 12. sha256 and ripemd160 available but less common
    // 13. Hash collisions possible with abi.encodePacked
    // 14. Signature verification requires proper message formatting
    // 15. Domain separators prevent cross-contract signature replay
    // ============================================================================
}
