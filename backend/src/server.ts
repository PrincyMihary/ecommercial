import { app } from './app';
import { env } from './config/env';
import { pool } from './db/pool';

const server = app.listen(env.port, () => {
  console.log(`ecommercial-backend en écoute sur http://localhost:${env.port}`);
});

async function shutdown(signal: string) {
  console.log(`\n${signal} reçu, arrêt en cours...`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
