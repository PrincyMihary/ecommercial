/**
 * Référence des identifiants PostgreSQL BIGINT/BIGSERIAL exposés par
 * l'API et convertis en `number` JSON via `toSafeApiId`
 * (voir src/api/serialization.ts).
 *
 * Ce fichier ne contient pas de logique : il documente, module par
 * module, quels champs sont concernés par la convention BIGINT afin
 * que les futurs modules (Claude 3/6...) réutilisent la même liste au
 * lieu de deviner. Chaque module applique `toSafeApiId` directement
 * dans son DTO/mapper (auth.repository.toPublicUser,
 * shops.controller.toDto, products.controller.toDto,
 * orders.mapper.orderDto/orderItemDto, cart.controller.toDto).
 *
 * `API_ID_PATHS` reste disponible pour la variante `serializeApiResponse`
 * / `sendApiJson`, utile si un futur endpoint préfère convertir un
 * corps de réponse déjà construit plutôt que d'appeler `toSafeApiId`
 * champ par champ.
 */
export const API_ID_PATHS = {
  // GET /users/me, réponse de /auth/register et /auth/login
  authUser: ['user.id'],

  // GET/POST/PUT /shops...
  shop: ['id', 'ownerId'],

  // GET/POST/PUT /products...
  product: ['id', 'shopId'],

  // GET /orders..., POST /orders/checkout
  order: ['id', 'userId'],
  orderItem: ['id', 'orderId', 'productId', 'shopId'],

  // GET/POST/PUT /cart/items
  cartItem: ['productId'],
} as const;

/**
 * Champs BIGINT/BIGSERIAL couverts par la convention (voir
 * migration_plan.md §7 et le rapport de fusion Claude 2.5) :
 *   - users.id
 *   - shops.id, shops.owner_id
 *   - products.id, products.shop_id
 *   - orders.id, orders.user_id
 *   - order_items.id, order_items.order_id, order_items.product_id,
 *     order_items.shop_id
 *   - carts.id, cart_items.id (usage interne uniquement, non exposés
 *     directement par l'API — cart_items.product_id l'est via
 *     `cartItem.productId`)
 *
 * Tout autre BIGINT éventuel ajouté par un futur module NE DOIT PAS
 * être converti sans être d'abord ajouté explicitement ici.
 */
