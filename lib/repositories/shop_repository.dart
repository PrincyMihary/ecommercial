import '../models/order.dart';
import '../models/shop.dart';
import '../services/api_client.dart';

/// Accès aux données Commerces (Shops) via l'API REST du backend.
///
/// Couvre uniquement les opérations réellement exposées par
/// `shops.routes.ts` :
///
///   - `GET    /shops`
///   - `GET    /shops/me`
///   - `GET    /shops/:id`
///   - `GET    /shops/:id/blocking-orders`
///   - `POST   /shops`
///   - `PUT    /shops/:id`
///   - `DELETE /shops/:id`
///
/// Ne couvre PAS `GET /shops/:shopId/products` : cette route retourne
/// des produits, donc relève de [ProductRepository]
/// (voir `product_repository.dart`, méthode `getByShop`) même si elle
/// est déclarée sous le router `shops` côté backend.
///
/// Strictement un accès aux données : aucune règle métier ici. Les
/// contrôles d'ownership (ex : "ce commerce m'appartient-il ?") sont
/// déjà appliqués côté backend (`assertShopOwnership`) et remontent
/// sous forme d'[ApiException] (403 `PERMISSION_ERROR`) — ce
/// repository ne les duplique pas.
class ShopRepository {
  ShopRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /shops` — tous les commerces.
  Future<List<Shop>> getAll() async {
    final response = await _api.get('/shops') as List<dynamic>;
    return response
        .map((json) => Shop.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `GET /shops/:id` — un commerce par id.
  ///
  /// Le backend répond 404 (`NOT_FOUND`) si le commerce n'existe pas ;
  /// cette erreur remonte telle quelle sous forme d'[ApiException],
  /// contrairement à `DatabaseHelper.getShopById` qui renvoyait
  /// `null`. C'est à l'appelant de décider comment traiter ce cas
  /// (ex : capturer l'[ApiException] 404) lors de la migration des
  /// écrans.
  Future<Shop> getById(int id) async {
    final response = await _api.get('/shops/$id') as Map<String, dynamic>;
    return Shop.fromApiJson(response);
  }

  /// `GET /shops/me` — commerce du vendeur authentifié.
  ///
  /// Équivalent REST de `DatabaseHelper.getShopByOwnerId(user.id)`.
  /// Le backend répond 404 (`NOT_FOUND`) si l'utilisateur n'a pas
  /// encore de commerce, plutôt que de renvoyer `null` : à
  /// l'appelant de capturer l'[ApiException] correspondante lors de
  /// la migration des écrans (`profile_screen.dart`,
  /// `product_form_screen.dart`, `product_list_screen.dart`,
  /// `sell_screen.dart`, `shop_form_screen.dart`).
  Future<Shop> getMine() async {
    final response = await _api.get('/shops/me') as Map<String, dynamic>;
    return Shop.fromApiJson(response);
  }

  /// `POST /shops` — crée le commerce du vendeur authentifié.
  ///
  /// `ownerId` est déduit du token côté backend, jamais envoyé par le
  /// client (voir [Shop.toApiJson]). Le backend répond 409
  /// (`SHOP_ERROR`, "Vous possédez déjà un commerce.") si l'appelant
  /// a déjà un commerce — même message que
  /// `DatabaseHelper.createShopForOwner`/`ShopException`.
  Future<Shop> create(Shop shop) async {
    final response = await _api.post('/shops', body: shop.toApiJson())
        as Map<String, dynamic>;
    return Shop.fromApiJson(response);
  }

  /// `PUT /shops/:id` — met à jour un commerce.
  ///
  /// L'ownership est vérifiée côté backend
  /// (`assertShopOwnership`) : un appel sur un commerce qui
  /// n'appartient pas à l'utilisateur authentifié lève une
  /// [ApiException] 403.
  Future<Shop> update(int id, Shop shop) async {
    final response = await _api.put('/shops/$id', body: shop.toApiJson())
        as Map<String, dynamic>;
    return Shop.fromApiJson(response);
  }

  /// `DELETE /shops/:id` — supprime un commerce.
  ///
  /// Le backend refuse (409 `BLOCKING_ORDERS`, avec la liste des
  /// commandes concernées) si le commerce apparaît dans des commandes
  /// non finalisées — même règle que
  /// `DatabaseHelper.deleteShopCascade`/`BlockingOrdersException`.
  /// Cette liste n'est PAS reconstruite ici : ce repository ne fait
  /// que transporter l'[ApiException] ; sa traduction éventuelle en
  /// une exception Dart dédiée avec `orders` typé est un travail
  /// restant (voir rapport §10, la remarque sur
  /// `errorHandler.ts`/champ `code`).
  Future<void> delete(int id) async {
    await _api.delete('/shops/$id');
  }

  /// `GET /shops/:id/blocking-orders` — commandes non finalisées
  /// bloquant la suppression de ce commerce.
  Future<List<Order>> getBlockingOrders(int shopId) async {
    final response =
        await _api.get('/shops/$shopId/blocking-orders') as List<dynamic>;
    return response
        .map((json) => Order.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }
}
