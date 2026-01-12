# MNEE-Pulse

*The Smart Stablecoin Ecosystem: Earn via AI, Spend via QRIS.*

Mobile app for earning MNEE through AI-powered content tipping and spending via QR payments.

## What is This?

MNEE-Pulse connects content creators with real-world spending:
- **Earn**: AI Scout monitors social media and tips quality educational content automatically
- **Spend**: Use earned MNEE to pay at merchants via QR code (QRIS-like simulation)
- **Gasless**: Users don't pay fees; relayer handles transaction costs

Built for the **MNEE Hackathon** using the MNEE stablecoin on BSV blockchain.

## Demo Flow

1. **Creator posts quality content** → Educational tweet about blockchain
2. **AI Scout evaluates** → Gemini AI scores content quality
3. **Auto-tip sent** → 0.1 MNEE sent to creator's wallet
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
├── backend/             # Express + MNEE SDK
│   └── src/
│       ├── index.ts     # API routes
│       ├── mneeSdk.ts   # MNEE transfer logic
│       └── store.ts     # JSON storage + guardrails
└── android/ios/web/     # Platform configs
```

## Quick Start

### Backend (Local)

```bash
cd backend
cp .env.example .env
# Edit .env with your MNEE API key and wallet
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
| `MNEE_API_KEY` | From developer.mnee.net |
| `MNEE_ENVIRONMENT` | `sandbox` or `production` |
| `RELAYER_ADDRESS` | Your MNEE wallet address |
| `RELAYER_WIF` | WIF private key (from `mnee export`) |
| `DEMO_RECIPIENT_ADDRESS` | Wallet for demo tips |
| `DRY_RUN` | `false` for real transactions |
| `GEMINI_API_KEY` | (Optional) For AI content scoring |

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
- **Earn Tab**: Shows total earned MNEE, live/dry-run status, recent tips
- **Spend Tab**: QR scanner, merchant info, payment confirmation

## MNEE Resources

- **MNEE Developer Portal**: [developer.mnee.net](https://developer.mnee.net)
- **MNEE SDK**: `@mnee/ts-sdk` (npm)
- **MNEE CLI**: `@mnee/cli` (for wallet management)

## Environment Setup (MNEE Wallet)

```bash
# Install MNEE CLI
npm install -g @mnee/cli

# Login to sandbox
mnee login --environment sandbox

# Create wallet
mnee wallet

# Get test tokens
mnee faucet

# Export private key (for .env)
mnee export
```


## License

MIT
