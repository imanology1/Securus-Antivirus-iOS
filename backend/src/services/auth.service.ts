import bcrypt from 'bcryptjs';
import pool from '../config/database';
import { signToken } from '../utils/jwt';
import { Developer, DeveloperPublic } from '../models';
import {
  AuthenticationError,
  ConflictError,
  NotFoundError,
} from '../errors/AppError';
import { logger } from '../utils/logger';

const SALT_ROUNDS = 12;

function toPublicDeveloper(dev: Developer): DeveloperPublic {
  return {
    id: dev.id,
    email: dev.email,
    company_name: dev.company_name,
    created_at: dev.created_at,
    updated_at: dev.updated_at,
  };
}

export async function registerDeveloper(
  email: string,
  password: string,
  companyName: string
): Promise<{ developer: DeveloperPublic; token: string }> {
  // Check if developer already exists
  const existing = await pool.query(
    'SELECT id FROM developers WHERE email = $1',
    [email.toLowerCase()]
  );

  if (existing.rows.length > 0) {
    throw new ConflictError('A developer with this email already exists');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

  const result = await pool.query(
    `INSERT INTO developers (email, password_hash, company_name)
     VALUES ($1, $2, $3)
     RETURNING id, email, password_hash, company_name, created_at, updated_at`,
    [email.toLowerCase(), passwordHash, companyName]
  );

  const developer = result.rows[0] as Developer;

  // Create a default free subscription
  await pool.query(
    `INSERT INTO subscriptions (developer_id, plan, status, events_limit)
     VALUES ($1, 'free', 'active', 10000)`,
    [developer.id]
  );

  const token = signToken({
    developerId: developer.id,
    email: developer.email,
  });

  logger.info(`Developer registered: ${developer.email}`);

  return {
    developer: toPublicDeveloper(developer),
    token,
  };
}

export async function loginDeveloper(
  email: string,
  password: string
): Promise<{ developer: DeveloperPublic; token: string }> {
  const result = await pool.query(
    `SELECT id, email, password_hash, company_name, created_at, updated_at
     FROM developers
     WHERE email = $1`,
    [email.toLowerCase()]
  );

  if (result.rows.length === 0) {
    throw new AuthenticationError('Invalid email or password');
  }

  const developer = result.rows[0] as Developer;
  const isPasswordValid = await bcrypt.compare(password, developer.password_hash);

  if (!isPasswordValid) {
    throw new AuthenticationError('Invalid email or password');
  }

  const token = signToken({
    developerId: developer.id,
    email: developer.email,
  });

  logger.info(`Developer logged in: ${developer.email}`);

  return {
    developer: toPublicDeveloper(developer),
    token,
  };
}

export async function getDeveloperById(
  id: string
): Promise<DeveloperPublic> {
  const result = await pool.query(
    `SELECT id, email, password_hash, company_name, created_at, updated_at
     FROM developers
     WHERE id = $1`,
    [id]
  );

  if (result.rows.length === 0) {
    throw new NotFoundError('Developer not found');
  }

  return toPublicDeveloper(result.rows[0] as Developer);
}
