import { randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../../config/env';

export interface StoredFile {
  /** Storage key relative to the upload root, e.g. "<tenant>/2026-10/<uuid>.jpg". */
  key: string;
  /** Absolute URL clients can fetch. */
  url: string;
}

/** Strategy interface: local disk today, S3 / MinIO / GCS later without touching callers. */
export interface StorageService {
  save(input: { tenantId: string; buffer: Buffer; mimeType: string; folder: string }): Promise<StoredFile>;
}

const EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
};

export const ALLOWED_IMAGE_TYPES = Object.keys(EXTENSIONS);

export class LocalDiskStorage implements StorageService {
  constructor(
    private readonly rootDir: string = path.resolve(env.UPLOAD_DIR),
    private readonly publicBaseUrl: string = env.PUBLIC_BASE_URL,
  ) {}

  get root(): string {
    return this.rootDir;
  }

  async save(input: { tenantId: string; buffer: Buffer; mimeType: string; folder: string }): Promise<StoredFile> {
    const ext = EXTENSIONS[input.mimeType];
    if (!ext) throw new Error(`Unsupported mime type ${input.mimeType}`);
    const month = new Date().toISOString().slice(0, 7);
    const key = `${input.tenantId}/${input.folder}/${month}/${randomUUID()}.${ext}`;
    const full = path.join(this.rootDir, key);
    await mkdir(path.dirname(full), { recursive: true });
    await writeFile(full, input.buffer);
    return { key, url: `${this.publicBaseUrl.replace(/\/$/, '')}/files/${key}` };
  }
}
