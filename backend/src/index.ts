import cors from 'cors';
import 'dotenv/config';
import express from 'express';
import { z } from 'zod';

import { checkGeminiStatus, scoreContent } from './gemini.js';
// Switched to Ethereum MNEE (ERC-20) for hackathon compliance
import { getRelayerStatus, transferMnee, isValidEthAddress, type TxResult } from './mneeEth.js';
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
    // Ethereum mode: need RELAYER_PRIVATE_KEY instead of RELAYER_WIF
    const required = dryRun
      ? ['DRY_RUN']
      : ['DRY_RUN', 'RELAYER_ADDRESS', 'RELAYER_PRIVATE_KEY'];

    const missing = required.filter((k) => {
      const v = process.env[k];
      return v == null || String(v).trim() === '';
    });

    res.status(500).json({
      ok: false,
      error: (e as Error).message ?? 'status failed',
      mode: dryRun ? 'dry-run' : 'onchain',
      network: 'ethereum-mainnet',
      missingVars: missing,
      varsPresent: {
        DRY_RUN: (process.env.DRY_RUN ?? '').trim() !== '',
        ETHEREUM_RPC_URL: (process.env.ETHEREUM_RPC_URL ?? '').trim() !== '',
        RELAYER_ADDRESS: (process.env.RELAYER_ADDRESS ?? '').trim() !== '',
        RELAYER_PRIVATE_KEY: (process.env.RELAYER_PRIVATE_KEY ?? '').trim() !== '',
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
  // stubbed "scout" that always tips a demo recipient.
  const recipient =
    process.env.DEMO_RECIPIENT_ADDRESS ?? '0x136e49195511f4ca36d9582b203953d6d8b599f6';

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

// New: AI-powered content scoring endpoint
const scoreContentSchema = z.object({
  content: z.string().min(10).max(5000),
  recipientAddress: z.string().optional(),
});

app.post('/v1/scout/evaluate', async (req, res) => {
  const parsed = scoreContentSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const { content, recipientAddress } = parsed.data;
  // Default: user's Ethereum address for demo recipient
  const recipient = recipientAddress ?? process.env.DEMO_RECIPIENT_ADDRESS ?? '0x136e49195511f4ca36d9582b203953d6d8b599f6';

  // Guardrail 1: Daily limit
  const todayTotal = await getTodayTipsTotal();
  if (todayTotal + TIP_AMOUNT_MNEE > DAILY_TIP_LIMIT_MNEE) {
    return res.status(429).json({
      error: `Daily tip limit reached (${DAILY_TIP_LIMIT_MNEE} MNEE). Try again tomorrow.`,
      todayTotal,
      limit: DAILY_TIP_LIMIT_MNEE,
    });
  }

  // Guardrail 2: Anti-spam
  const recentlyTipped = await hasRecentTipToRecipient(recipient, ANTI_SPAM_MINUTES);
  if (recentlyTipped) {
    return res.status(429).json({
      error: `Anti-spam: Already tipped this address within ${ANTI_SPAM_MINUTES} minutes.`,
    });
  }

  // Score content with Gemini AI
  const evaluation = await scoreContent(content);

  // If qualified (score >= 7), send tip
  let tip = null;
  if (evaluation.isQualified) {
    const result = await transferMnee({ to: recipient, amountMnee: TIP_AMOUNT_MNEE });
    tip = {
      id: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
      from: 'MNEE-Scout-AI',
      to: recipient,
      amountMNEE: TIP_AMOUNT_MNEE,
      ticketId: result.ticketId,
      mode: result.mode,
      aiScore: evaluation.score,
    };
    await appendTip(tip);
  }

  res.json({
    ok: true,
    evaluation,
    rewarded: evaluation.isQualified,
    tip,
  });
});


app.get('/v1/ai/status', async (_req, res) => {
  const status = await checkGeminiStatus();
  res.json({ ok: status.available, ...status });
});

app.post('/v1/demo/reset', async (_req, res) => {
  await resetStore();
  res.json({ ok: true, message: 'Store reset for demo' });
});

app.get('/v1/demo/qris', async (_req, res) => {
  // For demo purposes - use user's Ethereum address as demo merchant
  const merchantAddress = process.env.DEMO_MERCHANT_ADDRESS 
    ?? process.env.RELAYER_ADDRESS 
    ?? '0x136e49195511f4ca36d9582b203953d6d8b599f6';

  return res.json({
    ok: true,
    merchantName: 'MNEE Coffee Co.',
    mneeAddress: merchantAddress,
    amountUSD: 0.08, 
    isDemo: true, // Flag for demo simulation
  });
});

const payQrisSchema = z.object({
  merchantAddress: z.string().min(1),
  amountUSD: z.number().positive(), // USD amount (1 MNEE = 1 USD)
});

app.post('/v1/payments/qris', async (req, res) => {
  const parsed = payQrisSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: parsed.error.flatten() });
  }

  const { merchantAddress, amountUSD } = parsed.data;
  const isDemo = req.body.isDemo === true;
  const forceReal = req.body.forceReal === true; 
  // 1 MNEE = 1 USD (stablecoin)
  const amountMnee = amountUSD;
  
  if (amountMnee <= 0) {
    return res.status(400).json({
      error: 'Invalid payment amount',
      amountMNEE: amountMnee,
    });
  }

  const relayer = (process.env.RELAYER_ADDRESS ?? '').trim();
  const isSelfTransfer = relayer.length > 0 && sameAddress(relayer, merchantAddress);

  let result: TxResult;

  // For demo: simulate success UNLESS forceReal is true
  if ((isDemo || isSelfTransfer) && !forceReal) {
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
        amountUSD,
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
    amountUSD,
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
