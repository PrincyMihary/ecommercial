import fs from 'fs';
import { Request, Response } from 'express';
import path from 'path';
import { ImageStorageException, Model3dStorageException, ValidationException } from '../../errors';

const UPLOADS_ROOT = path.join(__dirname, '..', '..', '..', 'uploads');

/**
 * POST /uploads/image?owner=shop|product — équivalent serveur de
 * ImageStorageService.pickAndStoreImage (voir migration_plan.md §14).
 * multer (voir uploads.routes.ts) a déjà validé extension/taille via
 * fileFilter + limits ; ce contrôleur ne fait que router le fichier
 * vers le bon sous-dossier et retourner l'URL relative.
 */
export async function uploadImage(req: Request, res: Response) {
  const owner = String(req.query.owner ?? '');
  if (owner !== 'shop' && owner !== 'product') {
    throw new ValidationException("Le paramètre 'owner' doit valoir 'shop' ou 'product'.");
  }
  const file = req.file;
  if (!file) {
    throw new ImageStorageException('Aucun fichier reçu.');
  }
  const folder = owner === 'shop' ? 'shops' : 'products';
  res.status(201).json({ path: `/files/${folder}/${file.filename}`, url: `/files/${folder}/${file.filename}` });
}

/** POST /uploads/model — équivalent serveur de Model3dStorageService.pickAndStoreModel. */
export async function uploadModel(req: Request, res: Response) {
  const file = req.file;
  if (!file) {
    throw new Model3dStorageException('Aucun fichier reçu.');
  }
  res.status(201).json({ path: `/files/models/${file.filename}`, url: `/files/models/${file.filename}` });
}

/**
 * Suppression best-effort — miroir de ImageStorageService.deleteImage /
 * Model3dStorageService.deleteModel : ne jamais toucher aux assets
 * Flutter embarqués (`assets/...`), un fichier déjà absent n'est pas
 * une erreur.
 */
function deleteBestEffort(relativePath: string) {
  if (relativePath.startsWith('assets/')) return;
  const cleaned = relativePath.replace(/^\/?files\//, '');
  const fullPath = path.join(UPLOADS_ROOT, cleaned);
  if (!fullPath.startsWith(UPLOADS_ROOT)) return; // garde-fou path traversal
  fs.promises.unlink(fullPath).catch(() => {
    // suppression best-effort : jamais bloquant
  });
}

export async function deleteUpload(req: Request, res: Response) {
  const target = String(req.body?.path ?? req.query.path ?? '');
  if (target.length > 0) deleteBestEffort(target);
  res.status(204).send();
}
