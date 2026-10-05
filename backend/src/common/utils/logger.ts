import pino from 'pino';
import { env, isProd } from '../../config/env';

export const logger = pino({
  level: env.NODE_ENV === 'test' ? 'silent' : env.LOG_LEVEL,
  ...(isProd ? {} : { transport: { target: 'pino-pretty', options: { colorize: true, singleLine: true } } }),
  redact: ['req.headers.authorization', 'password', 'passwordHash', 'token'],
});
