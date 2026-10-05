import { createApp } from './app';
import { env } from './config/env';
import { db } from './db/database';
import { startScheduler } from './jobs/scheduler';
import { logger } from './common/utils/logger';

const { app, container } = createApp();

const server = app.listen(env.PORT, () => {
  logger.info(`HVP API listening on :${env.PORT} (${env.NODE_ENV})`);
});

const scheduler = env.ENABLE_SCHEDULER ? startScheduler(container) : null;

async function shutdown(signal: string): Promise<void> {
  logger.info({ signal }, 'shutting down');
  scheduler?.stop();
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));
