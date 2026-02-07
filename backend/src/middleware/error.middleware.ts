import { Request, Response, NextFunction } from 'express';
import { AppError, ValidationError } from '../errors/AppError';
import { ZodError } from 'zod';
import { logger } from '../utils/logger';

interface ErrorResponse {
  status: 'error';
  code: string;
  message: string;
  details?: unknown[];
  stack?: string;
}

export function notFoundHandler(
  req: Request,
  _res: Response,
  next: NextFunction
): void {
  const error = new AppError(
    `Route not found: ${req.method} ${req.originalUrl}`,
    404,
    'ROUTE_NOT_FOUND'
  );
  next(error);
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Handle Zod validation errors
  if (err instanceof ZodError) {
    const details = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
      code: e.code,
    }));

    res.status(400).json({
      status: 'error',
      code: 'VALIDATION_ERROR',
      message: 'Request validation failed',
      details,
    } satisfies ErrorResponse);
    return;
  }

  // Handle custom application errors
  if (err instanceof AppError) {
    const response: ErrorResponse = {
      status: 'error',
      code: err.code,
      message: err.message,
    };

    if (err instanceof ValidationError && err.details.length > 0) {
      response.details = err.details;
    }

    if (process.env.NODE_ENV === 'development') {
      response.stack = err.stack;
    }

    res.status(err.statusCode).json(response);
    return;
  }

  // Handle unexpected errors
  logger.error('Unhandled error', err);

  const response: ErrorResponse = {
    status: 'error',
    code: 'INTERNAL_ERROR',
    message: process.env.NODE_ENV === 'production'
      ? 'An unexpected error occurred'
      : err.message,
  };

  if (process.env.NODE_ENV === 'development') {
    response.stack = err.stack;
  }

  res.status(500).json(response);
}
