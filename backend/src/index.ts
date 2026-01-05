import cors from 'cors';
import 'dotenv/config';
import express from 'express';
import { z } from 'zod';

import { getRelayerStatus, transferMnee, type ChainTxResult } from './mneeErc20.js';
import { appendPayment, appendTip, listTips } from './store.js';

const app = express();

app.use(cors({ origin: process.env.CORS_ORIGIN ?? '*' }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, name: 'mnee-pulse-backend' });
});

app.get('/v1/status', async (_req, res) => {
  try {
    const status = await getRelayerStatus();
    res.json({ ok: true, ...status });
  } catch (e) {
    res.status(500).json({ ok: false, error: (e as Error).message ?? 'status failed' });
  }
});

app.get('/v1/tips', async (_req, res) => {
  res.json(await listTips());
});

app.get('/v1/tips/:userAddress', async (req, res) => {
  const userAddress = req.params.userAddress;
  const tips = await listTips();
  res.json(tips.filter((t) => (t.to ?? '').toLowerCase() === userAddress.toLowerCase()));
});

app.post('/v1/demo/run-scout-once', async (_req, res) => {
  // MVP: stubbed "scout" that always tips a demo recipient.
  const recipient = process.env.DEMO_RECIPIENT_ADDRESS;
  if (!recipient) {
    return res.status(400).json({ error: 'DEMO_RECIPIENT_ADDRESS is not set' });
  }

  const amountMnee = 0.1;
  const result = await transferMnee({ to: recipient, amountMnee });

  const tip = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    from: 'MNEE-Scout',
    to: recipient,
    amountMNEE: amountMnee,
    txHash: result.txHash,
    mode: result.mode,
  };

  await appendTip(tip);
  res.json({ ok: true, tip });
});

const payQrisSchema = z.object({
  merchantAddress: z.string().min(1),
  amountIDR: z.number().int().positive(),
  rateIDRPerMNEE: z.number().int().positive(),
});

app.post('/v1/payments/qris', async (req, res) => {
  const parsed = payQrisSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const { merchantAddress, amountIDR, rateIDRPerMNEE } = parsed.data;
  const amountMnee = roundTo(amountIDR / rateIDRPerMNEE, 5);

  let result: ChainTxResult;
  try {
    result = await transferMnee({ to: merchantAddress, amountMnee });
  } catch (e) {
    return res.status(500).json({ error: (e as Error).message ?? 'transfer failed' });
  }

  const payment = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    merchantAddress,
    amountIDR,
    rateIDRPerMNEE,
    amountMNEE: amountMnee,
    txHash: result.txHash,
    mode: result.mode,
  };

  await appendPayment(payment);
  res.json({ ok: true, ...payment });
});

function roundTo(value: number, decimals: number) {
  const p = 10 ** decimals;
  return Math.round(value * p) / p;
}

const port = Number(process.env.PORT ?? '8000');
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`mnee-pulse-backend listening on :${port}`);
});
