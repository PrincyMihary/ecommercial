import dotenv from 'dotenv';

dotenv.config();

/**
 * Configuration centralisée du backend, lue une seule fois au démarrage.
 * Toute variable obligatoire manquante fait échouer le démarrage
 * immédiatement (fail-fast), plutôt que de laisser une erreur survenir
 * plus tard au premier appel réseau/DB.
 */
interface EnvConfig {
  port: number;
  databaseUrl: string;
  nodeEnv: string;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === '') {
    throw new Error(
      `Variable d'environnement obligatoire manquante : ${name}. ` +
        'Copiez .env.example vers .env et renseignez cette valeur.',
    );
  }
  return value;
}

function loadEnv(): EnvConfig {
  const portRaw = process.env.PORT ?? '3000';
  const port = Number(portRaw);

  if (!Number.isInteger(port) || port <= 0) {
    throw new Error(`PORT invalide : "${portRaw}". Doit être un entier positif.`);
  }

  const databaseUrl = requireEnv('DATABASE_URL');

  return {
    port,
    databaseUrl,
    nodeEnv: process.env.NODE_ENV ?? 'development',
  };
}

export const env = loadEnv();
