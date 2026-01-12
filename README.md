# MNEE-Pulse

*The Smart Stablecoin Ecosystem: Earn via AI, Spend via QRIS.*

Mobile app for earning MNEE through AI-powered content tipping and spending via QR payments.

## 🏆 Track

**AI & Agent Payments** + **Commerce & Creator Tools**

Built for the [MNEE Hackathon](https://mnee-eth.devpost.com/) using **MNEE ERC-20 stablecoin on Ethereum**.

**Contract**: [`0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF`](https://etherscan.io/address/0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF)

---

## 📱 What is MNEE-Pulse?

MNEE-Pulse connects content creators with real-world spending:

| Feature | Description |
|---------|-------------|
| **Earn** | AI Scout (Gemini) evaluates content quality → auto-tips quality posts (score ≥7) |
| **Spend** | Use earned MNEE to pay at merchants via QR code |
| **Gasless** | Users don't pay fees; hosted relayer handles Ethereum gas |

---

## 🎬 Demo Flow

1. **Open App** → Install APK on Android device
2. **Earn Tab** → Paste quality content (tweet, article, etc.)
3. **AI Evaluates** → Gemini scores 1-10, if ≥7 you earn 0.1 MNEE
4. **Spend Tab** → Tap "Use Demo QR (Coffee Shop)"
5. **Pay** → Choose "Demo Pay" or "🔗 Real Tx (On-chain)"
6. **Verify** → Real tx shows Etherscan link with tx hash

---

## 🧪 For Judges: How to Test

### Step 1: Install APK
Download and install the provided APK on your Android device.

### Step 2: Test Earn Feature
1. Go to **Earn** tab
2. Paste quality content (e.g., educational tweet about blockchain)
3. Tap **"Evaluate with Gemini AI"**
4. If score ≥7, you'll see 0.1 MNEE added to your balance

### Step 3: Test Spend Feature
1. Go to **Spend** tab
2. Tap **"Use Demo QR (Coffee Shop)"** — loads demo merchant ($0.08)
3. Choose payment option:
   - **Demo Pay** → Simulated payment (no real tx)
   - **🔗 Real Tx (On-chain)** → Real Ethereum tx, verifiable on Etherscan

### Step 4: Verify On-chain Transaction
After a real tx, the app shows:
- ✅ "Real Payment Success!"
- Tx hash (e.g., `0x806751f21ca1ea8b5dd882efcce81d4...`)
- **"View on Etherscan!"** link

Click to verify the actual MNEE ERC-20 transfer on Ethereum mainnet.

---

## ⚠️ Important Notes

### Why is this repo private?

This MVP uses a **hosted relayer wallet** to provide gasless UX:
- Relayer pays ETH gas fees
- Relayer sends MNEE tokens on behalf of users

To prevent abuse (random people draining the relayer), this repo is kept **private** during the hackathon. Source code is provided as ZIP for review.

### Guardrails (Anti-Abuse)

| Rule | Value | Description |
|------|-------|-------------|
| Daily Limit | 10 MNEE | Max tips per day |
| Anti-Spam | 5 min | Cooldown between actions |
| Tip Amount | 0.1 MNEE | Fixed tip per quality content |

---

## ▶️ Run From Source (Optional)

If you want to run the project from source (instead of using the APK), use the hosted backend URL below, or run the backend locally.

### Prerequisites

- Flutter SDK (stable)
- Android Studio + Android SDK (or `adb` available)
- Node.js 18+ (for `backend/`)

### Option A (Fastest): Run app with hosted backend

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://mnee-pulse-production.up.railway.app
```

### Option B: Run backend locally

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

Then run the app pointing to your machine IP (phone and PC must be on the same WiFi):

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Note: set `DRY_RUN=true` in `backend/.env` if you want to ensure no on-chain funds are spent.

---

## 📦 Build & Install Release APK

Build:

```bash
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://mnee-pulse-production.up.railway.app
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

Install via ADB (optional):

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 🚀 Roadmap: Public Release

For production / public use, we plan to integrate **self-custodial wallets**:

- **WalletConnect** integration → Users sign their own transactions
- **Each user pays their own ETH gas** and uses their own MNEE balance
- Backend remains for AI scoring, QR parsing, and analytics

This hackathon MVP demonstrates the end-to-end flow. Self-custody is the next milestone.

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter (Android, iOS, Web) |
| Backend | Node.js + Express + TypeScript |
| Blockchain | Ethereum + ethers.js |
| Token | MNEE ERC-20 |
| AI | Google Gemini API |
| Hosting | Railway |

---

## 📁 Project Structure

```
mnee-pulse/
├── lib/                 # Flutter mobile app
│   └── src/
│       ├── screens/     # Earn & Spend UI
│       ├── services/    # API client
│       └── theme.dart   # Dark theme
├── backend/             # Express + ethers.js
│   └── src/
│       ├── index.ts     # API routes
│       ├── mneeEth.ts   # MNEE ERC-20 transfers
│       ├── gemini.ts    # AI content scoring
│       └── store.ts     # JSON storage
└── android/ios/web/     # Platform configs
```

---

## 🔗 Links

- **MNEE Contract**: [Etherscan](https://etherscan.io/address/0x8ccedbAe4916b79da7F3F612EfB2EB93A2bFD6cF)
- **MNEE Website**: [mnee.io](https://mnee.io)
- **Hackathon**: [mnee-eth.devpost.com](https://mnee-eth.devpost.com)

---

## 📄 License

MIT
