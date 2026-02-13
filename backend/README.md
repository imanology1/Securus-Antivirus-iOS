# Securus Backend API

The Threat Intelligence Cloud backend for the Securus platform. Receives anonymized threat reports from iOS SDKs and serves the developer dashboard.

## Tech Stack

- **Runtime**: Node.js 20+ / TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL 16 + TimescaleDB (time-series)
- **Auth**: JWT (Bearer tokens)
- **Validation**: Zod

## Prerequisites

- Node.js 20+
- PostgreSQL 16 with TimescaleDB extension
- Redis (optional, for distributed rate limiting)

## Quick Start

### 1. Install dependencies

```bash
cd backend
npm install
```

### 2. Set up the database

```bash
# Start PostgreSQL + TimescaleDB via Docker
docker run -d --name securus-db \
  -e POSTGRES_USER=securus \
  -e POSTGRES_PASSWORD=securus_password \
  -e POSTGRES_DB=securus_db \
  -p 5432:5432 \
  timescale/timescaledb:latest-pg16

# Run migrations (applied automatically via Docker init scripts,
# or manually with psql)
psql postgresql://securus:securus_password@localhost:5432/securus_db \
  -f src/database/migrations/001_create_extensions.sql \
  -f src/database/migrations/002_create_developers_table.sql \
  -f src/database/migrations/003_create_apps_table.sql \
  -f src/database/migrations/004_create_threat_events_table.sql \
  -f src/database/migrations/005_create_subscriptions_table.sql \
  -f src/database/migrations/006_create_indexes.sql
```

### 3. Configure environment

```bash
cp .env.example .env
# Edit .env with your database credentials if different from defaults
```

### 4. Run the server

```bash
npm run dev
```

The API will be available at `http://localhost:3001`.

## API Endpoints

### Authentication
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Register a developer account |
| POST | `/api/auth/login` | Login, receive JWT token |
| GET | `/api/auth/me` | Get current developer profile |

### SDK Reporting (API Key auth)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/report` | Submit anonymized threat event |

### Threats (JWT auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/threats` | List threats (paginated, filterable) |
| GET | `/api/v1/threats/stats` | Aggregated threat statistics |

### Apps (JWT auth)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/apps` | Register a new app, get API key |
| GET | `/api/v1/apps` | List your apps |
| GET | `/api/v1/apps/:id` | Get app details |
| DELETE | `/api/v1/apps/:id` | Delete an app |

### Analytics (JWT auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/analytics/overview` | Dashboard overview stats |
| GET | `/api/v1/analytics/timeline` | Time-series threat data |

### Health
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check with DB status |

## Threat Report Payload

```json
{
  "threat_id": "unique-event-id",
  "threat_type": "network_anomaly",
  "severity": "high",
  "metadata": {
    "destination_hash": "sha256..."
  },
  "app_token": "anonymous-device-token",
  "sdk_version": "1.0.0",
  "os_version": "17.1.2"
}
```

PII is automatically rejected — any payload containing email addresses, phone numbers, or other personal data returns `400 Bad Request`.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server with hot reload |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled production build |
| `npm test` | Run test suite |
| `npm run lint` | Type-check without emitting |

## Docker

```bash
docker build -t securus-backend .
docker run -p 3001:3001 --env-file .env securus-backend
```

Or use the root `docker-compose.yml` to start everything together.

## License

See [LICENSE](../LICENSE) for details.
