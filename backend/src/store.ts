import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

type Tip = {
  id: string;
  createdAt: string;
  from: string;
  to: string;
  amountMNEE: number;
  ticketId: string;
  mode: 'dry-run' | 'onchain';
};

type Payment = {
  id: string;
  createdAt: string;
  merchantAddress: string;
  amountIDR: number;
  rateIDRPerMNEE: number;
  amountMNEE: number;
  ticketId: string;
  mode: 'dry-run' | 'onchain';
};

type StoreShape = {
  tips: Tip[];
  payments: Payment[];
};

const __dirname = dirname(fileURLToPath(import.meta.url));
const storePath = join(__dirname, '..', 'data', 'store.json');

async function readStore(): Promise<StoreShape> {
  try {
    const raw = await readFile(storePath, 'utf-8');
    const decoded = JSON.parse(raw);
    return {
      tips: Array.isArray(decoded?.tips) ? decoded.tips : [],
      payments: Array.isArray(decoded?.payments) ? decoded.payments : [],
    };
  } catch {
    return { tips: [], payments: [] };
  }
}

async function writeStore(store: StoreShape) {
  await writeFile(storePath, JSON.stringify(store, null, 2), 'utf-8');
}

export async function listTips(): Promise<Tip[]> {
  const store = await readStore();
  return store.tips
    .slice()
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

export async function appendTip(tip: Tip) {
  const store = await readStore();
  store.tips.push(tip);
  await writeStore(store);
}

export async function appendPayment(payment: Payment) {
  const store = await readStore();
  store.payments.push(payment);
  await writeStore(store);
}

export async function resetStore() {
  await writeStore({ tips: [], payments: [] });
}

export async function getTodayTipsTotal(): Promise<number> {
  const store = await readStore();
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  return store.tips
    .filter((t) => new Date(t.createdAt) >= todayStart)
    .reduce((sum, t) => sum + t.amountMNEE, 0);
}

export async function hasRecentTipToRecipient(
  recipient: string,
  withinMinutes = 5
): Promise<boolean> {
  const store = await readStore();
  const cutoff = new Date(Date.now() - withinMinutes * 60 * 1000);

  return store.tips.some(
    (t) =>
      t.to.toLowerCase() === recipient.toLowerCase() &&
      new Date(t.createdAt) >= cutoff
  );
}
