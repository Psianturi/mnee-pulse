import { Contract, JsonRpcProvider, Wallet, formatEther, formatUnits, parseUnits } from 'ethers';

export type ChainTxResult = {
  txHash: string;
  mode: 'dry-run' | 'onchain';
};

const erc20Abi = [
  'function decimals() view returns (uint8)',
  'function balanceOf(address owner) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
];

let cachedDecimals: number | null = null;

export type RelayerStatus = {
  mode: 'dry-run' | 'onchain';
  chainId?: number;
  relayerAddress?: string;
  relayerEth?: string;
  relayerMnee?: string;
  tokenAddress?: string;
  tokenDecimals?: number;
};

export async function getRelayerStatus(): Promise<RelayerStatus> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';
  if (dryRun) {
    return { mode: 'dry-run', tokenAddress: process.env.MNEE_TOKEN_ADDRESS };
  }

  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.RELAYER_PRIVATE_KEY;
  const tokenAddress = process.env.MNEE_TOKEN_ADDRESS;

  if (!rpcUrl) throw new Error('RPC_URL is not set');
  if (!privateKey) throw new Error('RELAYER_PRIVATE_KEY is not set');
  if (!tokenAddress) throw new Error('MNEE_TOKEN_ADDRESS is not set');

  const provider = new JsonRpcProvider(rpcUrl);
  const wallet = new Wallet(privateKey, provider);
  const token = new Contract(tokenAddress, erc20Abi, provider);

  const network = await provider.getNetwork();

  const [ethBal, decimals, mneeBal] = await Promise.all([
    provider.getBalance(wallet.address),
    cachedDecimals == null ? token.decimals() : Promise.resolve(cachedDecimals),
    token.balanceOf(wallet.address),
  ]);

  cachedDecimals ??= Number(decimals);

  return {
    mode: 'onchain',
    chainId: Number(network.chainId),
    relayerAddress: wallet.address,
    relayerEth: formatEther(ethBal),
    relayerMnee: formatUnits(mneeBal, cachedDecimals),
    tokenAddress,
    tokenDecimals: cachedDecimals,
  };
}

export async function transferMnee(params: {
  to: string;
  amountMnee: number;
}): Promise<ChainTxResult> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';
  if (dryRun) {
    return {
      mode: 'dry-run',
      txHash: `0xDEMO${Math.random().toString(16).slice(2).padEnd(60, '0')}`.slice(0, 66),
    };
  }

  const rpcUrl = process.env.RPC_URL;
  const privateKey = process.env.RELAYER_PRIVATE_KEY;
  const tokenAddress = process.env.MNEE_TOKEN_ADDRESS;

  if (!rpcUrl) throw new Error('RPC_URL is not set');
  if (!privateKey) throw new Error('RELAYER_PRIVATE_KEY is not set');
  if (!tokenAddress) throw new Error('MNEE_TOKEN_ADDRESS is not set');

  const provider = new JsonRpcProvider(rpcUrl);
  const wallet = new Wallet(privateKey, provider);
  const token = new Contract(tokenAddress, erc20Abi, wallet);

  if (cachedDecimals == null) {
    cachedDecimals = Number(await token.decimals());
  }

  const amount = parseUnits(params.amountMnee.toFixed(5), cachedDecimals);
  const tx = await token.transfer(params.to, amount);
  const receipt = await tx.wait();

  return { mode: 'onchain', txHash: receipt?.hash ?? tx.hash };
}
