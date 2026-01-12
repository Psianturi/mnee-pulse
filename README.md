# MNEE-Pulse

*The Smart Stablecoin Ecosystem: Earn via AI, Spend via QRIS.*

Mobile app for earning MNEE through AI-powered content tipping and spending via QR payments.

##  Track

**AI & Agent Payments** + **Commerce & Creator Tools**

Built for the [MNEE Hackathon](https://mnee-eth.devpost.com/) using **MNEE ERC-20 stablecoin on Ethereum**.

**Contract**: `0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF`

## What is This?

MNEE-Pulse connects content creators with real-world spending:
- **Earn**: AI Scout (Gemini) evaluates content quality and auto-tips quality posts
- **Spend**: Use earned MNEE to pay at merchants via QR code (QRIS-like)
- **Gasless**: Users don't pay fees; relayer handles Ethereum gas costs

## Demo Flow

1. **Creator posts quality content** → Educational tweet about blockchain
2. **AI Scout evaluates** → Gemini AI scores content quality (1-10)
3. **Auto-tip sent** → If score ≥7, 0.1 MNEE sent via ERC-20 transfer
4. **Creator checks app** → Balance shows in "Earn" tab
5. **Buy coffee** → Scan QR, pay 25,000 IDR with MNEE

## Project Structure

```
mnee-pulse/
├── lib/                 # Flutter mobile app
│   └── src/
│       ├── screens/     # Earn & Spend UI
│       ├── services/    # API client
│       └── theme.dart   # Dark theme with gradients
├── backend/             # Express + ethers.js (ERC-20)
│   └── src/
│       ├── index.ts     # API routes
│       ├── mneeEth.ts   # MNEE ERC-20 transfer logic
│       ├── gemini.ts    # AI content scoring
│       └── store.ts     # JSON storage + guardrails
└── android/ios/web/     # Platform configs
```

## Quick Start

### Backend (Local)

```bash
cd backend
cp .env.example .env
# Edit .env with your Ethereum wallet and keys
npm install
npm run dev
```

### Backend (Railway - Production)

1. Go to [railway.app](https://railway.app)
2. New Project → Deploy from GitHub repo
3. Select `mnee-pulse` repo
4. Set Root Directory: `backend`
5. Add Environment Variables (see below)
6. Deploy! You'll get a public URL like `https://mnee-pulse-xxx.up.railway.app`

**Required Environment Variables for Railway:**

| Variable | Description |
|----------|-------------|
| `RELAYER_ADDRESS` | Your Ethereum wallet address (0x...) |
| `RELAYER_PRIVATE_KEY` | Ethereum private key (64 hex chars) |
| `ETHEREUM_RPC_URL` | (Optional) RPC endpoint, default: public RPC |
| `DEMO_RECIPIENT_ADDRESS` | Demo tip recipient (Ethereum address) |
| `DEMO_MERCHANT_ADDRESS` | Demo merchant (Ethereum address) |
| `DRY_RUN` | `true` for demo, `false` for real transactions |
| `GEMINI_API_KEY` | For AI content scoring |

### Flutter App

```bash
flutter pub get

# For web (uses localhost)
flutter run -d chrome

# For Android with production backend
flutter run --dart-define=API_BASE_URL=https://your-railway-url.up.railway.app

# For Android with local backend (same WiFi)
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/v1/status` | Relayer mode + MNEE balance |
| GET | `/v1/tips` | List all tips |
| POST | `/v1/demo/run-scout-once` | Generate demo tip (with guardrails) |
| POST | `/v1/demo/reset` | Reset data for demo |
| POST | `/v1/payments/qris` | Process QR payment |

## Guardrails (Anti-Abuse)

| Rule | Value | Description |
|------|-------|-------------|
| Daily Limit | 10 MNEE | Max tips per day from AI Scout |
| Anti-Spam | 5 min | Cooldown per recipient |
| Tip Amount | 0.1 MNEE | Fixed tip per quality content |

## Screenshots

The app features a modern dark theme with gradient cards and smooth animations:
- **Earn Tab**: Shows total earned MNEE, live/dry-run status, recent tips, AI content evaluation
- **Spend Tab**: QR scanner, demo merchant QR, payment confirmation

## Tech Stack

- **Mobile**: Flutter (iOS, Android, Web)
- **Backend**: Node.js + Express + TypeScript
- **Blockchain**: Ethereum (ethers.js) + MNEE ERC-20
- **AI**: Google Gemini API (content scoring)
- **Hosting**: Railway

## MNEE Resources

- **MNEE Website**: [mnee.io](https://mnee.io)
- **Hackathon**: [mnee-eth.devpost.com](https://mnee-eth.devpost.com)
- **Contract (Ethereum)**: `0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF`

## License

MIT
