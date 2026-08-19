import express, { NextFunction, Request, Response } from 'express';

/**
 * Application Express minimale.
 *
 * Volontairement sans routes métier (/auth, /shops, /products, /cart,
 * /orders, /uploads) : elles seront ajoutées par les agents suivants,
 * chacun dans son propre module sous src/modules/.
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

  // 404 générique pour toute route non définie.
  app.use((_req: Request, res: Response) => {
    res.status(404).json({ error: 'Not Found' });
  });

  // Gestionnaire d'erreurs générique, en dernier recours. Les modules
  // métier suivants pourront le remplacer/étendre par un middleware
  // d'erreurs plus riche (mapping des exceptions métier -> codes HTTP,
  // voir le plan de migration).
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    // eslint-disable-next-line no-console
    console.error(err);
    res.status(500).json({ error: 'Internal Server Error' });
  });

  return app;
}
