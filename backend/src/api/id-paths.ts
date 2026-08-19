/**
 * Explicit API serialization paths for PostgreSQL BIGINT/BIGSERIAL IDs.
 *
 * Only fields listed here are eligible for conversion to JSON numbers.
 * Future modules should add their response-specific paths here instead of
 * converting database values ad hoc in repositories/controllers.
 */
export const API_ID_PATHS = {
  authUser: ['user.id'],
  shop: ['shop.id'],
  product: ['product.id'],
  order: ['order.id'],
  orderItem: ['order_item.id'],
} as const;
