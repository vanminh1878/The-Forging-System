import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import type { RoleCode } from '../../shared/roles';

export interface AccessTokenClaims {
  sub: string; // user id
  tid: string; // tenant id
  roles: RoleCode[];
  bid: string | null; // branch id
}

export function signAccessToken(claims: AccessTokenClaims): string {
  return jwt.sign(claims, env.JWT_ACCESS_SECRET, { expiresIn: env.JWT_ACCESS_TTL as jwt.SignOptions['expiresIn'] });
}

export function verifyAccessToken(token: string): AccessTokenClaims {
  return jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessTokenClaims & jwt.JwtPayload;
}
