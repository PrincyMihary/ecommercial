import { createApp } from './app';
import { env } from './config/env';
import { checkDatabaseConnection } from './db/pool';

async function start() {
  try {
    await checkDatabaseConnection();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(
      'Impossible de se connecter à PostgreSQL. Vérifiez que le serveur ' +
        'est lancé et que DATABASE_URL (.env) est correct.',
    );
    // eslint-disable-next-line no-console
    console.error(err);
    process.exit(1);
  }

  const app = createApp();

  const server = app.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Backend démarré sur http://localhost:${env.port}`);
    // eslint-disable-next-line no-console
    console.log(`Health check : http://localhost:${env.port}/health`);
  });

  server.on('error', (err) => {
    // eslint-disable-next-line no-console
    console.error('Erreur au démarrage du serveur HTTP', err);
    process.exit(1);
  });
}

start();
