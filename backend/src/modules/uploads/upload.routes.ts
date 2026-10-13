import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { authOf, created, handle } from '../../common/http/handler';
import { badRequest } from '../../common/errors/app-error';
import { requireAuth } from '../../common/middlewares/auth.middleware';
import { validate } from '../../common/middlewares/validate.middleware';
import { ALLOWED_IMAGE_TYPES } from './storage.service';
import type { StorageService } from './storage.service';

const query = z.object({ purpose: z.enum(['evidence', 'avatar']).default('evidence') });

/**
 * POST /uploads?purpose=evidence|avatar   (multipart field "file")
 * Returns { url }. Clients then send that URL in the business request
 * (payment evidence, delivery evidence, challenge evidence, avatar...).
 */
export function uploadRoutes(storage: StorageService): Router {
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024, files: 1 },
    fileFilter: (_req, file, cb) => cb(null, ALLOWED_IMAGE_TYPES.includes(file.mimetype)),
  });

  const r = Router();
  r.post(
    '/uploads',
    requireAuth,
    validate({ query }),
    upload.single('file'),
    handle(async (req) => {
      if (!req.file) throw badRequest('Ảnh không hợp lệ. Chỉ chấp nhận JPG, PNG, WEBP hoặc HEIC tối đa 8MB.', undefined, 'INVALID_FILE');
      const purpose = (req.query as unknown as z.infer<typeof query>).purpose;
      const stored = await storage.save({
        tenantId: req.ctx.tenantId,
        buffer: req.file.buffer,
        mimeType: req.file.mimetype,
        folder: purpose === 'avatar' ? `avatars/${authOf(req).userId}` : 'evidence',
      });
      return created({ url: stored.url });
    }),
  );
  return r;
}
