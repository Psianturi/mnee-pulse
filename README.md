# MNEE-Pulse

*The Smart Stablecoin Ecosystem: Earn via AI, Spend via QRIS.*

Mobile app for earning MNEE through AI-powered content tipping and spending via QR payments.

## What is This?

MNEE-Pulse connects content creators with real-world spending:
- **Earn**: AI Scout monitors social media and tips quality educational content automatically
- **Spend**: Use earned MNEE to pay at merchants via QR code (QRIS-like simulation)
- **Gasless**: Users don't need ETH; relayer handles transaction fees

Built for the MNEE Hackathon using the MNEE ERC-20 stablecoin.

## Project Structure

```
mnee-pulse/
├── lib/           # Flutter mobile app
├── backend/       # Express + ethers relayer API
└── contracts/     # ABI and contract address references
```

## Requirements

- Node.js 18+
- Flutter 3.x
- MNEE sandbox API key (from developer.mnee.net)

## Quick Start

### Backend

```bash
cd backend
cp .env.example .env
# Edit .env with your settings
npm install
npm run dev
```

Required `.env` variables:
- `DEMO_RECIPIENT_ADDRESS` — wallet to receive demo tips
- `DRY_RUN=true` — set to `false` for real transactions
- `RPC_URL` — Ethereum RPC endpoint
- `RELAYER_PRIVATE_KEY` — wallet private key for sending MNEE

### Flutter App

```bash
flutter pub get
flutter run
```

Backend URL configured in `lib/src/config.dart`.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/status` | Relayer mode and balances |
| GET | `/v1/tips` | List all tips |
| POST | `/v1/demo/run-scout-once` | Generate demo tip |
| POST | `/v1/demo/reset` | Reset data for demo |
| POST | `/v1/payments/qris` | Process QR payment |

## Guardrails

- Daily limit: 10 MNEE max per day
- Anti-spam: 5 minute cooldown per recipient
- Tip amount: 0.1 MNEE per tip

## MNEE Contract

Address: `0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF`

## License

MIT
