import { Pool } from 'pg';
import { env } from '../config/env';

/**
 * Pool de connexion PostgreSQL centralisé, unique pour toute
 * l'application. Les modules métier (Auth, Shops, Products, Cart,
 * Orders, Uploads) doivent importer `pool` depuis ce fichier plutôt que
 * d'instancier leur propre client.
 *
 * Ce fichier ne contient volontairement aucune requête ni logique
 * métier : uniquement la connexion.
 */
export const pool = new Pool({
  connectionString: env.databaseUrl,
});

pool.on('error', (err) => {
  // Erreur sur une connexion inactive du pool (ex. connexion perdue) :
  // on logue sans faire planter le process, le pool en récupérera une
  // nouvelle au prochain appel.
  // eslint-disable-next-line no-console
  console.error('Erreur inattendue sur le pool PostgreSQL', err);
});

/**
 * Vérifie que la base est joignable. Utile au démarrage du serveur pour
 * échouer rapidement si PostgreSQL n'est pas lancé, plutôt que de
 * démarrer un serveur HTTP qui échouera au premier appel DB.
 */
export async function checkDatabaseConnection(): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
  } finally {
    client.release();
  }
}
