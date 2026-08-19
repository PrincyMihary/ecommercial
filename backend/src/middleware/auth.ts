import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { AppError } from '../errors/AppError';

interface JwtPayload {
  sub: number | string;
}

/**
 * Middleware d'authentification JWT, réutilisable par tous les futurs
 * modules (voir consigne : "Il doit être réutilisable par les futurs
 * modules").
 *
 * 1. récupère le token depuis `Authorization: Bearer <token>` ;
 * 2. vérifie sa signature/expiration ;
 * 3. extrait l'identifiant utilisateur (`sub`) ;
 * 4. expose `req.user = { id }` (typé via src/types/express.d.ts).
 *
 * Ne charge PAS l'utilisateur complet depuis la base ici : chaque route
 * qui en a besoin le fait elle-même (garde le middleware léger et
 * générique, sans dépendance vers un module métier précis).
 */
export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    next(new AppError(401, 'AUTH_TOKEN_MISSING', 'Authentification requise.'));
    return;
  }

  const token = header.slice('Bearer '.length).trim();
  if (token.length === 0) {
    next(new AppError(401, 'AUTH_TOKEN_MISSING', 'Authentification requise.'));
    return;
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret) as unknown as JwtPayload;
    const userId = Number(payload.sub);

    if (!Number.isInteger(userId)) {
      next(new AppError(401, 'AUTH_TOKEN_INVALID', 'Token invalide.'));
      return;
    }

    req.user = { id: userId };
    next();
  } catch {
    next(new AppError(401, 'AUTH_TOKEN_INVALID', 'Token invalide ou expiré.'));
  }
}
