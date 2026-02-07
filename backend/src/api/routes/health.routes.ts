import { Router, Request, Response } from 'express';
import { checkDatabaseHealth } from '../../config/database';

const router = Router();

// GET /health - Health check endpoint with database connectivity verification
router.get('/health', async (_req: Request, res: Response) => {
  const dbHealthy = await checkDatabaseHealth();

  const status = dbHealthy ? 'healthy' : 'degraded';
  const statusCode = dbHealthy ? 200 : 503;

  res.status(statusCode).json({
    status,
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    checks: {
      database: dbHealthy ? 'connected' : 'disconnected',
    },
  });
});

export default router;
