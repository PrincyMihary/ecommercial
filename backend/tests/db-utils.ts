import { pool } from '../src/db/pool';

/**
 * Vide toutes les tables métier avant chaque test, en réinitialisant
 * les séquences BIGSERIAL (RESTART IDENTITY) pour obtenir des ids
 * prévisibles (1, 2, 3...) dans les assertions.
 */
export async function resetDatabase(): Promise<void> {
  await pool.query(
    'TRUNCATE TABLE order_items, orders, cart_items, carts, products, shops, users RESTART IDENTITY CASCADE',
  );
}
