import { toSafeApiId } from '../../api/serialization';
import { OrderItemRow, OrderRow } from './orders.repository';

/** DTO commun (camelCase) pour une commande, réutilisé par le module
 * orders lui-même mais aussi par shops/products (endpoints
 * blocking-orders, voir migration_plan.md §9). */
export function orderDto(order: OrderRow & { item_count?: unknown; shop_item_count?: unknown; shop_total?: unknown }) {
  return {
    id: toSafeApiId(order.id, 'order.id'),
    userId: toSafeApiId(order.user_id, 'order.userId'),
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
    id: toSafeApiId(item.id, 'order_item.id'),
    orderId: toSafeApiId(item.order_id, 'order_item.orderId'),
    productId: toSafeApiId(item.product_id, 'order_item.productId'),
    productName: item.product_name,
    quantity: item.quantity,
    price: Number(item.price),
    shopId: toSafeApiId(item.shop_id, 'order_item.shopId'),
    shopName: item.shop_name,
  };
}
