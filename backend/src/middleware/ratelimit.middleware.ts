import { Request, Response, NextFunction } from 'express';
import { RateLimitError } from '../errors/AppError';
import config from '../config';

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

const WINDOW_MS = 60 * 1000; // 1-minute sliding window
const store = new Map<string, RateLimitEntry>();

// Periodic cleanup of expired entries to prevent memory leaks
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of store) {
    if (now > entry.resetTime) {
      store.delete(key);
    }
  }
}, 60 * 1000);

function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string') {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket.remoteAddress || 'unknown';
}

export function rateLimitMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const ip = getClientIp(req);
  const now = Date.now();
  const limit = config.apiRateLimit;

  let entry = store.get(ip);

  if (!entry || now > entry.resetTime) {
    entry = {
      count: 0,
      resetTime: now + WINDOW_MS,
    };
    store.set(ip, entry);
  }

  entry.count++;

  // Set rate limit headers
  const remaining = Math.max(0, limit - entry.count);
  const resetSeconds = Math.ceil((entry.resetTime - now) / 1000);

  res.setHeader('X-RateLimit-Limit', limit);
  res.setHeader('X-RateLimit-Remaining', remaining);
  res.setHeader('X-RateLimit-Reset', resetSeconds);

  if (entry.count > limit) {
    res.setHeader('Retry-After', resetSeconds);
    next(new RateLimitError(
      `Rate limit exceeded. Try again in ${resetSeconds} seconds.`
    ));
    return;
  }

  next();
}
