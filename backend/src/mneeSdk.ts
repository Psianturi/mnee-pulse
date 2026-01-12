import Mnee from '@mnee/ts-sdk';

export type TxResult = {
  ticketId: string;
  mode: 'dry-run' | 'onchain';
};

export type RelayerStatus = {
  mode: 'dry-run' | 'onchain';
  environment?: string;
  relayerAddress?: string;
  relayerMnee?: string;
};

let mneeClient: Mnee | null = null;

function getClient(): Mnee {
  if (mneeClient) return mneeClient;

  const apiKey = process.env.MNEE_API_KEY;
  const environment = (process.env.MNEE_ENVIRONMENT ?? 'sandbox') as 'sandbox' | 'production';

  if (!apiKey) throw new Error('MNEE_API_KEY is not set');

  mneeClient = new Mnee({ apiKey, environment });
  return mneeClient;
}

export async function getRelayerStatus(): Promise<RelayerStatus> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';
  const relayerAddress = process.env.RELAYER_ADDRESS;

  if (dryRun) {
    return {
      mode: 'dry-run',
      environment: process.env.MNEE_ENVIRONMENT ?? 'sandbox',
      relayerAddress,
    };
  }

  if (!relayerAddress) throw new Error('RELAYER_ADDRESS is not set');

  const client = getClient();

  try {
    const balance = await client.balance(relayerAddress);
    return {
      mode: 'onchain',
      environment: process.env.MNEE_ENVIRONMENT ?? 'sandbox',
      relayerAddress,
      relayerMnee: balance.decimalAmount.toString(),
    };
  } catch (e) {
    return {
      mode: 'onchain',
      environment: process.env.MNEE_ENVIRONMENT ?? 'sandbox',
      relayerAddress,
      relayerMnee: 'error fetching balance',
    };
  }
}

export async function transferMnee(params: {
  to: string;
  amountMnee: number;
}): Promise<TxResult> {
  const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';

  if (dryRun) {
    return {
      mode: 'dry-run',
      ticketId: `DEMO-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    };
  }

  const wif = process.env.RELAYER_WIF;
  if (!wif) throw new Error('RELAYER_WIF is not set');

  const client = getClient();

  let response: { ticketId?: string };
  try {
    response = await client.transfer(
      [{ address: params.to, amount: params.amountMnee }],
      wif
    );
  } catch (e) {
    const message = (e as { message?: unknown })?.message;
    const msg =
      typeof message === 'string' && message.trim().length > 0
        ? message
        : String(e);
    throw new Error(`MNEE transfer failed: ${msg}`);
  }

  if (!response.ticketId) {
    throw new Error('Transfer failed: no ticketId returned');
  }

  return {
    mode: 'onchain',
    ticketId: response.ticketId,
  };
}
