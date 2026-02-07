import crypto from 'crypto';
import pool from '../config/database';
import { App } from '../models';
import { NotFoundError, ForbiddenError } from '../errors/AppError';
import { logger } from '../utils/logger';

function generateApiKey(): string {
  // Generate a secure, URL-safe API key prefixed with "sk_" for identification
  const randomBytes = crypto.randomBytes(32).toString('hex');
  return `sk_${randomBytes}`;
}

export async function createApp(
  developerId: string,
  name: string,
  platform: string = 'ios'
): Promise<App> {
  const apiKey = generateApiKey();

  const result = await pool.query(
    `INSERT INTO apps (developer_id, name, api_key, platform, status)
     VALUES ($1, $2, $3, $4, 'active')
     RETURNING *`,
    [developerId, name, apiKey, platform]
  );

  const app = result.rows[0] as App;
  logger.info(`App created: ${app.name} (${app.id}) for developer ${developerId}`);
  return app;
}

export async function listApps(developerId: string): Promise<App[]> {
  const result = await pool.query(
    `SELECT * FROM apps
     WHERE developer_id = $1
     ORDER BY created_at DESC`,
    [developerId]
  );

  return result.rows as App[];
}

export async function getAppById(
  developerId: string,
  appId: string
): Promise<App> {
  const result = await pool.query(
    'SELECT * FROM apps WHERE id = $1',
    [appId]
  );

  if (result.rows.length === 0) {
    throw new NotFoundError('App not found');
  }

  const app = result.rows[0] as App;

  if (app.developer_id !== developerId) {
    throw new ForbiddenError('You do not have access to this app');
  }

  return app;
}

export async function deleteApp(
  developerId: string,
  appId: string
): Promise<void> {
  // Verify ownership first
  const existing = await pool.query(
    'SELECT id, developer_id FROM apps WHERE id = $1',
    [appId]
  );

  if (existing.rows.length === 0) {
    throw new NotFoundError('App not found');
  }

  if (existing.rows[0].developer_id !== developerId) {
    throw new ForbiddenError('You do not have access to this app');
  }

  await pool.query('DELETE FROM apps WHERE id = $1', [appId]);

  logger.info(`App deleted: ${appId} by developer ${developerId}`);
}
