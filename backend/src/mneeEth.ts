import { ethers, JsonRpcProvider, Wallet, Contract, formatUnits, parseUnits } from 'ethers';

// MNEE ERC-20 contract on Ethereum (from hackathon requirements)
const MNEE_CONTRACT = '0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF';

// Standard ERC-20 ABI (only functions we need)
const ERC20_ABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
];

export type TxResult = {
  ticketId: string; // tx hash for Ethereum
  mode: 'dry-run' | 'onchain';
};

export type RelayerStatus = {
  mode: 'dry-run' | 'onchain';
  network?: string;
  relayerAddress?: string;
  relayerMnee?: string;
  contractAddress?: string;
};

let provider: JsonRpcProvider | null = null;
let wallet: Wallet | null = null;
let mneeContract: Contract | null = null;

function getProvider(): JsonRpcProvider {
  if (provider) return provider;

  // Default to Ethereum mainnet via public RPC, or use custom RPC
  const rpcUrl = process.env.ETHEREUM_RPC_URL || 'https://eth.llamarpc.com';
  provider = new JsonRpcProvider(rpcUrl);
  return provider;
}

function getWallet(): Wallet {
  if (wallet) return wallet;

  const privateKey = process.env.RELAYER_PRIVATE_KEY;
  if (!privateKey) throw new Error('RELAYER_PRIVATE_KEY is not set');

  wallet = new Wallet(privateKey, getProvider());
  return wallet;
}

function getMneeContract(signerOrProvider?: Wallet | JsonRpcProvider): Contract {
  if (mneeContract && !signerOrProvider) return mneeContract;

  const contractProvider = signerOrProvider || getProvider();
  const contract = new Contract(MNEE_CONTRACT, ERC20_ABI, contractProvider);

  if (!signerOrProvider) {
    mneeContract = contract;
  }

  return contract;
}

export async function getRelayerStatus(): Promise<RelayerStatus> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';
  const relayerAddress = process.env.RELAYER_ADDRESS;

  if (dryRun) {
    return {
      mode: 'dry-run',
      network: 'ethereum-mainnet',
      relayerAddress,
      contractAddress: MNEE_CONTRACT,
    };
  }

  if (!relayerAddress) throw new Error('RELAYER_ADDRESS is not set');

  try {
    const contract = getMneeContract();
    const [balance, decimals] = await Promise.all([
      contract.balanceOf(relayerAddress),
      contract.decimals(),
    ]);

    return {
      mode: 'onchain',
      network: 'ethereum-mainnet',
      relayerAddress,
      relayerMnee: formatUnits(balance, decimals),
      contractAddress: MNEE_CONTRACT,
    };
  } catch (e) {
    console.error('[mneeEth] Error fetching balance:', e);
    return {
      mode: 'onchain',
      network: 'ethereum-mainnet',
      relayerAddress,
      relayerMnee: 'error fetching balance',
      contractAddress: MNEE_CONTRACT,
    };
  }
}

export async function transferMnee(params: {
  to: string;
  amountMnee: number;
}): Promise<TxResult> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';

  // Demo mode - return fake tx hash
  if (dryRun) {
    return {
      mode: 'dry-run',
      ticketId: `DEMO-ETH-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    };
  }

  // Validate Ethereum address format
  if (!ethers.isAddress(params.to)) {
    throw new Error(`Invalid Ethereum address: ${params.to}`);
  }

  try {
    const signer = getWallet();
    const contract = getMneeContract(signer);

    // Get decimals (MNEE is likely 6 or 18 decimals)
    const decimals = await contract.decimals();
    const amount = parseUnits(params.amountMnee.toString(), decimals);

    console.log(`[mneeEth] Transferring ${params.amountMnee} MNEE to ${params.to}`);

    // Send ERC-20 transfer
    const tx = await contract.transfer(params.to, amount);
    console.log(`[mneeEth] Transaction submitted: ${tx.hash}`);

    // Wait for confirmation (1 block)
    const receipt = await tx.wait(1);
    console.log(`[mneeEth] Transaction confirmed in block ${receipt.blockNumber}`);

    return {
      mode: 'onchain',
      ticketId: tx.hash,
    };
  } catch (e) {
    const message = (e as { message?: unknown })?.message;
    const msg =
      typeof message === 'string' && message.trim().length > 0
        ? message
        : String(e);
    throw new Error(`MNEE transfer failed: ${msg}`);
  }
}

// Helper to check if an address is valid Ethereum address
export function isValidEthAddress(address: string): boolean {
  return ethers.isAddress(address);
}
