# Frontend Integration — ethers.js & viem

Complete reference for connecting smart contracts to frontend applications.
All examples use the contracts from this repository as the target.

---

## Table of Contents

1. [Stack Overview](#1-stack-overview)
2. [Project Setup](#2-project-setup)
3. [Connecting to a Wallet](#3-connecting-to-a-wallet)
4. [Reading Contract State](#4-reading-contract-state)
5. [Writing to Contracts (Transactions)](#5-writing-to-contracts-transactions)
6. [Listening to Events](#6-listening-to-events)
7. [ABI Encoding & Decoding](#7-abi-encoding--decoding)
8. [ERC-20 Integration](#8-erc-20-integration)
9. [ERC-721 Integration](#9-erc-721-integration)
10. [ERC-1155 Integration](#10-erc-1155-integration)
11. [ERC-4337 — Gasless Transactions](#11-erc-4337--gasless-transactions)
12. [Multicall — Batch Reads](#12-multicall--batch-reads)
13. [Error Handling](#13-error-handling)
14. [Signing Messages & Typed Data (EIP-712)](#14-signing-messages--typed-data-eip-712)
15. [SIWE — Sign-In With Ethereum](#15-siwe--sign-in-with-ethereum)
16. [Simulating Transactions](#16-simulating-transactions)
17. [Gas Estimation](#17-gas-estimation)
18. [Testing Frontend Integrations](#18-testing-frontend-integrations)
19. [Security Best Practices](#19-security-best-practices)
20. [Tooling & Ecosystem Cheatsheet](#20-tooling--ecosystem-cheatsheet)

---

## 1. Stack Overview

| Layer | ethers.js v6 | viem v2 | Notes |
|-------|-------------|---------|-------|
| Philosophy | Class-based, batteries-included | Functional, tree-shakeable | viem has zero dependencies |
| TypeScript | Good | Excellent (type-safe ABIs) | viem generates types from ABI |
| Bundle size | ~130KB gzip | ~35KB gzip | viem wins for SPAs |
| Wagmi | v1 (legacy) | v2 (default) | wagmi wraps viem for React |
| Learning curve | Easier | Slightly steeper | Both excellent docs |
| Performance | Good | Better (uses native BigInt) | Both sufficient for most apps |

**Recommendation (2025+):**
- New projects → **viem + wagmi**
- Existing ethers.js projects → stay on ethers.js v6
- Node.js scripts/bots → either works; viem preferred for type safety

---

## 2. Project Setup

### ethers.js v6

```bash
npm install ethers
# or
pnpm add ethers
```

```ts
import { ethers } from "ethers";

// Browser wallet (MetaMask, Rabby, etc.)
const provider = new ethers.BrowserProvider(window.ethereum);
const signer   = await provider.getSigner();

// Read-only RPC provider
const readProvider = new ethers.JsonRpcProvider(process.env.NEXT_PUBLIC_RPC_URL);

// WebSocket provider (for event subscriptions)
const wsProvider = new ethers.WebSocketProvider(process.env.NEXT_PUBLIC_WS_URL);
```

### viem v2 + wagmi v2

```bash
npm install viem wagmi @tanstack/react-query
```

```ts
// config.ts
import { createConfig, http } from "wagmi";
import { mainnet, sepolia, arbitrum, base } from "wagmi/chains";

export const config = createConfig({
  chains: [mainnet, sepolia, arbitrum, base],
  transports: {
    [mainnet.id]:  http(process.env.NEXT_PUBLIC_MAINNET_RPC),
    [sepolia.id]:  http(process.env.NEXT_PUBLIC_SEPOLIA_RPC),
    [arbitrum.id]: http(process.env.NEXT_PUBLIC_ARBITRUM_RPC),
    [base.id]:     http(process.env.NEXT_PUBLIC_BASE_RPC),
  },
});
```

```tsx
// app/providers.tsx
"use client";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { config } from "./config";

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

---

## 3. Connecting to a Wallet

### ethers.js v6

```ts
// Request wallet connection
async function connectWallet() {
  if (!window.ethereum) throw new Error("No wallet found");

  const provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  const signer  = await provider.getSigner();
  const address = await signer.getAddress();
  const network = await provider.getNetwork();

  console.log("Connected:", address);
  console.log("Chain ID:", network.chainId);

  return { provider, signer, address };
}

// Switch to a specific chain
async function switchChain(chainId: number) {
  await window.ethereum.request({
    method: "wallet_switchEthereumChain",
    params: [{ chainId: `0x${chainId.toString(16)}` }],
  });
}

// Add a chain if not present (e.g., Arbitrum)
async function addArbitrum() {
  await window.ethereum.request({
    method: "wallet_addEthereumChain",
    params: [{
      chainId:         "0xa4b1",
      chainName:       "Arbitrum One",
      nativeCurrency:  { name: "ETH", symbol: "ETH", decimals: 18 },
      rpcUrls:         ["https://arb1.arbitrum.io/rpc"],
      blockExplorerUrls: ["https://arbiscan.io"],
    }],
  });
}
```

### viem + wagmi (React)

```tsx
import { useConnect, useDisconnect, useAccount, useSwitchChain } from "wagmi";
import { injected, walletConnect } from "wagmi/connectors";

function ConnectButton() {
  const { connect, connectors } = useConnect();
  const { disconnect }          = useDisconnect();
  const { address, isConnected, chainId } = useAccount();
  const { switchChain }         = useSwitchChain();

  if (isConnected) {
    return (
      <div>
        <p>Connected: {address}</p>
        <p>Chain: {chainId}</p>
        <button onClick={() => switchChain({ chainId: 1 })}>Switch to Mainnet</button>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    );
  }

  return (
    <div>
      {connectors.map((connector) => (
        <button key={connector.id} onClick={() => connect({ connector })}>
          Connect with {connector.name}
        </button>
      ))}
    </div>
  );
}
```

---

## 4. Reading Contract State

### ethers.js v6

```ts
import { ethers } from "ethers";
import { ERC20_ABI } from "./abis"; // generated from forge build

const TOKEN_ADDRESS = "0x...";

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const token    = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, provider);

// Single call
const totalSupply: bigint = await token.totalSupply();
const balance: bigint     = await token.balanceOf("0x...");
const name: string        = await token.name();
const decimals: number    = await token.decimals();

// Format for display
const formatted = ethers.formatUnits(balance, decimals);
console.log(`Balance: ${formatted} ${await token.symbol()}`);

// Read with block override (historical state)
const historicBalance = await token.balanceOf("0x...", { blockTag: 18_000_000 });
```

### viem v2

```ts
import { createPublicClient, http, formatUnits } from "viem";
import { mainnet } from "viem/chains";
import { erc20Abi } from "viem"; // built-in standard ABIs

const TOKEN_ADDRESS = "0x..." as `0x${string}`;

const client = createPublicClient({
  chain:     mainnet,
  transport: http(process.env.RPC_URL),
});

// Single call
const totalSupply = await client.readContract({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  functionName: "totalSupply",
});

const balance = await client.readContract({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  functionName: "balanceOf",
  args:         ["0x..." as `0x${string}`],
});

// Read at historical block
const historicBalance = await client.readContract({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  functionName: "balanceOf",
  args:         ["0x..." as `0x${string}`],
  blockNumber:  18_000_000n,
});
```

### wagmi React Hook (viem under the hood)

```tsx
import { useReadContract, useReadContracts } from "wagmi";
import { erc20Abi } from "viem";
import { formatUnits } from "viem";

const TOKEN = { address: "0x..." as `0x${string}`, abi: erc20Abi };

function TokenInfo({ userAddress }: { userAddress: `0x${string}` }) {
  // Batch multiple reads in a single hook call
  const { data, isLoading, error } = useReadContracts({
    contracts: [
      { ...TOKEN, functionName: "name" },
      { ...TOKEN, functionName: "symbol" },
      { ...TOKEN, functionName: "decimals" },
      { ...TOKEN, functionName: "totalSupply" },
      { ...TOKEN, functionName: "balanceOf", args: [userAddress] },
    ],
  });

  if (isLoading) return <p>Loading...</p>;
  if (error)     return <p>Error: {error.message}</p>;

  const [name, symbol, decimals, totalSupply, balance] = data!;

  return (
    <div>
      <h2>{name.result} ({symbol.result})</h2>
      <p>Total Supply: {formatUnits(totalSupply.result!, decimals.result!)}</p>
      <p>Your Balance: {formatUnits(balance.result!, decimals.result!)}</p>
    </div>
  );
}
```

---

## 5. Writing to Contracts (Transactions)

### ethers.js v6

```ts
const provider = new ethers.BrowserProvider(window.ethereum);
const signer   = await provider.getSigner();
const token    = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, signer);

// Send transaction
const tx = await token.transfer("0xRecipient...", ethers.parseUnits("100", 18));

console.log("Tx hash:", tx.hash);

// Wait for confirmation
const receipt = await tx.wait(1); // 1 confirmation
console.log("Block:", receipt!.blockNumber);
console.log("Gas used:", receipt!.gasUsed);

// With custom gas settings
const txOverrides = await token.transfer("0xRecipient...", ethers.parseUnits("100", 18), {
  gasLimit:             BigInt(100_000),
  maxFeePerGas:         ethers.parseUnits("30", "gwei"),
  maxPriorityFeePerGas: ethers.parseUnits("1",  "gwei"),
});

// Send ETH directly
const ethTx = await signer.sendTransaction({
  to:    "0xRecipient...",
  value: ethers.parseEther("0.1"),
});
```

### viem v2

```ts
import { createWalletClient, createPublicClient, custom, parseUnits } from "viem";
import { mainnet } from "viem/chains";

const walletClient = createWalletClient({
  chain:     mainnet,
  transport: custom(window.ethereum),
});

const [account] = await walletClient.getAddresses();

// Write to contract
const txHash = await walletClient.writeContract({
  address:      TOKEN_ADDRESS,
  abi:          ERC20_ABI,
  functionName: "transfer",
  args:         ["0xRecipient..." as `0x${string}`, parseUnits("100", 18)],
  account,
});

// Wait for receipt
const publicClient = createPublicClient({ chain: mainnet, transport: http() });
const receipt      = await publicClient.waitForTransactionReceipt({ hash: txHash });

console.log("Status:", receipt.status); // "success" | "reverted"
console.log("Gas used:", receipt.gasUsed);
```

### wagmi React Hook

```tsx
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { erc20Abi, parseUnits } from "viem";

function TransferButton({ recipient, amount }: { recipient: `0x${string}`; amount: string }) {
  const { writeContract, data: txHash, isPending, error } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const handleTransfer = () => {
    writeContract({
      address:      TOKEN_ADDRESS,
      abi:          erc20Abi,
      functionName: "transfer",
      args:         [recipient, parseUnits(amount, 18)],
    });
  };

  return (
    <div>
      <button onClick={handleTransfer} disabled={isPending || isConfirming}>
        {isPending     ? "Waiting for wallet..." :
         isConfirming  ? "Confirming..."         :
         "Transfer"}
      </button>

      {txHash    && <p>Tx: {txHash}</p>}
      {isSuccess && <p>Transfer confirmed!</p>}
      {error     && <p>Error: {error.message}</p>}
    </div>
  );
}
```

---

## 6. Listening to Events

### ethers.js v6

```ts
const token = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, provider);

// Listen to all Transfer events
token.on("Transfer", (from, to, value, event) => {
  console.log("Transfer:", {
    from,
    to,
    value: ethers.formatUnits(value, 18),
    block: event.log.blockNumber,
    hash:  event.log.transactionHash,
  });
});

// Listen to filtered events (only transfers TO a specific address)
const filter = token.filters.Transfer(null, "0xMyAddress...");
token.on(filter, (from, to, value) => {
  console.log(`Received ${ethers.formatUnits(value, 18)} tokens from ${from}`);
});

// Stop listening
token.removeAllListeners("Transfer");

// Query historical events
const pastEvents = await token.queryFilter(
  token.filters.Transfer(),
  18_000_000,   // fromBlock
  18_100_000    // toBlock
);

pastEvents.forEach((e) => {
  const decoded = e as ethers.EventLog;
  console.log(decoded.args.from, "->", decoded.args.to, decoded.args.value);
});
```

### viem v2

```ts
// Subscribe to live events (WebSocket)
const wsClient = createPublicClient({
  chain:     mainnet,
  transport: webSocket(process.env.WS_RPC_URL),
});

const unwatch = wsClient.watchContractEvent({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  eventName:    "Transfer",
  onLogs: (logs) => {
    logs.forEach((log) => {
      console.log("Transfer:", log.args.from, "->", log.args.to, log.args.value);
    });
  },
});

// Stop watching
unwatch();

// Query historical logs
const logs = await publicClient.getContractEvents({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  eventName:    "Transfer",
  fromBlock:    18_000_000n,
  toBlock:      18_100_000n,
  args: {
    to: "0xMyAddress..." as `0x${string}`, // filter by indexed argument
  },
});
```

### wagmi React Hook

```tsx
import { useWatchContractEvent } from "wagmi";

function TransferListener() {
  useWatchContractEvent({
    address:   TOKEN_ADDRESS,
    abi:       erc20Abi,
    eventName: "Transfer",
    onLogs: (logs) => {
      console.log("New transfers:", logs);
    },
  });

  return <p>Listening for transfers...</p>;
}
```

---

## 7. ABI Encoding & Decoding

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
import { ethers, AbiCoder } from "ethers";

const coder = AbiCoder.defaultAbiCoder();

// Encode function call
const iface    = new ethers.Interface(ERC20_ABI);
const calldata = iface.encodeFunctionData("transfer", ["0xRecipient...", ethers.parseUnits("100", 18)]);

// Decode function result
const result   = iface.decodeFunctionResult("balanceOf", "0x...(raw bytes)...");

// Encode/decode raw types
const encoded  = coder.encode(["address", "uint256"], ["0x...", 100n]);
const decoded  = coder.decode(["address", "uint256"], encoded);

// Parse a transaction's calldata
const parsed   = iface.parseTransaction({ data: "0x...", value: 0n });
console.log("Function:", parsed?.name);
console.log("Args:",     parsed?.args);

// Get function selector
const selector = iface.getFunction("transfer")!.selector; // "0xa9059cbb"

// ─── viem v2 ────────────────────────────────────────────────
import { encodeFunctionData, decodeFunctionResult, encodeAbiParameters, decodeAbiParameters, toFunctionSelector } from "viem";

// Encode function call
const calldata2 = encodeFunctionData({
  abi:          erc20Abi,
  functionName: "transfer",
  args:         ["0xRecipient..." as `0x${string}`, parseUnits("100", 18)],
});

// Decode result
const [balance] = decodeFunctionResult({
  abi:          erc20Abi,
  functionName: "balanceOf",
  data:         "0x...",
});

// Encode raw ABI types
const encoded2 = encodeAbiParameters(
  [{ type: "address" }, { type: "uint256" }],
  ["0x..." as `0x${string}`, 100n]
);

// Function selector
const selector2 = toFunctionSelector("transfer(address,uint256)"); // "0xa9059cbb"
```

---

## 8. ERC-20 Integration

Complete pattern for an ERC-20 approve → action flow (e.g., staking, DEX swap):

```tsx
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { erc20Abi, parseUnits, maxUint256 } from "viem";

const TOKEN    = "0xTokenAddress..."   as `0x${string}`;
const SPENDER  = "0xProtocolAddress..." as `0x${string}`;
const DECIMALS = 18;

function ApproveAndStake({ amount }: { amount: string }) {
  const { address } = useAccount();
  const parsedAmount = parseUnits(amount, DECIMALS);

  // Read current allowance
  const { data: allowance } = useReadContract({
    address:      TOKEN,
    abi:          erc20Abi,
    functionName: "allowance",
    args:         [address!, SPENDER],
    query: { enabled: !!address },
  });

  const needsApproval = allowance !== undefined && allowance < parsedAmount;

  // Approve tx
  const { writeContract: approve, data: approveTxHash, isPending: isApproving } = useWriteContract();
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash });

  // Stake tx
  const { writeContract: stake, data: stakeTxHash, isPending: isStaking } = useWriteContract();
  const { isSuccess: stakeConfirmed } = useWaitForTransactionReceipt({ hash: stakeTxHash });

  const handleApprove = () => {
    approve({
      address:      TOKEN,
      abi:          erc20Abi,
      functionName: "approve",
      args:         [SPENDER, maxUint256], // infinite approval (use carefully)
    });
  };

  const handleStake = () => {
    stake({
      address:      SPENDER,
      abi:          STAKING_ABI,
      functionName: "stake",
      args:         [parsedAmount],
    });
  };

  return (
    <div>
      {needsApproval ? (
        <button onClick={handleApprove} disabled={isApproving}>
          {isApproving ? "Approving..." : "Approve Token"}
        </button>
      ) : (
        <button onClick={handleStake} disabled={isStaking}>
          {isStaking ? "Staking..." : "Stake"}
        </button>
      )}
      {approveConfirmed && <p>Approved! Now stake.</p>}
      {stakeConfirmed   && <p>Staked successfully!</p>}
    </div>
  );
}
```

---

## 9. ERC-721 Integration

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
const nft = new ethers.Contract(NFT_ADDRESS, ERC721_ABI, provider);

// Read NFT metadata
const owner     = await nft.ownerOf(1n);
const tokenURI  = await nft.tokenURI(1n);
const balance   = await nft.balanceOf("0xOwner...");

// Fetch and display metadata from tokenURI (IPFS or HTTP)
const response  = await fetch(tokenURI.replace("ipfs://", "https://ipfs.io/ipfs/"));
const metadata  = await response.json();
// { name, description, image, attributes }

// Transfer NFT
const signer = await provider.getSigner();
const nftWithSigner = nft.connect(signer);
const tx = await nftWithSigner["safeTransferFrom(address,address,uint256)"](
  owner, "0xRecipient...", 1n
);

// ─── wagmi React Hook ───────────────────────────────────────
import { useReadContracts } from "wagmi";
import { erc721Abi } from "viem";

function NFTCard({ tokenId }: { tokenId: bigint }) {
  const { data } = useReadContracts({
    contracts: [
      { address: NFT_ADDRESS, abi: erc721Abi, functionName: "ownerOf",  args: [tokenId] },
      { address: NFT_ADDRESS, abi: erc721Abi, functionName: "tokenURI", args: [tokenId] },
    ],
  });

  const owner    = data?.[0].result as `0x${string}`;
  const tokenURI = data?.[1].result as string;

  // Resolve IPFS URIs to HTTP gateways
  const imageURL = tokenURI?.replace("ipfs://", "https://ipfs.io/ipfs/");

  return (
    <div>
      <p>Token ID: {tokenId.toString()}</p>
      <p>Owner: {owner}</p>
      <img src={imageURL} alt={`NFT #${tokenId}`} />
    </div>
  );
}
```

---

## 10. ERC-1155 Integration

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
const multi = new ethers.Contract(ERC1155_ADDRESS, ERC1155_ABI, provider);

// Read balances
const balance = await multi.balanceOf("0xOwner...", 1n);

// Read multiple balances at once (balanceOfBatch)
const owners  = ["0xAlice...", "0xBob...", "0xCharlie..."];
const ids     = [1n, 2n, 3n];
const balances = await multi.balanceOfBatch(owners, ids);

// Transfer single token type
const signer   = await provider.getSigner();
const tx = await multi.connect(signer).safeTransferFrom(
  "0xFrom...",
  "0xTo...",
  1n,      // token id
  10n,     // amount
  "0x"     // data
);

// Batch transfer
const tx2 = await multi.connect(signer).safeBatchTransferFrom(
  "0xFrom...",
  "0xTo...",
  [1n, 2n, 3n],     // ids
  [10n, 20n, 5n],   // amounts
  "0x"
);
```

---

## 11. ERC-4337 — Gasless Transactions

Integrate account abstraction so users pay no gas (or pay in ERC-20):

```ts
// Using permissionless.js (built on viem) — simplest ERC-4337 integration
// npm install permissionless

import {
  createSmartAccountClient,
  ENTRYPOINT_ADDRESS_V07,
} from "permissionless";
import { signerToSimpleSmartAccount } from "permissionless/accounts";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { createPublicClient, http } from "viem";
import { sepolia } from "viem/chains";

const publicClient = createPublicClient({ chain: sepolia, transport: http() });

// Pimlico = bundler + paymaster service
const pimlicoClient = createPimlicoClient({
  transport: http(`https://api.pimlico.io/v2/sepolia/rpc?apikey=${PIMLICO_API_KEY}`),
  entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create smart account from an EOA signer
const smartAccount = await signerToSimpleSmartAccount(publicClient, {
  signer:     viemSigner,       // e.g., from wagmi's useWalletClient
  entryPoint: ENTRYPOINT_ADDRESS_V07,
  factoryAddress: "0x...",
});

const smartAccountClient = createSmartAccountClient({
  account:           smartAccount,
  chain:             sepolia,
  bundlerTransport:  http(`https://api.pimlico.io/v2/sepolia/rpc?apikey=${PIMLICO_API_KEY}`),
  middleware: {
    // Paymaster: sponsor gas for the user
    sponsorUserOperation: pimlicoClient.sponsorUserOperation,
  },
});

// Send a gasless transaction — user pays no ETH
const txHash = await smartAccountClient.sendTransaction({
  to:    TOKEN_ADDRESS as `0x${string}`,
  data:  encodeFunctionData({
    abi:          erc20Abi,
    functionName: "transfer",
    args:         ["0xRecipient...", parseUnits("100", 18)],
  }),
});
```

---

## 12. Multicall — Batch Reads

Read dozens of contract values in a single RPC call using Multicall3:

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
import { ethers } from "ethers";

const MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11";
const MULTICALL3_ABI = [
  "function aggregate3(tuple(address target, bool allowFailure, bytes callData)[] calls) returns (tuple(bool success, bytes returnData)[] results)"
];

const multi   = new ethers.Contract(MULTICALL3, MULTICALL3_ABI, provider);
const iface   = new ethers.Interface(erc20Abi);
const targets = ["0xTokenA...", "0xTokenB...", "0xTokenC..."];

const calls = targets.map((addr) => ({
  target:       addr,
  allowFailure: true,
  callData:     iface.encodeFunctionData("totalSupply", []),
}));

const results = await multi.aggregate3(calls);

results.forEach(({ success, returnData }, i) => {
  if (success) {
    const [supply] = iface.decodeFunctionResult("totalSupply", returnData);
    console.log(`${targets[i]}: ${ethers.formatEther(supply)}`);
  }
});

// ─── viem v2 (built-in multicall) ───────────────────────────
const results2 = await publicClient.multicall({
  contracts: targets.map((address) => ({
    address:      address as `0x${string}`,
    abi:          erc20Abi,
    functionName: "totalSupply" as const,
  })),
  allowFailure: true,
});

// ─── wagmi React Hook ───────────────────────────────────────
const { data } = useReadContracts({
  contracts: tokens.map((addr) => ({
    address:      addr,
    abi:          erc20Abi,
    functionName: "balanceOf",
    args:         [userAddress],
  })),
});
```

---

## 13. Error Handling

### Decode Custom Errors

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
try {
  await token.transfer("0x...", amount);
} catch (err: unknown) {
  if (err instanceof ethers.ContractTransactionResponse) {
    // Transaction sent but reverted
  }

  if (ethers.isCallException(err)) {
    const iface = new ethers.Interface(ERC20_ABI);

    try {
      const decoded = iface.parseError(err.data ?? "0x");
      console.log("Custom error:", decoded?.name);
      console.log("Args:", decoded?.args);
    } catch {
      console.log("Unknown error:", err.data);
    }

    // Check specific custom error
    if (err.data?.startsWith("0xf4d678b8")) { // InsufficientBalance selector
      console.log("Insufficient balance");
    }
  }

  if ((err as { code?: string }).code === "ACTION_REJECTED") {
    console.log("User rejected transaction");
  }
}

// ─── viem v2 ────────────────────────────────────────────────
import { decodeErrorResult, BaseError, ContractFunctionRevertedError, UserRejectedRequestError } from "viem";

try {
  await walletClient.writeContract({ ... });
} catch (err) {
  if (err instanceof BaseError) {
    const revertError = err.walk((e) => e instanceof ContractFunctionRevertedError);

    if (revertError instanceof ContractFunctionRevertedError) {
      const errorName = revertError.data?.errorName;
      console.log("Reverted with:", errorName);
      // "InsufficientBalance", "Unauthorized", etc.
    }

    if (err.walk((e) => e instanceof UserRejectedRequestError)) {
      console.log("User rejected");
    }
  }
}
```

### User-Facing Error Messages

```ts
function getReadableError(err: unknown): string {
  if (err instanceof Error) {
    // viem custom errors
    if (err.message.includes("InsufficientBalance"))   return "Insufficient balance";
    if (err.message.includes("Unauthorized"))          return "Not authorized";
    if (err.message.includes("User rejected"))         return "Transaction cancelled";
    if (err.message.includes("insufficient funds"))    return "Not enough ETH for gas";
    if (err.message.includes("nonce too low"))         return "Nonce conflict, please retry";
    if (err.message.includes("replacement fee too low")) return "Increase gas price to replace";
  }
  return "Transaction failed. Please try again.";
}
```

---

## 14. Signing Messages & Typed Data (EIP-712)

```ts
// ─── ethers.js v6 — Plain message ───────────────────────────
const signer    = await provider.getSigner();
const message   = "Sign in to MyApp";
const signature = await signer.signMessage(message);

// Verify on frontend
const recovered = ethers.verifyMessage(message, signature);
// recovered === signer address

// ─── ethers.js v6 — EIP-712 typed data ──────────────────────
const domain = {
  name:              "MyProtocol",
  version:           "1",
  chainId:           1,
  verifyingContract: "0xContractAddress...",
};

const types = {
  Permit: [
    { name: "owner",   type: "address" },
    { name: "spender", type: "address" },
    { name: "value",   type: "uint256" },
    { name: "nonce",   type: "uint256" },
    { name: "deadline",type: "uint256" },
  ],
};

const value = {
  owner:    await signer.getAddress(),
  spender:  "0xSpender...",
  value:    ethers.parseUnits("100", 18),
  nonce:    await token.nonces(await signer.getAddress()),
  deadline: Math.floor(Date.now() / 1000) + 3600, // 1 hour
};

const sig = await signer.signTypedData(domain, types, value);
const { v, r, s } = ethers.Signature.from(sig);

// Submit permit — user never needs ETH to approve!
await token.permit(value.owner, value.spender, value.value, value.deadline, v, r, s);

// ─── viem v2 — EIP-712 ──────────────────────────────────────
import { signTypedData } from "viem/actions";

const signature2 = await walletClient.signTypedData({
  domain,
  types,
  primaryType: "Permit",
  message:     value,
});
```

---

## 15. SIWE — Sign-In With Ethereum

Authenticate users with their wallet instead of passwords:

```ts
// npm install siwe viem
import { SiweMessage, generateNonce } from "siwe";

// 1. Backend generates nonce and stores it in session
//    GET /api/auth/nonce → returns random nonce

// 2. Frontend builds and signs the SIWE message
async function signIn(address: string, chainId: number) {
  const nonce   = await fetch("/api/auth/nonce").then((r) => r.text());

  const message = new SiweMessage({
    domain:    window.location.host,
    address,
    statement: "Sign in to MyApp with your Ethereum wallet.",
    uri:       window.location.origin,
    version:   "1",
    chainId,
    nonce,
  });

  const prepared  = message.prepareMessage();
  const signature = await walletClient.signMessage({ message: prepared, account: address as `0x${string}` });

  // 3. Backend verifies
  const result = await fetch("/api/auth/verify", {
    method:  "POST",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify({ message: prepared, signature }),
  });

  return result.json(); // { ok: true, address }
}

// 4. Backend verification (Node.js)
import { SiweMessage } from "siwe";

async function verifySiwe(message: string, signature: string, expectedNonce: string) {
  const siweMessage = new SiweMessage(message);
  const result      = await siweMessage.verify({ signature, nonce: expectedNonce });

  if (!result.success) throw new Error("Invalid SIWE signature");

  return result.data.address; // verified Ethereum address
}
```

---

## 16. Simulating Transactions

Simulate before sending to catch reverts early and protect UX:

```ts
// ─── ethers.js v6 — staticCall ──────────────────────────────
// staticCall runs the function without broadcasting — reverts if it would fail
try {
  await token.transfer.staticCall("0xRecipient...", amount, {
    from: userAddress,
  });
  console.log("Transaction will succeed — safe to send");
} catch (err) {
  console.log("Would revert:", err);
}

// ─── viem v2 — simulateContract ─────────────────────────────
import { simulateContract } from "viem/actions";

try {
  const { request } = await publicClient.simulateContract({
    address:      TOKEN_ADDRESS,
    abi:          erc20Abi,
    functionName: "transfer",
    args:         ["0xRecipient..." as `0x${string}`, parseUnits("100", 18)],
    account:      userAddress,
  });

  // Simulation succeeded — now send the real transaction
  const txHash = await walletClient.writeContract(request);
} catch (err) {
  // Caught before any gas is spent
  console.log("Simulation failed:", err);
}

// ─── wagmi React Hook ───────────────────────────────────────
import { useSimulateContract, useWriteContract } from "wagmi";

function SafeTransferButton() {
  const { data: simulation, error: simError } = useSimulateContract({
    address:      TOKEN_ADDRESS,
    abi:          erc20Abi,
    functionName: "transfer",
    args:         [RECIPIENT, parseUnits("100", 18)],
  });

  const { writeContract, isPending } = useWriteContract();

  return (
    <button
      disabled={!simulation?.request || isPending || !!simError}
      onClick={() => simulation?.request && writeContract(simulation.request)}
    >
      {simError ? `Will fail: ${simError.message}` : "Transfer"}
    </button>
  );
}
```

---

## 17. Gas Estimation

```ts
// ─── ethers.js v6 ───────────────────────────────────────────
const feeData = await provider.getFeeData();
console.log("Base fee:", ethers.formatUnits(feeData.lastBaseFeePerGas!, "gwei"), "gwei");
console.log("Max fee:", ethers.formatUnits(feeData.maxFeePerGas!, "gwei"), "gwei");
console.log("Priority:", ethers.formatUnits(feeData.maxPriorityFeePerGas!, "gwei"), "gwei");

// Estimate gas for a specific call
const gasEstimate = await token.transfer.estimateGas("0xRecipient...", amount, {
  from: userAddress,
});

// Add 20% buffer to avoid out-of-gas
const gasLimit = (gasEstimate * 120n) / 100n;

const tx = await token.transfer("0xRecipient...", amount, {
  gasLimit,
  maxFeePerGas:         feeData.maxFeePerGas!,
  maxPriorityFeePerGas: feeData.maxPriorityFeePerGas!,
});

// ─── viem v2 ────────────────────────────────────────────────
const gasEstimate2 = await publicClient.estimateContractGas({
  address:      TOKEN_ADDRESS,
  abi:          erc20Abi,
  functionName: "transfer",
  args:         [RECIPIENT, parseUnits("100", 18)],
  account:      userAddress,
});

const fees = await publicClient.estimateFeesPerGas();
// fees.maxFeePerGas, fees.maxPriorityFeePerGas

// Cost in ETH
const costWei = gasEstimate2 * fees.maxFeePerGas!;
const costEth = formatEther(costWei);
console.log("Estimated cost:", costEth, "ETH");
```

---

## 18. Testing Frontend Integrations

### Mocking Contracts with Anvil

```bash
# Start Anvil with a mainnet fork
anvil --fork-url $MAINNET_RPC_URL --fork-block-number 19500000

# Your frontend connects to localhost:8545
# All mainnet contracts are available
```

```ts
// In tests — use Anvil's local RPC
const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

// Impersonate a whale to test with real tokens
await provider.send("anvil_impersonateAccount", [WHALE_ADDRESS]);
const whale  = await provider.getSigner(WHALE_ADDRESS);
const token  = new ethers.Contract(USDC_ADDRESS, erc20Abi, whale);
await token.transfer(testUser, parseUnits("10000", 6));
await provider.send("anvil_stopImpersonatingAccount", [WHALE_ADDRESS]);
```

### Vitest + wagmi Test Utils

```ts
// npm install -D @wagmi/test vitest
import { renderHook, waitFor } from "@testing-library/react";
import { useReadContract } from "wagmi";
import { createWrapper } from "@wagmi/test"; // wraps with WagmiProvider

test("reads ERC20 balance", async () => {
  const { result } = renderHook(
    () => useReadContract({
      address:      TOKEN_ADDRESS,
      abi:          erc20Abi,
      functionName: "balanceOf",
      args:         [TEST_ADDRESS],
    }),
    { wrapper: createWrapper({ config: testConfig }) }
  );

  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toBe(100n * 10n ** 18n);
});
```

---

## 19. Security Best Practices

```
NEVER expose private keys in frontend code — use wallet providers only.

ALWAYS validate chain ID before sending transactions:
  const { chainId } = useAccount();
  if (chainId !== mainnet.id) return <WrongNetworkBanner />;

SIMULATE before sending to avoid user-facing revert errors.

VALIDATE inputs client-side before encoding:
  - amount > 0
  - recipient is a valid address (isAddress() from viem)
  - deadline has not passed

DISPLAY human-readable amounts — never raw wei to users.

HANDLE slippage on DEX interactions — add minAmountOut parameter.

AVOID infinite approvals for high-value tokens — use exact amounts.

PROTECT against phishing:
  - Never ask users to sign arbitrary messages with personal data
  - Always show the exact action being signed in the UI

USE ENS / address labels to reduce copy-paste errors.

RATE LIMIT RPC calls — cache reads, debounce user inputs.

NEVER store sensitive data (private keys, mnemonics) in localStorage.
Use session-only storage for wallet state.

DISPLAY transaction status clearly:
  - Pending (in mempool)
  - Confirming (1 of N blocks)
  - Confirmed (success)
  - Failed (reverted)
```

---

## 20. Tooling & Ecosystem Cheatsheet

| Tool | Purpose | Install |
|------|---------|---------|
| **viem** | Low-level EVM client (TypeScript) | `npm i viem` |
| **wagmi** | React hooks for Ethereum | `npm i wagmi viem` |
| **ethers.js v6** | Full-featured Ethereum library | `npm i ethers` |
| **permissionless** | ERC-4337 client (built on viem) | `npm i permissionless` |
| **siwe** | Sign-In With Ethereum | `npm i siwe` |
| **@tanstack/react-query** | Data fetching for wagmi | `npm i @tanstack/react-query` |
| **RainbowKit** | Wallet connection UI (wagmi) | `npm i @rainbow-me/rainbowkit` |
| **ConnectKit** | Wallet connection UI (wagmi) | `npm i connectkit` |
| **Web3Modal** | WalletConnect modal | `npm i @web3modal/wagmi` |
| **Foundry / Anvil** | Local EVM node for testing | `curl -L https://foundry.paradigm.xyz \| bash` |

### ABI Generation from Foundry

```bash
# Compile and generate ABI
forge build

# ABI is at out/ContractName.sol/ContractName.json
# Extract just the ABI:
cat out/Standards.sol/ERC20Token.json | jq '.abi' > src/abis/ERC20Token.json

# Generate TypeScript types from ABI (wagmi CLI)
# npm install -D @wagmi/cli
# wagmi.config.ts:
#   import { defineConfig } from "@wagmi/cli";
#   import { foundry } from "@wagmi/cli/plugins";
#   export default defineConfig({
#     out: "src/generated.ts",
#     plugins: [foundry({ project: "../" })],
#   });
# npx wagmi generate
```

### Useful Cast Commands for Frontend Debugging

```bash
# Read contract state
cast call $TOKEN "balanceOf(address)(uint256)" $USER --rpc-url $RPC

# Decode a transaction's calldata
cast calldata-decode "transfer(address,uint256)" 0xa9059cbb...

# Decode a log/event
cast decode-event "Transfer(address indexed,address indexed,uint256)" <topics> <data>

# Get current gas price
cast gas-price --rpc-url $RPC

# Convert units
cast to-wei 1.5 ether
cast from-wei 1500000000000000000

# Check if address is a contract
cast code $ADDRESS --rpc-url $RPC | wc -c   # > 2 = contract
```
