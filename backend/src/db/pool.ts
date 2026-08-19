import { Pool, PoolClient, types } from 'pg';
import { env } from '../config/env';

// `pg` retourne BIGINT (OID 20, utilisé par tous nos BIGSERIAL/BIGINT)
// comme une chaîne par défaut, pour ne jamais perdre de précision au-delà
// de Number.MAX_SAFE_INTEGER. À l'échelle de cette marketplace, les
// identifiants restent largement dans cette plage : on les reconvertit
// en nombre JS pour que les DTO JSON renvoient des `id` numériques
// (attendu par les modèles Dart `fromMap`, qui font `map['id'] as int`).
types.setTypeParser(20, (value: string) => parseInt(value, 10));

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
