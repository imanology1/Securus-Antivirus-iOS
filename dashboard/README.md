# Securus Developer Dashboard

A dark-themed React SPA for monitoring mobile app security threats in real time.

## Tech Stack

- **Framework**: React 18 + TypeScript
- **Build**: Vite 5
- **State**: Zustand
- **Charts**: Chart.js + react-chartjs-2
- **HTTP**: Axios
- **Routing**: React Router v6

## Quick Start

### 1. Install dependencies

```bash
cd dashboard
npm install
```

### 2. Start the dev server

```bash
npm run dev
```

The dashboard will be available at `http://localhost:5173`.

API calls are proxied to `http://localhost:3001` (the backend) via Vite's dev proxy.

### 3. Demo mode

The dashboard works out of the box with **mock data** — no backend required for exploring the UI. All pages render with realistic sample data when the API is unreachable.

## Pages

| Route | Page | Description |
|-------|------|-------------|
| `/` | Dashboard | Stat widgets, threat feed, world threat map |
| `/analytics` | Analytics | Time-series charts, threat distribution |
| `/configuration` | Configuration | App management, API key generation |
| `/login` | Login | Developer authentication |
| `/register` | Register | Account creation |

## Features

- **Real-time Threat Feed** — Scrolling list of recent threats with severity badges
- **Global Threat Map** — SVG world map with animated pulsing dots showing threat origins
- **Stat Cards** — Threats neutralized, devices protected, agent performance with sparklines
- **Time-Series Analytics** — Chart.js line charts with configurable time ranges
- **Threat Distribution** — Doughnut chart showing breakdown by threat type
- **App Management** — Register apps, generate/view API keys, delete apps
- **Auto-Refresh** — Dashboard refreshes every 30 seconds
- **Dark Theme** — Full dark mode with #0a0e17 background

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start Vite dev server |
| `npm run build` | Type-check and build for production |
| `npm run preview` | Preview production build |
| `npm run lint` | Run ESLint |

## Docker

```bash
docker build -t securus-dashboard .
docker run -p 5173:5173 securus-dashboard
```

Or use the root `docker-compose.yml` to start everything together.

## License

See [LICENSE](../LICENSE) for details.
