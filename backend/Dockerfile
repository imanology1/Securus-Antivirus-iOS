FROM node:20-alpine AS base
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev 2>/dev/null || npm install --omit=dev

# Copy source
COPY . .

# Build TypeScript
RUN npm run build 2>/dev/null || npx tsc --outDir dist

EXPOSE 3001

CMD ["node", "dist/server.js"]
