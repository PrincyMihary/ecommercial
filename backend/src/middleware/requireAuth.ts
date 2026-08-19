import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';

export interface JwtPayload {
  sub: number;
  email: string;
}

/**
 * Vérifie le JWT porté par `Authorization: Bearer <token>` et pose
 * `req.user`. Le panier/les commandes sont TOUJOURS résolus depuis
 * `req.user.id`, jamais depuis un identifiant transmis par le client
 * (voir migration_plan.md §12 — même discipline que
 * `_getOrCreateCartId` côté SQLite).
 */
export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ code: 'UNAUTHORIZED', message: 'Authentification requise.' });
  }

  const token = header.slice('Bearer '.length).trim();
  try {
    const payload = jwt.verify(token, env.jwt.secret) as unknown as JwtPayload;
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch (err) {
    return res.status(401).json({ code: 'UNAUTHORIZED', message: 'Session invalide ou expirée.' });
  }
}

/**
 * Variante non bloquante : pose `req.user` si un token valide est
 * présent, mais laisse passer la requête dans tous les cas (utile pour
 * des routes publiques dont le comportement peut légèrement varier
 * selon la présence d'une session, si besoin futur).
 */
export function optionalAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    const token = header.slice('Bearer '.length).trim();
    try {
      const payload = jwt.verify(token, env.jwt.secret) as unknown as JwtPayload;
      req.user = { id: payload.sub, email: payload.email };
    } catch {
      // Token invalide : on continue en visiteur, sans erreur.
    }
  }
  next();
}
