import { Pool, PoolClient } from 'pg';
import { env } from '../config/env';

// `pg` retourne BIGINT/BIGSERIAL (OID 20, utilisé par tous nos
// identifiants) comme une chaîne JavaScript par défaut, pour ne jamais
// perdre de précision au-delà de Number.MAX_SAFE_INTEGER.
//
// Ce fichier NE reconfigure PAS le type parser global de `pg`
// (`types.setTypeParser(20, ...)`) : une conversion `parseInt` globale
// s'appliquerait à TOUT BIGINT de la connexion, sans distinction entre
// un identifiant et une éventuelle autre colonne BIGINT future, et sans
// jamais vérifier `Number.MAX_SAFE_INTEGER` — voir migration_plan.md §6-7
// et le rapport de fusion Claude 2.5.
//
// Les identifiants restent donc des `string` en interne (ce qui reste
// cohérent d'un bout à l'autre du backend : comparaisons, requêtes SQL
// et le JWT — qui embarque `sub` directement depuis la valeur lue en
// base — manipulent tous la même représentation). La conversion en
// `number` JSON n'a lieu qu'au moment explicite de construire la
// réponse API, via `toSafeApiId` (src/api/serialization.ts), appelé
// dans le DTO/mapper de chaque module (auth, shops, products, orders,
// cart) pour les champs listés dans src/api/id-paths.ts.
export const pool = new Pool({
  host: env.db.host,
  port: env.db.port,
  database: env.db.database,
  user: env.db.user,
  password: env.db.password,
});

/**
 * Exécute [fn] dans une transaction PostgreSQL : BEGIN, puis COMMIT si
 * [fn] réussit, ROLLBACK sinon (l'erreur est relancée telle quelle, y
 * compris les exceptions métier — voir src/errors.ts — pour que
 * errorHandler puisse les mapper correctement).
 *
 * Miroir direct de `db.transaction((txn) async { ... })` côté
 * DatabaseHelper (Flutter/sqflite).
 */
export async function withTransaction<T>(
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
