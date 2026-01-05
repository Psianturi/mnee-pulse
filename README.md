# MNEE-Pulse

Hackathon MVP: **Earn via AI micro-tipping, spend via QR (QRIS-like)** using the MNEE ERC-20 stablecoin.

## Repo Structure

- `lib/` — Flutter mobile app (Earn/Spend UI)
- `backend/` — Demo relayer + API (Express + ethers)
- `contracts/` — No custom contracts; keeps ABI/address references

## Quick Run (Local)

### 1) Backend

1. Copy env: `backend/.env.example` → `backend/.env`
2. Set at minimum:
	 - `DRY_RUN=true` (default) to avoid on-chain tx
	 - or set `RPC_URL` + `RELAYER_PRIVATE_KEY` to send real ERC-20 transfers

Commands:

- `cd backend`
- `npm install`
- `npm run dev`

Backend runs on `http://localhost:8000`.

Useful endpoints:

- `GET /v1/status` — relayer mode + balances (ETH + MNEE)
- `POST /v1/demo/run-scout-once` — generates one demo tip
- `POST /v1/payments/qris` — simulated QR payment (sends ERC-20 transfer)

### 2) Flutter

- `flutter pub get`
- `flutter run`

App expects backend at `http://localhost:8000` (see `lib/src/config.dart`).

## Notes

- Do not commit secrets (API keys / private keys). Keep them in `.env`.
- Hackathon requirement: project must use MNEE ERC-20 contract address:
	`0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF`.
