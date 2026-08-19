import { Request } from 'express';
import fs from 'fs';
import multer, { FileFilterCallback } from 'multer';
import path from 'path';
import { Router } from 'express';
import { env } from '../../config/env';
import { asyncHandler } from '../../middleware/errorHandler';
import { requireAuth } from '../../middleware/requireAuth';
import { deleteUpload, uploadImage, uploadModel } from './uploads.controller';

const UPLOADS_ROOT = path.join(__dirname, '..', '..', '..', 'uploads');
const ALLOWED_IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];
const ALLOWED_MODEL_EXTENSIONS = ['glb'];

function randomSuffix(): string {
  return Math.floor(Math.random() * 0xffffff)
    .toString(16)
    .padStart(6, '0');
}

/** Nom de fichier généré côté serveur : préfixe_timestamp_random.ext — jamais le nom original (voir §14). */
function generateFileName(prefix: string, extension: string): string {
  return `${prefix}_${Date.now()}_${randomSuffix()}.${extension}`;
}

function imageStorage() {
  return multer.diskStorage({
    destination: (req: Request, _file, cb) => {
      const owner = String(req.query.owner ?? '');
      const folder = owner === 'shop' ? 'shops' : 'products';
      const dir = path.join(UPLOADS_ROOT, folder);
      fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    },
    filename: (req: Request, file, cb) => {
      const owner = String(req.query.owner ?? '');
      const prefix = owner === 'shop' ? 'shop' : 'product';
      const extension = path.extname(file.originalname).replace('.', '').toLowerCase();
      cb(null, generateFileName(prefix, extension));
    },
  });
}

function imageFileFilter(_req: Request, file: Express.Multer.File, cb: FileFilterCallback) {
  const extension = path.extname(file.originalname).replace('.', '').toLowerCase();
  if (!ALLOWED_IMAGE_EXTENSIONS.includes(extension)) {
    return cb(
      new Error(
        `Format d'image non supporté (.${extension}). Formats acceptés : ${ALLOWED_IMAGE_EXTENSIONS.join(', ')}.`,
      ),
    );
  }
  cb(null, true);
}

const modelStorage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    const dir = path.join(UPLOADS_ROOT, 'models');
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname).replace('.', '').toLowerCase();
    cb(null, generateFileName('model', extension));
  },
});

function modelFileFilter(_req: Request, file: Express.Multer.File, cb: FileFilterCallback) {
  const extension = path.extname(file.originalname).replace('.', '').toLowerCase();
  if (!ALLOWED_MODEL_EXTENSIONS.includes(extension)) {
    return cb(new Error('Format non supporté (.' + extension + '). Seul le format .glb est accepté.'));
  }
  cb(null, true);
}

const uploadImageMw = multer({
  storage: imageStorage(),
  limits: { fileSize: env.uploads.maxImageBytes },
  fileFilter: imageFileFilter,
});

const uploadModelMw = multer({
  storage: modelStorage,
  limits: { fileSize: env.uploads.maxModelBytes },
  fileFilter: modelFileFilter,
});

export const uploadsRouter = Router();
uploadsRouter.use(requireAuth);

uploadsRouter.post('/image', uploadImageMw.single('file'), asyncHandler(uploadImage));
uploadsRouter.post('/model', uploadModelMw.single('file'), asyncHandler(uploadModel));
uploadsRouter.delete('/', asyncHandler(deleteUpload));
