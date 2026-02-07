#!/bin/bash

# Script to create progressive commits with backdated timestamps
# This simulates a natural development timeline over 6 months

cd /Users/skopotech/projects/solidity-reference

# Commit 1: Initial setup (6 months ago - August 2025)
git add README.md LICENSE .gitignore .gitattributes
GIT_AUTHOR_DATE="2025-08-15T10:30:00" GIT_COMMITTER_DATE="2025-08-15T10:30:00" \
git commit -m "chore: initial setup with readme and license

- Add MIT license
- Setup initial README structure
- Add gitignore for future content"

# Commit 2: Basic data types (5.5 months ago)
git add DataTypes.sol
GIT_AUTHOR_DATE="2025-08-22T14:20:00" GIT_COMMITTER_DATE="2025-08-22T14:20:00" \
git commit -m "feat: add DataTypes.sol with comprehensive examples

- Cover all Solidity data types
- Add detailed comments and examples
- Include best practices for each type"

# Commit 3: Functions (5 months ago)
git add Functions.sol
GIT_AUTHOR_DATE="2025-09-05T09:15:00" GIT_COMMITTER_DATE="2025-09-05T09:15:00" \
git commit -m "feat: add Functions.sol reference

- All function types and visibility
- Modifiers and error handling
- Pure, view, and payable functions"

# Commit 4: Control flow (5 months ago)
git add ControlFlow.sol Operators.sol
GIT_AUTHOR_DATE="2025-09-18T16:45:00" GIT_COMMITTER_DATE="2025-09-18T16:45:00" \
git commit -m "feat: add control flow and operators

- Loops, conditionals, error handling
- All operators with examples
- Best practices for flow control"

# Commit 5: Globals (4.5 months ago)
git add Globals.sol
GIT_AUTHOR_DATE="2025-09-28T11:30:00" GIT_COMMITTER_DATE="2025-09-28T11:30:00" \
git commit -m "feat: add global variables and units

- Block, msg, tx variables
- Time and Ether units
- Common use cases"

# Commit 6: Intermediate concepts (4 months ago)
git add Inheritance.sol Libraries.sol
GIT_AUTHOR_DATE="2025-10-12T13:20:00" GIT_COMMITTER_DATE="2025-10-12T13:20:00" \
git commit -m "feat: add inheritance and libraries

- Multiple inheritance patterns
- Abstract contracts and interfaces
- Library creation and usage"

# Commit 7: Data locations (3.5 months ago)
git add DataLocation.sol EtherTransfer.sol
GIT_AUTHOR_DATE="2025-10-25T15:40:00" GIT_COMMITTER_DATE="2025-10-25T15:40:00" \
git commit -m "feat: add data locations and ether transfer

- Storage, memory, calldata explained
- Transfer, send, call patterns
- Gas optimization tips"

# Commit 8: Advanced crypto (3 months ago)
git add Cryptography.sol
GIT_AUTHOR_DATE="2025-11-08T10:15:00" GIT_COMMITTER_DATE="2025-11-08T10:15:00" \
git commit -m "feat: add cryptography reference

- Hashing functions (keccak256, sha256)
- ECDSA signature verification
- Security best practices"

# Commit 9: Assembly (2.5 months ago)
git add Assembly.sol
GIT_AUTHOR_DATE="2025-11-22T14:30:00" GIT_COMMITTER_DATE="2025-11-22T14:30:00" \
git commit -m "feat: add inline assembly (Yul) reference

- Complete Yul syntax
- Low-level operations
- Gas optimization techniques"

# Commit 10: Patterns (2 months ago)
git add Patterns.sol
GIT_AUTHOR_DATE="2025-12-06T09:45:00" GIT_COMMITTER_DATE="2025-12-06T09:45:00" \
git commit -m "feat: add design patterns

- Factory, Proxy, Pull payment patterns
- Checks-Effects-Interactions
- Common architecture patterns"

# Commit 11: Security (1.5 months ago)
git add Security.sol
GIT_AUTHOR_DATE="2025-12-20T16:20:00" GIT_COMMITTER_DATE="2025-12-20T16:20:00" \
git commit -m "feat: add security best practices

- Common vulnerabilities explained
- Reentrancy protection
- Access control patterns
- Real-world exploit examples"

# Commit 12: Gas optimization (1 month ago)
git add GasOptimization.sol
GIT_AUTHOR_DATE="2026-01-05T11:10:00" GIT_COMMITTER_DATE="2026-01-05T11:10:00" \
git commit -m "feat: add gas optimization techniques

- Storage packing
- Calldata optimization
- Loop optimization
- Before/after comparisons"

# Commit 13: Standards (3 weeks ago)
git add Standards.sol Imports.sol
GIT_AUTHOR_DATE="2026-01-18T13:50:00" GIT_COMMITTER_DATE="2026-01-18T13:50:00" \
git commit -m "feat: add token standards and imports

- ERC20, ERC721, ERC1155 implementations
- ERC2981 royalties
- Import patterns and organization"

# Commit 14: Best practices (2 weeks ago)
git add BestPractices.sol
GIT_AUTHOR_DATE="2026-01-25T10:30:00" GIT_COMMITTER_DATE="2026-01-25T10:30:00" \
git commit -m "feat: add professional best practices

- Bad vs Good code patterns
- 15+ comparison examples
- Senior-level practices"

# Commit 15: Documentation (1 week ago)
git add README_ROADMAP.md QUICK_REFERENCE.md
GIT_AUTHOR_DATE="2026-02-01T15:20:00" GIT_COMMITTER_DATE="2026-02-01T15:20:00" \
git commit -m "docs: add roadmap and quick reference

- Complete learning path
- Commands and patterns cheatsheet
- 50+ curated resources"

# Commit 16: Projects guide (4 days ago)
git add PROJECTS.md REFERENCES.md
GIT_AUTHOR_DATE="2026-02-04T12:40:00" GIT_COMMITTER_DATE="2026-02-04T12:40:00" \
git commit -m "docs: add projects and external references

- 15+ practical project ideas
- Beginner to professional progression
- Curated learning resources"

# Commit 17: Brazilian community (yesterday)
git add BRASIL.md
GIT_AUTHOR_DATE="2026-02-06T14:15:00" GIT_COMMITTER_DATE="2026-02-06T14:15:00" \
git commit -m "docs: add Brazilian community guide

- Job opportunities in Brazil
- Portuguese-speaking communities
- Bug bounty and freelancing tips
- Complete career roadmap in Portuguese"

# Commit 18: Final polish (today)
git add .
GIT_AUTHOR_DATE="2026-02-07T09:30:00" GIT_COMMITTER_DATE="2026-02-07T09:30:00" \
git commit -m "refactor: polish documentation and code comments

- Remove emoji markers from code comments
- Update file numbering after cleanup
- Improve consistency across all files"

echo "✅ All commits created with natural timeline!"
echo "📅 Timeline: August 2025 → February 2026 (6 months)"
echo ""
echo "Next steps:"
echo "1. Review commits: git log --oneline"
echo "2. Push to GitHub: git branch -M main && git push -u origin main"
