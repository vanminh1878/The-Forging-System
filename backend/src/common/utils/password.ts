import bcrypt from 'bcryptjs';
import { env } from '../../config/env';

export const hashPassword = (plain: string): Promise<string> => bcrypt.hash(plain, env.BCRYPT_ROUNDS);
export const verifyPassword = (plain: string, hash: string): Promise<boolean> => bcrypt.compare(plain, hash);

/** At least `min` characters containing a letter and a digit. */
export function isStrongPassword(value: string, min = 8): boolean {
  return value.length >= min && /[A-Za-z]/.test(value) && /\d/.test(value);
}
