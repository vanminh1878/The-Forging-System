import cors from 'cors';
import express from 'express';
import type { Express } from 'express';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import { errorHandler, notFoundHandler } from './common/middlewares/error.middleware';
import { resolveTenant } from './common/middlewares/tenant.middleware';
import { logger } from './common/utils/logger';
import { buildContainer } from './container';
import type { Container, ContainerOverrides } from './container';
import { LocalDiskStorage } from './modules/uploads/storage.service';

export interface AppBundle {
  app: Express;
  container: Container;
}

export function createApp(overrides: ContainerOverrides = {}): AppBundle {
  const container = buildContainer(overrides);
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors());
  app.use(pinoHttp({ logger, autoLogging: { ignore: (req) => req.url === '/health' } }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', time: new Date().toISOString() });
  });

  if (container.storage instanceof LocalDiskStorage) {
    app.use('/files', express.static(container.storage.root, { fallthrough: false, index: false, maxAge: '7d' }));
  }

  app.use('/api/v1', resolveTenant, ...container.routers);
  app.use(notFoundHandler);
  app.use(errorHandler);
  return { app, container };
}
