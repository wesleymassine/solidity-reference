# 🚀 Solidity Complete Reference
## From Zero to Professional Developer 

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?style=for-the-badge&logo=solidity)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Complete-success?style=for-the-badge)
![CI](https://img.shields.io/github/actions/workflow/status/wesleymassine/solidity-reference/ci.yml?style=for-the-badge&label=build)

> **The most comprehensive Solidity learning resource - 32 complete files covering 100% of professional development skills**

---

## 📖 About This Repository

This repository contains a complete, professional-grade Solidity reference covering everything from basic syntax to advanced optimization techniques. Each file is extensively commented in English with real-world examples, security warnings, and professional best practices.

**Perfect for:**
- 🎓 Complete beginners starting their blockchain journey
- 💻 Intermediate developers wanting to fill knowledge gaps
- 🏆 Professional developers seeking advanced optimization techniques
- 👨‍🏫 Educators looking for comprehensive teaching materials

---

## 📚 Complete File List

| # | File | Topics Covered | Level |
|---|------|----------------|-------|
| 1 | [DataTypes.sol](DataTypes.sol) | All Solidity data types with examples | Beginner |
| 2 | [Functions.sol](Functions.sol) | Complete function reference | Beginner |
| 3 | [Inheritance.sol](Inheritance.sol) | Inheritance, abstracts, interfaces | Intermediate |
| 4 | [Libraries.sol](Libraries.sol) | Library patterns and usage | Intermediate |
| 5 | [ControlFlow.sol](ControlFlow.sol) | Loops, conditionals, error handling | Beginner |
| 6 | [Globals.sol](Globals.sol) | Global variables, units, time | Beginner |
| 7 | [Operators.sol](Operators.sol) | All operators and expressions | Beginner |
| 8 | [EtherTransfer.sol](EtherTransfer.sol) | transfer/send/call methods | Intermediate |
| 9 | [DataLocation.sol](DataLocation.sol) | storage/memory/calldata | Intermediate |
| 10 | [Cryptography.sol](Cryptography.sol) | Hashing, signatures, verification | Advanced |
| 11 | [Assembly.sol](Assembly.sol) | Inline assembly (Yul) | Advanced |
| 12 | [Patterns.sol](Patterns.sol) | Design patterns | Advanced |
| 13 | [Security.sol](Security.sol) | Security & vulnerabilities | Advanced |
| 14 | [GasOptimization.sol](GasOptimization.sol) | Gas optimization techniques | Advanced |
| 15 | [Standards.sol](Standards.sol) | ERC20, ERC721, ERC1155, ERC2981 | Advanced |
| 16 | [Imports.sol](Imports.sol) | Project organization | Intermediate |
| 17 | [BestPractices.sol](BestPractices.sol) | ⭐ Bad vs Good code patterns (Senior) | Professional |
| 18 | [Testing.sol](Testing.sol) | Foundry testing: unit, fuzz, invariant, fork, ERC-4337 | Professional |
| 19 | [Deploy.sol](Deploy.sol) | Foundry scripts: deploy, verify, multisig, CI/CD, CREATE2 | Professional |
| 20 | [Integration.md](Integration.md) | Frontend: ethers.js v6, viem v2, wagmi, ERC-4337 gasless, SIWE | Professional |
| 21 | [DeFi.sol](DeFi.sol) | AMM math, flash loans, oracles, liquidations, MEV, governance | Professional |
| 22 | [L2.sol](L2.sol) | L2 architecture, opcode diffs, bridges, CCIP, LayerZero, zkSync | Professional |
| 23 | [FormalVerification.sol](FormalVerification.sol) | SMTChecker, Certora CVL, Echidna, Halmos, Gambit, invariant design | Professional |
| 24 | [Upgrades.sol](Upgrades.sol) | Transparent/UUPS/Beacon/Diamond proxies, ERC-7201, storage gaps, slashing, timelocks | Professional |
| 25 | [EIP7702.sol](EIP7702.sol) | EOA delegation (Pectra), session keys, EIP-1271, sponsored txs, vs ERC-4337 | Expert |
| 26 | [Intents.sol](Intents.sol) | Intent architecture, Dutch auction (UniswapX), solvers, ERC-7521, cross-chain (ERC-7683) | Expert |
| 27 | [RWA.sol](RWA.sol) | Real World Assets, ERC-3643/T-REX, identity registry, compliance modules, DvP, dividends | Expert |
| 28 | [ZKProofs.sol](ZKProofs.sol) | Groth16/PLONK/STARK, ZK coprocessors (Axiom/SP1), nullifiers, ZK airdrop, recursive proofs | Expert |
| 29 | [EigenLayer.sol](EigenLayer.sol) | Restaking, AVS design, operator registration, slashing conditions, EigenPod, rewards | Expert |
| 30 | [UniswapV4.sol](UniswapV4.sol) | Singleton PoolManager, hooks architecture, dynamic fees, TWAMM, limit orders, custom curves | Expert |
| 31 | [Governance.sol](Governance.sol) | Governor + TimelockController, proposal lifecycle, vetoGuardian, Snapshot hybrid, NFT voting | Expert |
| 32 | [Tokenomics.sol](Tokenomics.sol) | Vesting (cliff/linear), Merkle airdrop, bonding curves, staking rewards, veToken, buyback/burn | Expert |

📋 **See [README_ROADMAP.md](README_ROADMAP.md) for detailed learning path**

⚡ **See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands, patterns & quick lookup**

🏗️ **See [PROJECTS.md](PROJECTS.md) for hands-on practical projects**

🇧🇷 **See [BRASIL.md](BRASIL.md) for Brazilian developers guide** (Portuguese)

---

## 🎯 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/wesleymassine/solidity-reference.git
cd solidity-reference
```

### 2. Compile Everything (verified in CI)

All 31 `.sol` files compile with [Foundry](https://getfoundry.sh) and are checked on every push:

```bash
forge build          # compile all reference contracts
forge build --sizes  # also report deployed bytecode sizes
```

> Config lives in [foundry.toml](foundry.toml) (solc 0.8.28, `via_ir`, Cancun EVM). The files are self-contained — no external dependencies to install.

### 3. Choose Your Learning Path

**Beginner Path (4 weeks):**
```
DataTypes.sol → Operators.sol → ControlFlow.sol → Functions.sol → Globals.sol
```

**Intermediate Path (4 weeks):**
```
DataLocation.sol → Inheritance.sol → Libraries.sol → EtherTransfer.sol → Cryptography.sol
```

**Advanced Path (4 weeks):**
```
Assembly.sol → Patterns.sol → Security.sol → GasOptimization.sol → Standards.sol → BestPractices.sol
```

**Professional Path (3 weeks):**
```
Testing.sol → Deploy.sol → Integration.md → DeFi.sol → L2.sol → FormalVerification.sol
```

**Expert Path (3 weeks — 2025/2026 trends):**
```
Upgrades.sol → EIP7702.sol → Intents.sol → RWA.sol → ZKProofs.sol → EigenLayer.sol
→ UniswapV4.sol → Governance.sol → Tokenomics.sol
```

### 4. Study & Practice
- Open files in VS Code, Remix, or your favorite editor
- Read comments thoroughly
- Run examples in [Remix IDE](https://remix.ethereum.org)
- Modify code and experiment
- Build small projects using each concept

---

## 🇧🇷 Brazilian Community

This project now includes **complete resources for Brazilian developers**:
- 💼 Job boards for Web3 positions in Brazil
- 🤝 Portuguese-speaking communities
- 💰 Bounty & freelancing opportunities
- 🎓 Learning resources in Portuguese
- 🏆 Brazilian hackathons calendar

**See [BRASIL.md](BRASIL.md) for complete guide in Portuguese**

---

## 🌟 What Makes This Special

### ✨ Comprehensive Coverage
- **32 complete reference files** covering all Solidity concepts
- **Over 10,000 lines** of extensively commented code
- **150+ practical examples** demonstrating best practices
- **NEW: Bad vs Good code comparisons** for professional development

### 🔒 Security-First Approach
- Vulnerable vs secure code comparisons
- Real-world attack vectors explained
- Prevention techniques for all common vulnerabilities

### ⚡ Gas Optimization Focus
- Professional optimization techniques
- Before/after comparisons
- Gas cost analysis

### 📝 Professional Quality
- Production-ready code patterns
- Industry standard practices
- Real-world use cases

---

## 🛠️ Development Tools

| Tool | Purpose | Link |
|------|---------|------|
| Remix IDE | Quick testing & learning | [remix.ethereum.org](https://remix.ethereum.org) |
| Hardhat | Professional development | [hardhat.org](https://hardhat.org) |
| Foundry | Fast Solidity testing | [getfoundry.sh](https://getfoundry.sh) |
| VS Code | Code editing | [code.visualstudio.com](https://code.visualstudio.com) |
| Metamask | Wallet for testing | [metamask.io](https://metamask.io) |

### 🔍 Security & Audit Tools

| Tool | Purpose | Link |
|------|---------|------|
| Slither | Static analysis & vulnerability detection | [github.com/crytic/slither](https://github.com/crytic/slither) |
| Mythril | Security analysis tool | [github.com/ConsenSys/mythril](https://github.com/ConsenSys/mythril) |
| Echidna | Fuzzing & property testing | [github.com/crytic/echidna](https://github.com/crytic/echidna) |
| Manticore | Symbolic execution tool | [github.com/trailofbits/manticore](https://github.com/trailofbits/manticore) |
| Tenderly | Real-time monitoring & debugging | [tenderly.co](https://tenderly.co) |
| OpenZeppelin Defender | Security operations platform | [openzeppelin.com/defender](https://openzeppelin.com/defender) |

### ⚡ Gas Optimization Tools

| Tool | Purpose | Link |
|------|---------|------|
| hardhat-gas-reporter | Track gas usage in tests | [npm: hardhat-gas-reporter](https://www.npmjs.com/package/hardhat-gas-reporter) |
| Foundry Gas Snapshots | Compare gas usage across versions | Built into Foundry |
| eth-gas-reporter | Mocha reporter for gas costs | [npm: eth-gas-reporter](https://www.npmjs.com/package/eth-gas-reporter) |

---

## 📖 Learning Resources

### 📚 Official Documentation
- [Solidity Docs](https://docs.soliditylang.org) - Official language documentation
- [Ethereum.org Developer Docs](https://ethereum.org/en/developers/docs/) - Ethereum fundamentals
- [OpenZeppelin Docs](https://docs.openzeppelin.com/) - Security patterns & contracts
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/) - Security guide

### 🎮 Interactive Learning & Challenges
- [CryptoZombies](https://cryptozombies.io) - Interactive Solidity tutorial
- [Ethernaut](https://ethernaut.openzeppelin.com) - Security challenges (18 levels)
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz) - DeFi security challenges
- [Capture The Ether](https://capturetheether.com) - Security CTF challenges
- [Secureum Bootcamp](https://secureum.substack.com/) - Advanced security training

### 🎥 Video Courses (Professional Level)
- [Patrick Collins - Smart Contract Developer](https://www.youtube.com/@PatrickAlphaC) - Free comprehensive course
- [Smart Contract Programmer](https://www.youtube.com/@smartcontractprogrammer) - Advanced topics
- [Cyfrin Updraft](https://updraft.cyfrin.io/) - Free professional courses
- [Alchemy University](https://university.alchemy.com/) - Web3 development

### 📰 Newsletters & Blogs
- [Week in Ethereum](https://weekinethereumnews.com/) - Weekly updates
- [Immunefi Blog](https://medium.com/@immunefi) - Security & bug bounties
- [Trail of Bits Blog](https://blog.trailofbits.com/) - Security research
- [OpenZeppelin Blog](https://blog.openzeppelin.com/) - Best practices
- [Consensys Diligence](https://consensys.io/diligence/) - Audit reports

### 🔐 Security Resources
- [SWC Registry](https://swcregistry.io/) - Smart Contract Weakness Classification
- [Rekt News](https://rekt.news/) - DeFi hack analysis
- [Blockchain Threat Intelligence](https://newsletter.blockthreat.io/) - Security newsletter
- [Solodit](https://solodit.xyz/) - Audit report database
- [Code4rena](https://code4rena.com/) - Competitive audits

### 💼 Professional Development
- [ChainLink Documentation](https://docs.chain.link/) - Oracles & automation
- [The Graph Docs](https://thegraph.com/docs/) - Indexing & querying
- [IPFS Docs](https://docs.ipfs.tech/) - Decentralized storage
- [Uniswap V3 Book](https://uniswapv3book.com/) - DeFi protocol deep dive
- [MEV Research](https://www.flashbots.net/) - MEV & transaction ordering

### 🏢 Audit Firms & Research
- [Trail of Bits](https://www.trailofbits.com/) - Security auditing
- [OpenZeppelin](https://www.openzeppelin.com/security-audits) - Smart contract audits
- [Consensys Diligence](https://consensys.io/diligence/) - Security services
- [ChainSecurity](https://chainsecurity.com/) - Audits & tools
- [Certora](https://www.certora.com/) - Formal verification

### 👥 Communities
- [Ethereum Stack Exchange](https://ethereum.stackexchange.com) - Q&A platform
- [r/ethdev](https://reddit.com/r/ethdev) - Reddit community
- [Discord: Foundry](https://discord.gg/foundry) - Foundry support
- [Discord: Hardhat](https://discord.gg/hardhat) - Hardhat support
- [Twitter/X](https://twitter.com) - Follow: #Solidity #EthDev #SmartContracts

### 🎯 Next Steps After This Repository

1. **Build Real Projects**: Token, NFT marketplace, DAO, DeFi protocol
2. **Participate in Audits**: Code4rena, Sherlock, Immunefi
3. **Read Audit Reports**: Study how professionals find vulnerabilities
4. **Contribute to Open Source**: OpenZeppelin, Aave, Uniswap
5. **Stay Updated**: Follow Ethereum Improvement Proposals (EIPs)
6. **Network**: Join Discord/Telegram groups, attend ETHGlobal hackathons

---

## 🎓 Topics Covered

<details>
<summary><b>Data Types & Basics</b></summary>

- Boolean, integers, addresses
- Fixed-size arrays, dynamic arrays
- Strings, bytes
- Mappings, structs, enums
- Constants, immutables
</details>

<details>
<summary><b>Functions & Control Flow</b></summary>

- Function visibility (public, private, external, internal)
- State mutability (pure, view, payable)
- Modifiers, events, errors
- Loops, conditionals
- Error handling (require, assert, revert, try-catch)
</details>

<details>
<summary><b>Advanced Concepts</b></summary>

- Inheritance patterns
- Abstract contracts & interfaces
- Libraries & using for
- Storage, memory, calldata
- Inline assembly (Yul)
</details>

<details>
<summary><b>Security & Best Practices</b></summary>

- Reentrancy protection
- Access control patterns
- Front-running prevention
- Signature verification
- Common vulnerabilities
</details>

<details>
<summary><b>Gas Optimization</b></summary>

- Storage packing
- Calldata optimization
- Loop techniques
- Batch operations
- Assembly optimization
</details>

<details>
<summary><b>Standards & Patterns</b></summary>

- ERC20, ERC721, ERC1155
- Factory pattern
- Proxy/Upgradeable contracts
- Design patterns
- Project organization
</details>

---

## 💡 Professional Checklist

After completing this reference, you will be able to:

- ✅ Write secure, production-ready smart contracts
- ✅ Implement all major token standards (ERC20, ERC721, ERC1155)
- ✅ Optimize contracts for minimal gas costs
- ✅ Prevent common security vulnerabilities
- ✅ Use advanced patterns (proxy, factory, etc.)
- ✅ Write comprehensive tests
- ✅ Deploy to mainnet confidently
- ✅ Perform code reviews
- ✅ Read and understand complex protocols

---

## 🤝 Contributing

Contributions are welcome! If you find any issues or have suggestions:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -m 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- OpenZeppelin for security patterns
- Solidity documentation team
- Ethereum developer community
- All contributors to this repository

---

## 📊 Stats

- **32 Complete Files** (NEW: Upgrades.sol, EIP7702.sol, Intents.sol, RWA.sol, ZKProofs.sol, EigenLayer.sol, UniswapV4.sol, Governance.sol, Tokenomics.sol)
- **22,000+ Lines of Code**
- **150+ Examples**
- **15+ Design Patterns**
- **20+ Security Topics**
- **50+ Gas Optimization Techniques**
- **15+ Bad vs Good Pattern Comparisons**
- **15+ Practical Projects** (Beginner to Professional)
- **ERC-4337 Account Abstraction** (2024/2026)
- **EIP-7702 EOA Delegation** (Pectra 2025)
- **Intent-based transactions** (UniswapX / ERC-7521 / ERC-7683)
- **Real World Assets** (ERC-3643 T-REX, DvP settlement)
- **ZK Proofs & Coprocessors** (Groth16, SP1, Axiom)
- **EigenLayer Restaking & AVS** (operators, slashing, EigenPods)
- **Foundry Testing: unit, fuzz, invariant, fork**
- **Brazilian Community Resources** 🇧🇷

---

## 🌐 Connect

- **Issues**: [GitHub Issues](https://github.com/wesleymassine/solidity-reference/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wesleymassine/solidity-reference/discussions)

---

<div align="center">

**⭐ If this repository helps you, please give it a star! ⭐**

Made with ❤️ for the Ethereum developer community 🇧🇷

---

“This repo is a learning/reference resource (not audited production contracts).

</div>
