import http from 'http';
import app from './app';
import config from './config';
import { connectDatabase, disconnectDatabase } from './config/database';
import { logger } from './utils/logger';

const server = http.createServer(app);

async function start(): Promise<void> {
  try {
    // Test database connection before accepting requests
    await connectDatabase();
    logger.info('Database connection verified');

    server.listen(config.port, () => {
      logger.info(`Securus API server running on port ${config.port}`);
      logger.info(`Environment: ${config.nodeEnv}`);
    });
  } catch (error) {
    logger.error('Failed to start server', error as Error);
    process.exit(1);
  }
}

// Graceful shutdown handler
async function shutdown(signal: string): Promise<void> {
  logger.info(`${signal} received — shutting down gracefully`);

  server.close(() => {
    logger.info('HTTP server closed');
  });

  try {
    await disconnectDatabase();
    logger.info('Shutdown complete');
    process.exit(0);
  } catch (error) {
    logger.error('Error during shutdown', error as Error);
    process.exit(1);
  }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start();
