import cors from 'cors';
import 'dotenv/config';
import express from 'express';
import { z } from 'zod';

import { getRelayerStatus, transferMnee, type TxResult } from './mneeSdk.js';
import {
  appendPayment,
  appendTip,
  getTodayTipsTotal,
  hasRecentTipToRecipient,
  listTips,
  resetStore,
} from './store.js';

// Guardrails
const DAILY_TIP_LIMIT_MNEE = 10;
const TIP_AMOUNT_MNEE = 0.1;
const ANTI_SPAM_MINUTES = 5;

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

  // Guardrail 1: Daily limit
  const todayTotal = await getTodayTipsTotal();
  if (todayTotal + TIP_AMOUNT_MNEE > DAILY_TIP_LIMIT_MNEE) {
    return res.status(429).json({
      error: `Daily tip limit reached (${DAILY_TIP_LIMIT_MNEE} MNEE). Try again tomorrow.`,
      todayTotal,
      limit: DAILY_TIP_LIMIT_MNEE,
    });
  }

  // Guardrail 2: Anti-spam (no duplicate tips to same address within X minutes)
  const recentlyTipped = await hasRecentTipToRecipient(recipient, ANTI_SPAM_MINUTES);
  if (recentlyTipped) {
    return res.status(429).json({
      error: `Anti-spam: Already tipped this address within ${ANTI_SPAM_MINUTES} minutes.`,
    });
  }

  const amountMnee = TIP_AMOUNT_MNEE;
  const result = await transferMnee({ to: recipient, amountMnee });

  const tip = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    from: 'MNEE-Scout',
    to: recipient,
    amountMNEE: amountMnee,
    ticketId: result.ticketId,
    mode: result.mode,
  };

  await appendTip(tip);
  res.json({ ok: true, tip });
});

app.post('/v1/demo/reset', async (_req, res) => {
  await resetStore();
  res.json({ ok: true, message: 'Store reset for demo' });
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

  let result: TxResult;
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
    ticketId: result.ticketId,
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
const host = process.env.HOST ?? '0.0.0.0';
app.listen(port, host, () => {
  // eslint-disable-next-line no-console
  console.log(`mnee-pulse-backend listening on ${host}:${port}`);
});
