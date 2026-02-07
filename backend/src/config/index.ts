import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

interface Config {
  port: number;
  nodeEnv: string;
  databaseUrl: string;
  jwtSecret: string;
  jwtExpiry: string;
  corsOrigin: string;
  redisUrl: string;
  apiRateLimit: number;
}

function requireEnv(key: string, defaultValue?: string): string {
  const value = process.env[key] ?? defaultValue;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

const config: Config = {
  port: parseInt(requireEnv('PORT', '3001'), 10),
  nodeEnv: requireEnv('NODE_ENV', 'development'),
  databaseUrl: requireEnv(
    'DATABASE_URL',
    'postgresql://securus:securus_password@localhost:5432/securus_db'
  ),
  jwtSecret: requireEnv('JWT_SECRET', 'dev-secret-change-in-production'),
  jwtExpiry: requireEnv('JWT_EXPIRY', '24h'),
  corsOrigin: requireEnv('CORS_ORIGIN', 'http://localhost:3000'),
  redisUrl: requireEnv('REDIS_URL', 'redis://localhost:6379'),
  apiRateLimit: parseInt(requireEnv('API_RATE_LIMIT', '100'), 10),
};

export default config;
