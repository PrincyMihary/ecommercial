import express, { Request, Response } from 'express';
import { errorHandler } from './middleware/errorHandler';
import authRoutes from './modules/auth/auth.routes';
import usersRoutes from './modules/users/users.routes';

/**
 * Application Express.
 *
 * Fondation d'Agent 1 conservée telle quelle (health check, structure
 * générale). Ajout d'Agent 2 : module Auth (/auth/register,
 * /auth/login, /users/me) et remplacement du handler d'erreurs
 * générique par `errorHandler` (src/middleware/errorHandler.ts),
 * réutilisable par les modules futurs (shops, products, cart, orders,
 * uploads) via `AppError`.
 */
export function createApp() {
  const app = express();

  app.use(express.json());

  // Route de health check : permet de vérifier que le serveur tourne et
  // répond, avant même qu'aucune route métier n'existe.
  app.get('/health', (_req: Request, res: Response) => {
    res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
    });
  });

  app.use('/auth', authRoutes);
  app.use('/users', usersRoutes);

  // 404 générique pour toute route non définie.
  app.use((_req: Request, res: Response) => {
    res.status(404).json({ code: 'NOT_FOUND', message: 'Not Found' });
  });

  // Gestionnaire d'erreurs centralisé (voir src/middleware/errorHandler.ts).
  app.use(errorHandler);

  return app;
}
