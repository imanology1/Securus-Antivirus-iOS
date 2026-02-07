import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';
import { AuthenticationError } from '../errors/AppError';
import pool from '../config/database';
import { logger } from '../utils/logger';

export async function authMiddleware(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      throw new AuthenticationError('Authorization header is required');
    }

    if (!authHeader.startsWith('Bearer ')) {
      throw new AuthenticationError('Authorization header must use Bearer scheme');
    }

    const token = authHeader.slice(7);

    if (!token) {
      throw new AuthenticationError('Token is required');
    }

    const payload = verifyToken(token);

    const result = await pool.query(
      'SELECT id, email, password_hash, company_name, created_at, updated_at FROM developers WHERE id = $1',
      [payload.developerId]
    );

    if (result.rows.length === 0) {
      throw new AuthenticationError('Developer account not found');
    }

    req.developer = result.rows[0];
    next();
  } catch (error) {
    if (error instanceof AuthenticationError) {
      next(error);
    } else {
      logger.error('Auth middleware error', error as Error);
      next(new AuthenticationError('Invalid or expired token'));
    }
  }
}
