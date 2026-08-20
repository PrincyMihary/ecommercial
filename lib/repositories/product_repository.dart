import '../models/order.dart';
import '../models/product.dart';
import '../services/api_client.dart';

/// Accès aux données Produits (Products) via l'API REST du backend.
///
/// Couvre uniquement les opérations réellement exposées par
/// `products.routes.ts` (et `GET /shops/:shopId/products`, déclarée
/// sous le router `shops` côté backend mais qui retourne des produits
/// — voir `shops.routes.ts` : `listProductsByShop` y est directement
/// importée du contrôleur products) :
///
///   - `GET    /products`
///   - `GET    /products/search`
///   - `GET    /products/mine`
///   - `GET    /products/:id`
///   - `GET    /products/:id/blocking-orders`
///   - `GET    /shops/:shopId/products`
///   - `POST   /products`
///   - `PUT    /products/:id`
///   - `DELETE /products/:id`
///
/// Strictement un accès aux données : aucune règle métier ici. Les
/// contrôles d'ownership (ex : "ce produit m'appartient-il ?") sont
/// déjà appliqués côté backend (`assertProductOwnership`,
/// `createProductForOwner` qui déduit `shopId` du vendeur
/// authentifié) et remontent sous forme d'[ApiException].
class ProductRepository {
  ProductRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /products` — tous les produits.
  Future<List<Product>> getAll() async {
    final response = await _api.get('/products') as List<dynamic>;
    return _decodeList(response);
  }

  /// `GET /products/:id` — un produit par id.
  ///
  /// Le backend répond 404 (`NOT_FOUND`) si le produit n'existe pas ;
  /// cette erreur remonte telle quelle sous forme d'[ApiException],
  /// contrairement à `DatabaseHelper.getProductById` qui renvoyait
  /// `null`.
  Future<Product> getById(int id) async {
    final response = await _api.get('/products/$id') as Map<String, dynamic>;
    return Product.fromApiJson(response);
  }

  /// `GET /shops/:shopId/products` — produits d'un commerce donné.
  ///
  /// Équivalent REST de `DatabaseHelper.getProductsByShop`.
  Future<List<Product>> getByShop(int shopId) async {
    final response = await _api.get('/shops/$shopId/products') as List<dynamic>;
    return _decodeList(response);
  }

  /// `GET /products/mine` — produits du vendeur authentifié.
  ///
  /// Équivalent REST de
  /// `DatabaseHelper.getProductsByOwner(user.id)`, mais résolu
  /// entièrement côté backend (l'id du commerce n'a pas besoin
  /// d'être connu côté client au préalable, contrairement à
  /// l'implémentation SQLite qui appelait d'abord
  /// `getShopByOwnerId`).
  Future<List<Product>> getMine() async {
    final response = await _api.get('/products/mine') as List<dynamic>;
    return _decodeList(response);
  }

  /// `GET /products/search?q=&category=` — recherche/filtre combinés.
  ///
  /// Équivalent REST de `DatabaseHelper.searchProducts`. `category`
  /// vaut `'Tout'` côté UI pour "pas de filtre" (voir
  /// `home_screen.dart`/`search_screen.dart`) : ce repository ne
  /// réinterprète pas cette convention, il transmet tel quel — c'est
  /// au futur appelant (ou à un `ProductService` si un jour créé) de
  /// décider s'il l'envoie ou l'omet.
  Future<List<Product>> search({String? query, String? category}) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    final response =
    await _api.get('/products/search', queryParams: params) as List<dynamic>;
    return _decodeList(response);
  }

  /// `POST /products` — crée un produit pour le vendeur authentifié.
  ///
  /// `shopId` est déduit du commerce du vendeur authentifié côté
  /// backend (`createProductForOwner`), jamais envoyé par le client
  /// (voir [Product.toApiJson]). Le backend répond 409
  /// (`SHOP_ERROR`) si l'appelant n'a pas encore de commerce — même
  /// message que `DatabaseHelper.createProductForOwner`.
  Future<Product> create(Product product) async {
    final response =
    await _api.post('/products', body: product.toApiJson()) as Map<String, dynamic>;
    return Product.fromApiJson(response);
  }

  /// `PUT /products/:id` — met à jour un produit (partiel côté
  /// backend : seuls les champs non-`undefined` du body sont
  /// appliqués, voir `parseProductInput(body, partial: true)`).
  ///
  /// [product] doit ici représenter l'état complet souhaité : ce
  /// repository sérialise systématiquement tous les champs de
  /// [Product] (voir [Product.toApiJson]) — pas de mise à jour
  /// champ-par-champ pour l'instant, la même limitation existe déjà
  /// dans `DatabaseHelper.updateProductForOwner`.
  Future<Product> update(int id, Product product) async {
    final response = await _api.put('/products/$id', body: product.toApiJson())
    as Map<String, dynamic>;
    return Product.fromApiJson(response);
  }

  /// `DELETE /products/:id` — supprime un produit.
  ///
  /// Le backend refuse (409 `BLOCKING_ORDERS`) si le produit apparaît
  /// dans des commandes non finalisées — même règle que
  /// `DatabaseHelper.deleteProductForOwner`/`BlockingOrdersException`.
  Future<void> delete(int id) async {
    await _api.delete('/products/$id');
  }

  /// `GET /products/:id/blocking-orders` — commandes non finalisées
  /// bloquant la suppression de ce produit.
  Future<List<Order>> getBlockingOrders(int productId) async {
    final response =
    await _api.get('/products/$productId/blocking-orders') as List<dynamic>;
    return response
        .map((json) => Order.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }

  List<Product> _decodeList(List<dynamic> response) {
    return response
        .map((json) => Product.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }
}