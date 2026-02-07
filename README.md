# Securus

**Autonomous Security for the App Economy.**

Securus is an intelligent mobile security platform that protects iOS applications from automated attacks, runtime tampering, and network-level threats. It combines on-device AI with a cloud-based threat intelligence network to provide adaptive, privacy-first security.

## Architecture

The platform consists of three components:

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│   Securus SDK        │────▶│   Threat Intelligence │────▶│  Developer Dashboard │
│   (iOS / Swift)      │     │   Cloud (Node.js)     │     │  (React SPA)         │
│                      │◀────│                        │     │                      │
│  • Network Monitor   │     │  • POST /v1/report     │     │  • Real-time Feed    │
│  • Runtime Integrity │     │  • Analytics API       │     │  • Threat Map        │
│  • On-Device AI      │     │  • TimescaleDB         │     │  • Configuration     │
└─────────────────────┘     └──────────────────────┘     └─────────────────────┘
```

### Securus SDK (`SecurusSDK/`)
A Swift Package for iOS 17+ with three modules:
- **SecurusCore** — Agent lifecycle, Core ML anomaly detection, secure storage, anonymous tokenization
- **SecurusNetwork** — Network traffic monitoring, baseline learning, anomaly scoring, threat reporting
- **SecurusRuntime** — Jailbreak detection, debugger detection, code signature verification

### Backend (`backend/`)
Node.js/Express/TypeScript API backed by PostgreSQL + TimescaleDB:
- Receives anonymized threat reports from SDKs
- Aggregates time-series analytics
- Serves the developer dashboard

### Dashboard (`dashboard/`)
React + TypeScript SPA built with Vite:
- Real-time threat feed and global threat map
- Time-series analytics and threat distribution charts
- App registration and API key management

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 20+ (for local development)
- Xcode 16+ (for iOS SDK development)

### Running with Docker

```bash
# Start all services
docker compose up -d

# Dashboard:  http://localhost:5173
# Backend:    http://localhost:3001
# PostgreSQL: localhost:5432
```

### Local Development

```bash
# Backend
cd backend
cp .env.example .env
npm install
npm run dev

# Dashboard
cd dashboard
npm install
npm run dev
```

### iOS SDK Integration

Add the Swift Package to your Xcode project:

```
https://github.com/imanology1/Secaurus-Antivirus-iOS.git
```

```swift
import SecurusCore

// In your AppDelegate or App init
SecurusAgent.shared.configure(apiKey: "your-api-key")
SecurusAgent.shared.start()
```

## Performance Budget

| Metric | Target |
|--------|--------|
| CPU Impact | < 1% average |
| Memory Footprint | < 15 MB |
| Network Latency Overhead | < 25ms per call |

## Privacy

Securus is built with **Privacy by Design**:
- No PII is ever collected, processed, or stored
- All identifiers are anonymized on-device via SHA-256 hashing
- The SDK ships with a complete `PrivacyInfo.xcprivacy` manifest
- Threat reports contain only anonymized, non-reversible data

## Business Model

| Tier | Events/Month | Features |
|------|-------------|----------|
| **Free** | 10,000 | Core protection, community dashboard |
| **Pro** | 500,000 | Full analytics, priority support, webhooks |
| **Enterprise** | Unlimited | Custom models, SLA, dedicated support |

## License

See [LICENSE](LICENSE) for details.
