import '../models/cart_item.dart';
import '../services/api_client.dart';

/// Résultat de [CartRepository.addItem] : quantité réellement ajoutée
/// (peut être inférieure à la quantité demandée si le stock est
/// limité, `0` si indisponible — même sémantique que
/// `DatabaseHelper.addCartItem`) et état complet du panier après
/// l'ajout, renvoyés ensemble par `POST /cart/items` (voir
/// `cart.controller.ts`, fonction `addItem`) pour éviter un
/// aller-retour réseau supplémentaire.
class CartAddResult {
  final int added;
  final List<CartItem> items;
  const CartAddResult({required this.added, required this.items});
}

/// Accès aux données Panier (Cart) via l'API REST du backend.
///
/// Couvre uniquement les opérations réellement exposées par
/// `cart.routes.ts` :
///
///   - `GET    /cart`
///   - `GET    /cart/count`
///   - `POST   /cart/items`
///   - `PUT    /cart/items/:productId`
///   - `DELETE /cart/items/:productId`
///   - `DELETE /cart`
///
/// Toutes les routes de ce module exigent un token (voir
/// `cartRouter.use(requireAuth)`) : le panier est TOUJOURS celui de
/// l'utilisateur authentifié, résolu implicitement côté backend
/// depuis le token — il n'y a jamais de `userId` explicite dans les
/// appels, contrairement à `DatabaseHelper` où chaque méthode prenait
/// un `userId` en paramètre.
///
/// PAS d'équivalent REST à `DatabaseHelper.getOrCreateCart` /
/// `_getOrCreateCartId` : côté backend, le panier d'un utilisateur
/// authentifié est résolu (et créé si besoin) de façon transparente à
/// l'intérieur de chaque opération (`cart.repository.ts`), jamais
/// exposé comme une ressource à récupérer explicitement. Ce
/// repository n'a donc pas de méthode équivalente — voir rapport
/// §2/§10.
///
/// Ce repository ne gère PAS le panier "visiteur" (non authentifié,
/// en mémoire uniquement) : cette distinction reste, par conception,
/// une responsabilité de [CartService] (voir rapport §3), qui ne
/// doit consulter ce repository que pour son régime "utilisateur
/// connecté".
class CartRepository {
  CartRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /cart` — lignes du panier de l'utilisateur authentifié.
  Future<List<CartItem>> getItems() async {
    final response = await _api.get('/cart') as List<dynamic>;
    return _decodeList(response);
  }

  /// `GET /cart/count` — nombre total d'articles (somme des
  /// quantités), pour un badge par exemple.
  Future<int> getItemCount() async {
    final response = await _api.get('/cart/count') as Map<String, dynamic>;
    return response['count'] as int? ?? 0;
  }

  /// `POST /cart/items` — ajoute [quantity] unité(s) du produit
  /// [productId]. Le stock est revérifié côté backend au moment de
  /// l'écriture (même garantie que `DatabaseHelper.addCartItem`).
  Future<CartAddResult> addItem(int productId, int quantity) async {
    final response = await _api.post('/cart/items', body: {
      'productId': productId,
      'quantity': quantity,
    }) as Map<String, dynamic>;
    return CartAddResult(
      added: response['added'] as int? ?? 0,
      items: _decodeList(response['items'] as List<dynamic>? ?? const []),
    );
  }

  /// `PUT /cart/items/:productId` — fixe directement la quantité
  /// (plafonnée au stock actuel côté backend, `quantity <= 0` retire
  /// la ligne — même sémantique que
  /// `DatabaseHelper.updateCartItemQuantity`). Retourne l'état complet
  /// du panier après modification.
  Future<List<CartItem>> updateItemQuantity(int productId, int quantity) async {
    final response = await _api.put('/cart/items/$productId', body: {
      'quantity': quantity,
    }) as List<dynamic>;
    return _decodeList(response);
  }

  /// `DELETE /cart/items/:productId` — retire une ligne. Retourne
  /// l'état complet du panier après suppression.
  Future<List<CartItem>> removeItem(int productId) async {
    final response = await _api.delete('/cart/items/$productId') as List<dynamic>;
    return _decodeList(response);
  }

  /// `DELETE /cart` — vide le panier.
  Future<void> clear() async {
    await _api.delete('/cart');
  }

  List<CartItem> _decodeList(List<dynamic> response) {
    return response
        .map((json) => CartItem.fromApiJson(json as Map<String, dynamic>))
        .toList();
  }
}