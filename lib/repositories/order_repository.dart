import '../models/order.dart';
import '../models/order_item.dart';
import '../services/api_client.dart';

/// Résultat de [OrderRepository.checkout] : la commande créée et ses
/// lignes, renvoyées ensemble par `POST /orders/checkout` (voir
/// `orders.controller.ts`, fonction `checkout`) — équivalent REST de
/// `DatabaseHelper.createOrder` + `markOrderAsPaid` fusionnés (le
/// paiement mocké réussit toujours côté client, voir
/// `MockPaymentService`, donc la commande passe directement à `paid`
/// dans la même transaction côté backend).
class CheckoutResult {
  final Order order;
  final List<OrderItem> items;
  const CheckoutResult({required this.order, required this.items});
}

/// Résultat de [OrderRepository.getDetail] : la commande, ses lignes
/// (déjà filtrées côté backend selon le rôle de l'appelant — voir
/// ci-dessous), et deux indicateurs de rôle renvoyés par
/// `GET /orders/:id` (voir `orders.controller.ts`, fonction
/// `getOrderDetail`).
///
/// Durcissement de sécurité : la règle d'accès (acheteur voit tout ;
/// commerçant ne voit que ses propres lignes ; ni l'un ni l'autre =
/// 403) est désormais appliquée CÔTÉ BACKEND, avant l'envoi des
/// données — alors qu'elle était calculée côté client dans
/// `order_detail_screen.dart` avec la version SQLite. `items`
/// contient déjà le bon sous-ensemble : ce repository ne recalcule
/// rien.
class OrderDetail {
  final Order order;
  final List<OrderItem> items;
  final bool isBuyer;
  final bool isMerchant;
  const OrderDetail({
    required this.order,
    required this.items,
    required this.isBuyer,
    required this.isMerchant,
  });
}

/// Résultat de [OrderRepository.advanceStatus] : la commande mise à
/// jour et les transitions encore disponibles depuis son nouveau
/// statut, renvoyées par `PATCH /orders/:id/status` (voir
/// `orders.controller.ts`, fonction `advanceStatus`). `availableTransitions`
/// reprend `OrderStatus.availableTransitions` déjà présent côté
/// Flutter (`order_status.dart`) : ce repository ne fait que
/// transporter la liste renvoyée par le backend, sans dupliquer la
/// règle de transition elle-même.
class AdvanceStatusResult {
  final Order order;
  final List<String> availableTransitions;
  const AdvanceStatusResult({required this.order, required this.availableTransitions});
}

/// Accès aux données Commandes (Orders / Order Items) via l'API REST
/// du backend.
///
/// Couvre uniquement les opérations réellement exposées par
/// `orders.routes.ts` :
///
///   - `POST  /orders/checkout`
///   - `GET   /orders`
///   - `GET   /orders/shop`
///   - `GET   /orders/:id`
///   - `GET   /orders/:id/items/shop`
///   - `PATCH /orders/:id/status`
///   - `POST  /orders/:id/refund`
///
/// (`GET /shops/:id/blocking-orders` et
/// `GET /products/:id/blocking-orders` sont couvertes respectivement
/// par [ShopRepository.getBlockingOrders] et
/// [ProductRepository.getBlockingOrders] — mêmes DTO `Order`, mais
/// domaine d'appel différent, voir rapport §2.)
///
/// PAS d'équivalent REST à
/// `DatabaseHelper.getOrdersWithItemCount` (toutes commandes, non
/// filtrées) : le backend n'expose intentionnellement aucune route
/// "toutes les commandes" sans filtre par utilisateur — seule
/// `GET /orders` (commandes de l'appelant authentifié, voir
/// [myOrders]) existe. `order_list_screen.dart` appelle aujourd'hui
/// `getOrdersWithItemCount()` sans filtre : c'est une incompatibilité
/// réelle avec le contrat REST, à traiter explicitement lors de la
/// migration de cet écran (le remplacer par [myOrders], scoping déjà
/// correct pour un "Mes commandes" - voir rapport §10), PAS en
/// inventant une route non filtrée côté backend.
///
/// Toutes les routes de ce module exigent un token (voir
/// `ordersRouter.use(requireAuth)`) : comme pour [CartRepository],
/// il n'y a jamais de `userId`/`ownerId` explicite dans les appels.
class OrderRepository {
  OrderRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  static const List<String> validPaymentMethods = ['orange_money', 'yas', 'visa'];

  /// `POST /orders/checkout` — crée une commande à partir du panier
  /// PERSISTÉ de l'utilisateur authentifié (jamais d'une liste
  /// fournie par l'appelant, même garantie que
  /// `DatabaseHelper.createOrder`). Le backend répond 409
  /// (`ORDER_ERROR`) si le panier est vide ou si le stock est
  /// insuffisant pour une ligne — mêmes messages que
  /// `OrderException` côté SQLite.
  Future<CheckoutResult> checkout(String paymentMethod) async {
    final response = await _api.post('/orders/checkout', body: {
      'paymentMethod': paymentMethod,
    }) as Map<String, dynamic>;
    return CheckoutResult(
      order: Order.fromApiJson(response['order'] as Map<String, dynamic>),
      items: _decodeItems(response['items'] as List<dynamic>? ?? const []),
    );
  }

  /// `GET /orders` — commandes de l'acheteur authentifié.
  ///
  /// Équivalent REST de
  /// `DatabaseHelper.getOrdersByUser(user.id)`.
  Future<List<Order>> myOrders() async {
    final response = await _api.get('/orders') as List<dynamic>;
    return _decodeOrders(response);
  }

  /// `GET /orders/shop` — commandes concernant le commerce du vendeur
  /// authentifié (liste vide si l'appelant n'a pas de commerce, voir
  /// `orders.controller.ts`, fonction `ordersForMyShop`).
  ///
  /// Équivalent REST de
  /// `DatabaseHelper.getOrdersForShopOwner(user.id)`, mais résolu
  /// entièrement côté backend (pas besoin de connaître l'id du
  /// commerce au préalable côté client).
  Future<List<Order>> ordersForMyShop() async {
    final response = await _api.get('/orders/shop') as List<dynamic>;
    return _decodeOrders(response);
  }

  /// `GET /orders/:id` — détail d'une commande, avec ses lignes déjà
  /// filtrées selon le rôle de l'appelant (voir [OrderDetail]).
  Future<OrderDetail> getDetail(int orderId) async {
    final response = await _api.get('/orders/$orderId') as Map<String, dynamic>;
    return OrderDetail(
      order: Order.fromApiJson(response['order'] as Map<String, dynamic>),
      items: _decodeItems(response['items'] as List<dynamic>? ?? const []),
      isBuyer: response['isBuyer'] as bool? ?? false,
      isMerchant: response['isMerchant'] as bool? ?? false,
    );
  }

  /// `GET /orders/:id/items/shop` — lignes d'une commande concernant
  /// spécifiquement le commerce du vendeur authentifié.
  ///
  /// Équivalent REST de
  /// `DatabaseHelper.getOrderItemsForShop(orderId, shopId)`, mais
  /// `shopId` n'est plus un paramètre : résolu côté backend depuis le
  /// vendeur authentifié (répond 403 `PERMISSION_ERROR` si l'appelant
  /// n'a pas de commerce).
  Future<List<OrderItem>> getItemsForMyShop(int orderId) async {
    final response = await _api.get('/orders/$orderId/items/shop') as List<dynamic>;
    return _decodeItems(response);
  }

  /// `PATCH /orders/:id/status` — fait progresser le statut d'une
  /// commande (action commerçant). Le backend applique
  /// `assertShopOwnership`/`OrderStatus.canTransition` avant
  /// d'accepter la transition — mêmes règles, mêmes messages, que
  /// `DatabaseHelper.advanceOrderStatusForShop`.
  Future<AdvanceStatusResult> advanceStatus(int orderId, String newStatus) async {
    final response = await _api.patch('/orders/$orderId/status', body: {
      'status': newStatus,
    }) as Map<String, dynamic>;
    final transitions = (response['availableTransitions'] as List<dynamic>? ?? const [])
        .map((s) => s as String)
        .toList();
    return AdvanceStatusResult(
      order: Order.fromApiJson(response['order'] as Map<String, dynamic>),
      availableTransitions: transitions,
    );
  }

  /// `POST /orders/:id/refund` — rembourse une commande et
  /// réapprovisionne le stock des produits concernés (même
  /// transaction atomique que
  /// `DatabaseHelper.refundOrderForShop`, désormais côté backend).
  Future<Order> refund(int orderId) async {
    final response = await _api.post('/orders/$orderId/refund') as Map<String, dynamic>;
    return Order.fromApiJson(response);
  }

  List<Order> _decodeOrders(List<dynamic> response) {
    return response
        .map((json) => Order.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }

  List<OrderItem> _decodeItems(List<dynamic> response) {
    return response
        .map((json) => OrderItem.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }
}