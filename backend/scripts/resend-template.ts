import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { OTP_TEMPLATE_ALIAS } from '../src/modules/auth/otp.sender';

/**
 * Creates or updates the OTP e-mail template in Resend and publishes it.
 * Run again after editing src/modules/auth/otp-email.html.
 * Needs a "Full access" key: RESEND_ADMIN_API_KEY (falls back to RESEND_API_KEY,
 * which the API itself can keep as a "Sending access" key).
 */
const API = 'https://api.resend.com/templates';
const KEY = process.env.RESEND_ADMIN_API_KEY ?? process.env.RESEND_API_KEY;

async function call(method: string, url: string, body?: unknown): Promise<Response> {
  return fetch(url, {
    method,
    headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function ok(res: Response, step: string): Promise<void> {
  if (!res.ok) throw new Error(`${step} failed: ${res.status} ${await res.text()}`);
}

async function main(): Promise<void> {
  if (!KEY) throw new Error('Set RESEND_ADMIN_API_KEY (Full access) in backend/.env');

  const template = {
    name: 'HVP OTP',
    html: readFileSync(join(__dirname, '../src/modules/auth/otp-email.html'), 'utf8'),
    variables: [
      { key: 'HEADING', type: 'string' },
      { key: 'INTRO', type: 'string' },
      { key: 'PIN', type: 'string' },
      { key: 'TTL_MINUTES', type: 'number' },
    ],
  };

  const updated = await call('PATCH', `${API}/${OTP_TEMPLATE_ALIAS}`, template);
  if (updated.status === 404) {
    await ok(await call('POST', API, { ...template, alias: OTP_TEMPLATE_ALIAS }), 'create');
  } else {
    await ok(updated, 'update');
  }
  await ok(await call('POST', `${API}/${OTP_TEMPLATE_ALIAS}/publish`), 'publish');
  // eslint-disable-next-line no-console
  console.log(`Resend template "${OTP_TEMPLATE_ALIAS}" published`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
