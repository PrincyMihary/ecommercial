import { PoolClient } from 'pg';
import { pool, withTransaction } from '../../db/pool';

export interface CartItemRow {
  product_id: number;
  product_name: string;
  price: string;
  image: string | null;
  stock: number;
  quantity: number;
}

/**
 * Résout (ou crée) l'id du panier de [userId]. Reproduit
 * `_getOrCreateCartId` (database_helper.dart) : SELECT puis INSERT si
 * absent, avec un filet de sécurité en cas de course concurrente sur
 * la contrainte UNIQUE(user_id).
 */
async function getOrCreateCartId(client: PoolClient, userId: number): Promise<number> {
  const existing = await client.query('SELECT id FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
  if (existing.rows.length > 0) return existing.rows[0].id as number;

  try {
    const inserted = await client.query('INSERT INTO carts (user_id) VALUES ($1) RETURNING id', [userId]);
    return inserted.rows[0].id as number;
  } catch (err) {
    const pgErr = err as { code?: string };
    if (pgErr.code === '23505') {
      const retry = await client.query('SELECT id FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
      if (retry.rows.length > 0) return retry.rows[0].id as number;
    }
    throw err;
  }
}

async function touchCart(client: PoolClient, cartId: number): Promise<void> {
  await client.query('UPDATE carts SET updated_at = now() WHERE id = $1', [cartId]);
}

export async function getOrCreateCart(userId: number): Promise<number> {
  const existing = await pool.query('SELECT id FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
  if (existing.rows.length > 0) return existing.rows[0].id as number;

  try {
    const inserted = await pool.query('INSERT INTO carts (user_id) VALUES ($1) RETURNING id', [userId]);
    return inserted.rows[0].id as number;
  } catch (err) {
    const pgErr = err as { code?: string };
    if (pgErr.code === '23505') {
      const retry = await pool.query('SELECT id FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
      if (retry.rows.length > 0) return retry.rows[0].id as number;
    }
    throw err;
  }
}

/** Lignes du panier de [userId], nom/prix/image/stock LUS depuis `products`. */
export async function getCartItems(userId: number): Promise<CartItemRow[]> {
  const { rows } = await pool.query<CartItemRow>(
    `SELECT
       products.id AS product_id,
       products.name AS product_name,
       products.price AS price,
       products.image AS image,
       products.stock AS stock,
       cart_items.quantity AS quantity
     FROM cart_items
     INNER JOIN carts ON carts.id = cart_items.cart_id
     INNER JOIN products ON products.id = cart_items.product_id
     WHERE carts.user_id = $1
     ORDER BY cart_items.id ASC`,
    [userId],
  );
  return rows;
}

export async function getCartItemCount(userId: number): Promise<number> {
  const { rows } = await pool.query(
    `SELECT COALESCE(SUM(cart_items.quantity), 0) AS count
     FROM cart_items
     INNER JOIN carts ON carts.id = cart_items.cart_id
     WHERE carts.user_id = $1`,
    [userId],
  );
  return Number(rows[0]?.count ?? 0);
}

/**
 * Ajoute [quantity] unité(s) du produit [productId], plafonné au stock
 * réel relu dans la transaction. Retourne la quantité réellement
 * ajoutée (0 si rupture/produit introuvable) — miroir exact de
 * `DatabaseHelper.addCartItem`.
 */
export async function addCartItem(userId: number, productId: number, quantity: number): Promise<number> {
  if (quantity <= 0) return 0;

  return withTransaction(async (client) => {
    const cartId = await getOrCreateCartId(client, userId);

    const productRes = await client.query('SELECT stock FROM products WHERE id = $1 LIMIT 1 FOR UPDATE', [
      productId,
    ]);
    if (productRes.rows.length === 0) return 0;
    const stock = productRes.rows[0].stock as number;
    if (stock <= 0) return 0;

    const existing = await client.query(
      'SELECT id, quantity FROM cart_items WHERE cart_id = $1 AND product_id = $2 LIMIT 1',
      [cartId, productId],
    );

    let added: number;
    if (existing.rows.length === 0) {
      added = Math.min(quantity, stock);
      if (added <= 0) return 0;
      await client.query('INSERT INTO cart_items (cart_id, product_id, quantity) VALUES ($1, $2, $3)', [
        cartId,
        productId,
        added,
      ]);
    } else {
      const current = existing.rows[0].quantity as number;
      const maxAddable = stock - current;
      if (maxAddable <= 0) return 0;
      added = Math.min(quantity, maxAddable);
      await client.query('UPDATE cart_items SET quantity = $1 WHERE id = $2', [
        current + added,
        existing.rows[0].id,
      ]);
    }

    await touchCart(client, cartId);
    return added;
  });
}

/**
 * Fixe directement la quantité du produit, plafonnée au stock actuel.
 * `quantity <= 0` retire la ligne. Miroir de
 * `DatabaseHelper.updateCartItemQuantity`.
 */
export async function updateCartItemQuantity(userId: number, productId: number, quantity: number): Promise<void> {
  await withTransaction(async (client) => {
    const cartId = await getOrCreateCartId(client, userId);

    if (quantity <= 0) {
      await client.query('DELETE FROM cart_items WHERE cart_id = $1 AND product_id = $2', [cartId, productId]);
      await touchCart(client, cartId);
      return;
    }

    const productRes = await client.query('SELECT stock FROM products WHERE id = $1 LIMIT 1 FOR UPDATE', [
      productId,
    ]);
    if (productRes.rows.length === 0) {
      await client.query('DELETE FROM cart_items WHERE cart_id = $1 AND product_id = $2', [cartId, productId]);
      await touchCart(client, cartId);
      return;
    }

    const stock = productRes.rows[0].stock as number;
    const clamped = Math.min(quantity, stock);

    if (clamped <= 0) {
      await client.query('DELETE FROM cart_items WHERE cart_id = $1 AND product_id = $2', [cartId, productId]);
    } else {
      const updated = await client.query(
        'UPDATE cart_items SET quantity = $1 WHERE cart_id = $2 AND product_id = $3',
        [clamped, cartId, productId],
      );
      if (updated.rowCount === 0) {
        await client.query('INSERT INTO cart_items (cart_id, product_id, quantity) VALUES ($1, $2, $3)', [
          cartId,
          productId,
          clamped,
        ]);
      }
    }

    await touchCart(client, cartId);
  });
}

export async function removeCartItem(userId: number, productId: number): Promise<void> {
  await withTransaction(async (client) => {
    const cartId = await getOrCreateCartId(client, userId);
    await client.query('DELETE FROM cart_items WHERE cart_id = $1 AND product_id = $2', [cartId, productId]);
    await touchCart(client, cartId);
  });
}

export async function clearCart(userId: number): Promise<void> {
  await withTransaction(async (client) => {
    const cartId = await getOrCreateCartId(client, userId);
    await client.query('DELETE FROM cart_items WHERE cart_id = $1', [cartId]);
    await touchCart(client, cartId);
  });
}
