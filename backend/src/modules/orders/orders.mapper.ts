import { OrderItemRow, OrderRow } from './orders.repository';

/** DTO commun (camelCase) pour une commande, réutilisé par le module
 * orders lui-même mais aussi par shops/products (endpoints
 * blocking-orders, voir migration_plan.md §9). */
export function orderDto(order: OrderRow & { item_count?: unknown; shop_item_count?: unknown; shop_total?: unknown }) {
  return {
    id: order.id,
    userId: order.user_id,
    total: Number(order.total),
    status: order.status,
    paymentMethod: order.payment_method,
    createdAt: order.created_at,
    updatedAt: order.updated_at,
    ...(order.item_count !== undefined ? { itemCount: Number(order.item_count) } : {}),
    ...(order.shop_item_count !== undefined ? { shopItemCount: Number(order.shop_item_count) } : {}),
    ...(order.shop_total !== undefined ? { shopTotal: Number(order.shop_total) } : {}),
  };
}

export function orderItemDto(item: OrderItemRow) {
  return {
    id: item.id,
    orderId: item.order_id,
    productId: item.product_id,
    productName: item.product_name,
    quantity: item.quantity,
    price: Number(item.price),
    shopId: item.shop_id,
    shopName: item.shop_name,
  };
}
