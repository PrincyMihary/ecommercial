import { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import {
  AuthException,
  BlockingOrdersException,
  ImageStorageException,
  Model3dStorageException,
  NotFoundException,
  OrderException,
  PermissionException,
  ShopException,
  ValidationException,
} from '../errors';

/**
 * Mapping HTTP recommandé par migration_plan.md §16 :
 * - AuthException -> 400/401 (409 pour "email déjà utilisé", cf. §16 —
 *   amélioration mineure signalée par rapport au SQLite d'origine qui
 *   levait la même exception dans tous les cas)
 * - ShopException -> 409
 * - PermissionException -> 403
 * - OrderException -> 409 (404 si "introuvable")
 * - BlockingOrdersException -> 409, avec le payload `orders`
 *
 * `ApiClient` côté Flutter doit reconstruire la bonne classe
 * d'exception Dart à partir du champ `code` de la réponse JSON.
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
) {
  if (err instanceof BlockingOrdersException) {
    return res.status(409).json({ code: err.code, message: err.message, orders: err.orders });
  }

  if (err instanceof ShopException) {
    return res.status(409).json({ code: err.code, message: err.message });
  }

  if (err instanceof PermissionException) {
    return res.status(403).json({ code: err.code, message: err.message });
  }

  if (err instanceof OrderException) {
    const status = /introuvable/i.test(err.message) ? 404 : 409;
    return res.status(status).json({ code: err.code, message: err.message });
  }

  if (err instanceof AuthException) {
    const status = /déjà utilisé/i.test(err.message) ? 409 : 400;
    return res.status(status).json({ code: err.code, message: err.message });
  }

  if (err instanceof NotFoundException) {
    return res.status(404).json({ code: err.code, message: err.message });
  }

  if (err instanceof ValidationException) {
    return res.status(400).json({ code: err.code, message: err.message });
  }

  if (err instanceof ImageStorageException || err instanceof Model3dStorageException) {
    return res.status(400).json({ code: err.code, message: err.message });
  }

  // Erreurs multer (taille dépassée, extension refusée par fileFilter) —
  // voir uploads.routes.ts. Messages déjà rédigés à l'identique des
  // ImageStorageException/Model3dStorageException Dart (§14).
  if (err instanceof multer.MulterError) {
    const isModel = _req.path.includes('/model');
    if (err.code === 'LIMIT_FILE_SIZE') {
      const message = isModel
        ? 'Modèle 3D trop volumineux (maximum 50 Mo).'
        : 'Image trop volumineuse (maximum 8 Mo).';
      return res.status(400).json({ code: 'UPLOAD_TOO_LARGE', message });
    }
    return res.status(400).json({ code: 'UPLOAD_ERROR', message: err.message });
  }
  if (err instanceof Error && /Format .*non supporté/i.test(err.message)) {
    return res.status(400).json({ code: 'UPLOAD_ERROR', message: err.message });
  }

  // Violation de contrainte PostgreSQL non catchée explicitement en amont.
  const pgErr = err as { code?: string; message?: string };
  if (pgErr && pgErr.code === '23505') {
    return res.status(409).json({ code: 'UNIQUE_CONSTRAINT', message: 'Cette ressource existe déjà.' });
  }

  console.error(err);
  return res.status(500).json({ code: 'INTERNAL_ERROR', message: 'Erreur interne du serveur.' });
}

export function notFoundHandler(_req: Request, res: Response) {
  res.status(404).json({ code: 'NOT_FOUND', message: 'Route introuvable.' });
}

/** Enveloppe un handler async pour transmettre ses rejets à errorHandler. */
export function asyncHandler<T extends (...args: any[]) => Promise<any>>(fn: T) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
