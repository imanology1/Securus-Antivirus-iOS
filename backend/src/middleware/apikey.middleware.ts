import { Request, Response, NextFunction } from 'express';
import { AuthenticationError } from '../errors/AppError';
import pool from '../config/database';
import { logger } from '../utils/logger';

export async function apiKeyMiddleware(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const apiKey = req.headers['x-api-key'] as string | undefined;

    if (!apiKey) {
      throw new AuthenticationError('X-API-Key header is required');
    }

    const result = await pool.query(
      `SELECT id, developer_id, name, api_key, platform, created_at, status
       FROM apps
       WHERE api_key = $1 AND status = 'active'`,
      [apiKey]
    );

    if (result.rows.length === 0) {
      throw new AuthenticationError('Invalid or inactive API key');
    }

    req.app = result.rows[0];
    next();
  } catch (error) {
    if (error instanceof AuthenticationError) {
      next(error);
    } else {
      logger.error('API key middleware error', error as Error);
      next(new AuthenticationError('API key validation failed'));
    }
  }
}
