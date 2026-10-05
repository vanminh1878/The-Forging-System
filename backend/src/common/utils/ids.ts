import { randomBytes, randomInt } from 'node:crypto';

/** Human-friendly code, e.g. member codes and redemption codes (no ambiguous characters). */
export function readableCode(prefix: string, length = 6): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i++) out += alphabet[randomInt(alphabet.length)];
  return `${prefix}-${out}`;
}

export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString('hex');
}

export function numericPin(length = 6): string {
  let out = '';
  for (let i = 0; i < length; i++) out += String(randomInt(10));
  return out;
}
