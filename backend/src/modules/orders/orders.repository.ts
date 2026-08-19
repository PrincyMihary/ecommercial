import { PoolClient } from 'pg';
import { pool, withTransaction } from '../../db/pool';
import { OrderException, PermissionException } from '../../errors';
import { canTransition, label, OrderStatus, TERMINAL_STATUSES } from './order-status';

export interface OrderRow {
  id: number;
  user_id: number | null;
  total: string;
  status: string;
  payment_method: string | null;
  created_at: string;
  updated_at: string;
}

export interface OrderItemRow {
  id: number;
  order_id: number;
  product_id: number | null;
  product_name: string | null;
  quantity: number;
  price: string;
  shop_id: number | null;
  shop_name: string | null;
}

/**
 * Commandes "bloquantes" pour un produit : celles où il apparaît et
 * dont le statut n'est pas terminal (voir
 * DatabaseHelper.getBlockingOrdersForProduct, migration_plan.md §16).
 */
export async function getBlockingOrdersForProduct(productId: number): Promise<OrderRow[]> {
  const { rows } = await pool.query<OrderRow>(
    `SELECT DISTINCT orders.*
     FROM orders
     INNER JOIN order_items ON order_items.order_id = orders.id
     WHERE order_items.product_id = $1
       AND orders.status <> ALL($2::text[])
     ORDER BY orders.created_at DESC`,
    [productId, TERMINAL_STATUSES],
  );
  return rows;
}

export async function getBlockingOrdersForShop(shopId: number): Promise<OrderRow[]> {
  const { rows } = await pool.query<OrderRow>(
    `SELECT DISTINCT orders.*
     FROM orders
     INNER JOIN order_items ON order_items.order_id = orders.id
     WHERE order_items.shop_id = $1
       AND orders.status <> ALL($2::text[])
     ORDER BY orders.created_at DESC`,
    [shopId, TERMINAL_STATUSES],
  );
  return rows;
}

export async function getOrderById(id: number): Promise<OrderRow | null> {
  const { rows } = await pool.query<OrderRow>('SELECT * FROM orders WHERE id = $1 LIMIT 1', [id]);
  return rows[0] ?? null;
}

export async function getOrderItems(orderId: number): Promise<OrderItemRow[]> {
  const { rows } = await pool.query<OrderItemRow>(
    'SELECT * FROM order_items WHERE order_id = $1 ORDER BY id ASC',
    [orderId],
  );
  return rows;
}

export async function getOrderItemsForShop(orderId: number, shopId: number): Promise<OrderItemRow[]> {
  const { rows } = await pool.query<OrderItemRow>(
    'SELECT * FROM order_items WHERE order_id = $1 AND shop_id = $2 ORDER BY id ASC',
    [orderId, shopId],
  );
  return rows;
}

export async function getOrdersByUser(userId: number) {
  const { rows } = await pool.query(
    `SELECT orders.*, COALESCE(SUM(order_items.quantity), 0) AS item_count
     FROM orders
     LEFT JOIN order_items ON order_items.order_id = orders.id
     WHERE orders.user_id = $1
     GROUP BY orders.id
     ORDER BY orders.created_at DESC`,
    [userId],
  );
  return rows;
}

export async function getOrdersForShopOwner(shopId: number) {
  const { rows } = await pool.query(
    `SELECT orders.*,
       COALESCE(SUM(CASE WHEN order_items.shop_id = $1 THEN order_items.quantity ELSE 0 END), 0) AS shop_item_count,
       COALESCE(SUM(CASE WHEN order_items.shop_id = $1 THEN order_items.quantity * order_items.price ELSE 0 END), 0.0) AS shop_total
     FROM orders
     INNER JOIN order_items ON order_items.order_id = orders.id
     WHERE orders.id IN (SELECT DISTINCT order_id FROM order_items WHERE shop_id = $1)
     GROUP BY orders.id
     ORDER BY orders.created_at DESC`,
    [shopId],
  );
  return rows;
}

/**
 * Checkout transactionnel — transposition de createOrder +
 * markOrderAsPaid fusionnés (voir migration_plan.md §12/§13) :
 *  1. résout le panier persisté de [userId] (409 si vide/inexistant) ;
 *  2. verrouille chaque produit du panier (`FOR UPDATE`, nécessaire dès
 *     que PostgreSQL est partagé entre requêtes concurrentes — absent
 *     de la version SQLite mono-utilisateur) ;
 *  3. vérifie le stock, calcule le total, insère `orders` + `order_items`
 *     (snapshots figés), décrémente le stock, vide `cart_items` ;
 *  4. passe directement le statut à `paid` dans la même transaction.
 *
 * Toute erreur (panier vide, stock insuffisant) fait échouer la
 * transaction entière : le panier n'est jamais partiellement vidé.
 */
export async function createOrderCheckout(userId: number, paymentMethod: string): Promise<number> {
  return withTransaction(async (client: PoolClient) => {
    const cartRes = await client.query('SELECT id FROM carts WHERE user_id = $1 LIMIT 1', [userId]);
    if (cartRes.rows.length === 0) {
      throw new OrderException('Le panier est vide.');
    }
    const cartId = cartRes.rows[0].id as number;

    const itemsRes = await client.query(
      `SELECT
         products.id AS product_id,
         products.name AS product_name,
         products.price AS price,
         products.stock AS stock,
         products.shop_id AS shop_id,
         cart_items.quantity AS quantity
       FROM cart_items
       INNER JOIN products ON products.id = cart_items.product_id
       WHERE cart_items.cart_id = $1
       FOR UPDATE OF products`,
      [cartId],
    );

    if (itemsRes.rows.length === 0) {
      throw new OrderException('Le panier est vide.');
    }

    let total = 0;
    const resolvedItems: {
      productId: number;
      productName: string;
      quantity: number;
      price: number;
      newStock: number;
      shopId: number | null;
      shopName: string | null;
    }[] = [];

    for (const row of itemsRes.rows) {
      const productId = row.product_id as number;
      const productName = (row.product_name as string) ?? '';
      const currentPrice = Number(row.price);
      const currentStock = row.stock as number;
      const shopId = row.shop_id as number | null;
      const quantity = row.quantity as number;

      if (currentStock < quantity) {
        throw new OrderException(
          `Stock insuffisant pour "${productName}" (disponible : ${currentStock}, demandé : ${quantity}).`,
        );
      }

      let shopName: string | null = null;
      if (shopId != null) {
        const shopRes = await client.query('SELECT name FROM shops WHERE id = $1 LIMIT 1', [shopId]);
        shopName = shopRes.rows[0]?.name ?? null;
      }

      total += currentPrice * quantity;
      resolvedItems.push({
        productId,
        productName,
        quantity,
        price: currentPrice,
        newStock: currentStock - quantity,
        shopId,
        shopName,
      });
    }

    const orderRes = await client.query(
      `INSERT INTO orders (user_id, total, status, payment_method)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [userId, total, OrderStatus.paid, paymentMethod],
    );
    const orderId = orderRes.rows[0].id as number;

    for (const item of resolvedItems) {
      await client.query(
        `INSERT INTO order_items (order_id, product_id, product_name, quantity, price, shop_id, shop_name)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [orderId, item.productId, item.productName, item.quantity, item.price, item.shopId, item.shopName],
      );
      await client.query('UPDATE products SET stock = $1 WHERE id = $2', [item.newStock, item.productId]);
    }

    await client.query('DELETE FROM cart_items WHERE cart_id = $1', [cartId]);

    return orderId;
  });
}

async function requireOwnerShopId(ownerId: number): Promise<number> {
  const { rows } = await pool.query('SELECT id FROM shops WHERE owner_id = $1 LIMIT 1', [ownerId]);
  if (rows.length === 0) {
    throw new PermissionException('Vous ne possédez pas de commerce.');
  }
  return rows[0].id as number;
}

export async function advanceOrderStatusForShop(ownerId: number, orderId: number, newStatus: string) {
  const shopId = await requireOwnerShopId(ownerId);

  const relevant = await getOrderItemsForShop(orderId, shopId);
  if (relevant.length === 0) {
    throw new PermissionException('Cette commande ne concerne pas votre commerce.');
  }

  const order = await getOrderById(orderId);
  if (!order) {
    throw new OrderException('Commande introuvable.');
  }

  if (!canTransition(order.status, newStatus)) {
    throw new OrderException(`Transition invalide : "${label(order.status)}" -> "${label(newStatus)}".`);
  }

  await pool.query('UPDATE orders SET status = $1 WHERE id = $2', [newStatus, orderId]);
}

export async function refundOrderForShop(ownerId: number, orderId: number) {
  const shopId = await requireOwnerShopId(ownerId);

  const relevant = await getOrderItemsForShop(orderId, shopId);
  if (relevant.length === 0) {
    throw new PermissionException('Cette commande ne concerne pas votre commerce.');
  }

  const order = await getOrderById(orderId);
  if (!order) {
    throw new OrderException('Commande introuvable.');
  }

  if (!canTransition(order.status, OrderStatus.refunded)) {
    throw new OrderException(`Impossible de rembourser une commande "${label(order.status)}".`);
  }

  await withTransaction(async (client) => {
    await client.query('UPDATE orders SET status = $1 WHERE id = $2', [OrderStatus.refunded, orderId]);
    for (const item of relevant) {
      if (item.product_id == null) continue;
      await client.query('UPDATE products SET stock = stock + $1 WHERE id = $2', [
        item.quantity,
        item.product_id,
      ]);
    }
  });
}
