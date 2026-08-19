import { NextFunction, Request, Response } from 'express';
import { AppError } from '../errors/AppError';

/**
 * Middleware d'erreurs centralisé, à monter en tout dernier dans
 * `app.ts`. Remplace le handler générique minimal de la fondation
 * (Agent 1) par une version qui :
 *
 * - retourne le format `{ code, message, ... }` pour toute [AppError] ;
 * - ne laisse JAMAIS fuiter une erreur SQL brute ou un détail interne
 *   au client (règle de sécurité explicite) ;
 * - logue l'erreur complète côté serveur pour le debug.
 *
 * Réutilisable tel quel par les futurs modules (shops, products, cart,
 * orders, uploads) : il leur suffit de lever une [AppError].
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      code: err.code,
      message: err.message,
      ...(err.extra ?? {}),
    });
    return;
  }

  // Erreur non anticipée (bug, erreur SQL brute, etc.) : jamais de détail
  // exposé au client, seulement loggé côté serveur.
  // eslint-disable-next-line no-console
  console.error('Erreur non gérée :', err);
  res.status(500).json({
    code: 'INTERNAL_ERROR',
    message: 'Une erreur interne est survenue.',
  });
}
