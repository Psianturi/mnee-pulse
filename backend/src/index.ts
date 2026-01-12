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
    const dryRun = (process.env.DRY_RUN ?? 'true').toLowerCase() === 'true';
    const required = dryRun
      ? ['DRY_RUN']
      : ['DRY_RUN', 'MNEE_API_KEY', 'MNEE_ENVIRONMENT', 'RELAYER_ADDRESS', 'RELAYER_WIF'];

    const missing = required.filter((k) => {
      const v = process.env[k];
      return v == null || String(v).trim() === '';
    });

    res.status(500).json({
      ok: false,
      error: (e as Error).message ?? 'status failed',
      mode: dryRun ? 'dry-run' : 'onchain',
      environment: process.env.MNEE_ENVIRONMENT ?? 'sandbox',
      missingVars: missing,
      varsPresent: {
        DRY_RUN: (process.env.DRY_RUN ?? '').trim() !== '',
        MNEE_ENVIRONMENT: (process.env.MNEE_ENVIRONMENT ?? '').trim() !== '',
        MNEE_API_KEY: (process.env.MNEE_API_KEY ?? '').trim() !== '',
        RELAYER_ADDRESS: (process.env.RELAYER_ADDRESS ?? '').trim() !== '',
        RELAYER_WIF: (process.env.RELAYER_WIF ?? '').trim() !== '',
        DEMO_RECIPIENT_ADDRESS: (process.env.DEMO_RECIPIENT_ADDRESS ?? '').trim() !== '',
      },
    });
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
  const recipient =
    process.env.DEMO_RECIPIENT_ADDRESS ?? '1LgxHPsSo2UTssKmxqVoNraJBaLBCN2NhW';

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

app.get('/v1/demo/qris', async (_req, res) => {
  // For demo purposes - use relayer as merchant but payment will be simulated
  const merchantAddress = process.env.DEMO_MERCHANT_ADDRESS 
    ?? process.env.RELAYER_ADDRESS 
    ?? '1LgxHPsSo2UTssKmxqVoNraJBaLBCN2NhW';

  return res.json({
    ok: true,
    merchantName: 'MNEE Coffee Co.',
    mneeAddress: merchantAddress,
    amountIDR: 5000,
    isDemo: true, // Flag for demo simulation
  });
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
  const isDemo = req.body.isDemo === true;
  const amountMnee = computeAmountMnee(amountIDR, rateIDRPerMNEE);
  
  if (amountMnee <= 0) {
    return res.status(400).json({
      error: 'Invalid payment amount after conversion',
      amountMNEE: amountMnee,
    });
  }

  const relayer = (process.env.RELAYER_ADDRESS ?? '').trim();
  const isSelfTransfer = relayer.length > 0 && sameAddress(relayer, merchantAddress);

  let result: TxResult;

  // For demo: simulate success if it would be self-transfer or isDemo flag
  if (isDemo || isSelfTransfer) {
    result = {
      mode: 'dry-run',
      ticketId: `DEMO-PAY-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    };
  } else {
    try {
      result = await transferMnee({ to: merchantAddress, amountMnee });
    } catch (e) {
      const requestId = crypto.randomUUID();
      console.error('[pay:qris] failed', {
        requestId,
        merchantAddress,
        amountIDR,
        rateIDRPerMNEE,
        amountMNEE: amountMnee,
        error: (e as Error).message ?? String(e),
      });

      return res.status(500).json({
        error: (e as Error).message ?? 'transfer failed',
        requestId,
      });
    }
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

function computeAmountMnee(amountIdr: number, rateIdrPerMnee: number) {
  // Use 1e8 "satoshi-like" precision to avoid float drift.
  const sats = Math.round((amountIdr * 1e8) / rateIdrPerMnee);
  return sats / 1e8;
}

function sameAddress(a: string, b: string) {
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

const port = Number(process.env.PORT ?? '8000');
const host = process.env.HOST ?? '0.0.0.0';
app.listen(port, host, () => {
  // eslint-disable-next-line no-console
  console.log(`mnee-pulse-backend listening on ${host}:${port}`);
});
