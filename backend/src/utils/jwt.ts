import jwt, { JwtPayload } from 'jsonwebtoken';
import config from '../config';

export interface TokenPayload extends JwtPayload {
  developerId: string;
  email: string;
}

export function signToken(payload: { developerId: string; email: string }): string {
  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtExpiry,
    issuer: 'securus-api',
    audience: 'securus-dashboard',
  });
}

export function verifyToken(token: string): TokenPayload {
  return jwt.verify(token, config.jwtSecret, {
    issuer: 'securus-api',
    audience: 'securus-dashboard',
  }) as TokenPayload;
}
