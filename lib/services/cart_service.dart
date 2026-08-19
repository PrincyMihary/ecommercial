import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import 'auth_service.dart';

/// Service singleton de panier.
///
/// Étape 5 : le panier n'est plus une liste globale partagée. Deux
/// régimes coexistent, jamais mélangés :
///
/// - UTILISATEUR CONNECTÉ : panier persisté en SQLite (`carts` /
///   `cart_items`), strictement scellé par `user_id`. Toutes les
///   écritures passent par `DatabaseHelper`, qui résout TOUJOURS le
///   panier via `userId -> carts.user_id` — jamais un `cart_id`
///   fourni par un écran. Le `userId` lui-même n'est JAMAIS un
///   paramètre public de ce service : il est résolu en interne
///   depuis `AuthService.instance.currentUser`, pour qu'aucun écran
///   ne puisse (volontairement ou par erreur) agir sur le panier d'un
///   autre utilisateur.
/// - VISITEUR (non connecté) : panier éphémère, en mémoire
///   uniquement — jamais écrit en SQLite, jamais rattaché à un faux
///   `user_id`. Préserve la possibilité historique de consulter le
///   catalogue et utiliser un panier sans compte.
///
/// Ce service s'abonne lui-même à [AuthService] (constructeur privé)
/// pour recharger/vider automatiquement le panier à chaque
/// connexion/déconnexion, sans qu'aucun écran de login/signup/logout
/// n'ait à s'en soucier explicitement.
class CartService extends ChangeNotifier {
  CartService._() {
    AuthService.instance.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  static final CartService instance = CartService._();

  List<CartItem> _items = const [];

  /// `null` tant qu'aucun panier persisté n'est chargé (visiteur, ou
  /// chargement en cours) — détermine si les opérations passent par
  /// SQLite ou restent en mémoire.
  int? _loadedUserId;

  bool _isLoading = false;

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.total);

  bool get isLoading => _isLoading;

  /// `true` si le panier actuellement affiché est persisté (donc
  /// éligible au checkout) ; `false` pour le panier éphémère d'un
  /// visiteur.
  bool get isPersisted => _loadedUserId != null;

  int _indexOf(int productId) => _items.indexWhere((i) => i.productId == productId);

  void _onAuthChanged() {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      clearSession();
    } else if (_loadedUserId != user.id) {
      loadForUser(user.id);
    }
  }

  /// Vide UNIQUEMENT l'état mémoire (appelé à la déconnexion). Le
  /// panier persisté de l'utilisateur, lui, n'est jamais touché en
  /// base : il sera retrouvé intact à sa prochaine connexion.
  void clearSession() {
    if (_loadedUserId == null && _items.isEmpty) return;
    _items = const [];
    _loadedUserId = null;
    notifyListeners();
  }

  /// Charge le panier persisté de [userId] (le crée s'il n'existe pas
  /// encore). Si l'état actuel était un panier VISITEUR (donc
  /// `_loadedUserId == null`) avec des articles, ceux-ci sont
  /// transférés vers le panier persisté (quantités revalidées contre
  /// le stock réel par `DatabaseHelper.addCartItem`) — pour ne pas
  /// faire perdre son panier à un visiteur qui se connecte.
  Future<void> loadForUser(int userId) async {
    final guestItems =
    _loadedUserId == null ? List<CartItem>.from(_items) : const <CartItem>[];

    _isLoading = true;
    notifyListeners();

    try {
      await DatabaseHelper.instance.getOrCreateCart(userId);
      for (final item in guestItems) {
        await DatabaseHelper.instance.addCartItem(userId, item.productId, item.quantity);
      }
      await _reloadFromDb(userId);
    } finally {
      _isLoading = false;
      // _reloadFromDb notifie déjà ; ce notify supplémentaire couvre
      // le cas où la boucle ci-dessus n'a rien ajouté mais où
      // _isLoading doit tout de même redevenir false visiblement.
      notifyListeners();
    }
  }

  Future<void> _reloadFromDb(int userId) async {
    final rows = await DatabaseHelper.instance.getCartItems(userId);
    _items = rows.map(CartItem.fromMap).toList();
    _loadedUserId = userId;
    notifyListeners();
  }

  /// Ajoute [quantity] unité(s) de [product] (1 par défaut).
  ///
  /// Retourne la quantité réellement ajoutée (peut être inférieure à
  /// [quantity] si le stock est limité, 0 si indisponible). Pour un
  /// utilisateur connecté, le stock est TOUJOURS revérifié depuis
  /// `products` par `DatabaseHelper.addCartItem` au moment de
  /// l'écriture — jamais depuis une valeur mémorisée dans
  /// `CartItem.stock`.
  Future<int> addProduct(Product product, {int quantity = 1}) async {
    if (product.id == null || quantity <= 0) return 0;

    final userId = _loadedUserId;
    if (userId != null) {
      final added = await DatabaseHelper.instance.addCartItem(userId, product.id!, quantity);
      if (added > 0) await _reloadFromDb(userId);
      return added;
    }

    return _addProductGuest(product, quantity);
  }

  int _addProductGuest(Product product, int quantity) {
    if (product.stock <= 0) return 0;
    final index = _indexOf(product.id!);

    if (index == -1) {
      final added = quantity > product.stock ? product.stock : quantity;
      if (added <= 0) return 0;
      _items = [
        ..._items,
        CartItem(
          productId: product.id!,
          productName: product.name,
          price: product.price,
          image: product.image,
          quantity: added,
          stock: product.stock,
        ),
      ];
      notifyListeners();
      return added;
    }

    final current = _items[index];
    final maxAddable = current.stock - current.quantity;
    if (maxAddable <= 0) return 0;
    final added = quantity > maxAddable ? maxAddable : quantity;
    final updated = List<CartItem>.from(_items);
    updated[index] = current.copyWith(quantity: current.quantity + added);
    _items = updated;
    notifyListeners();
    return added;
  }

  Future<void> removeProduct(int productId) async {
    final userId = _loadedUserId;
    if (userId != null) {
      await DatabaseHelper.instance.removeCartItem(userId, productId);
      await _reloadFromDb(userId);
      return;
    }
    final index = _indexOf(productId);
    if (index == -1) return;
    final updated = List<CartItem>.from(_items)..removeAt(index);
    _items = updated;
    notifyListeners();
  }

  Future<void> increaseQuantity(int productId) async {
    final index = _indexOf(productId);
    if (index == -1) return;
    await setQuantity(productId, _items[index].quantity + 1);
  }

  Future<void> decreaseQuantity(int productId) async {
    final index = _indexOf(productId);
    if (index == -1) return;
    await setQuantity(productId, _items[index].quantity - 1);
  }

  /// Fixe directement la quantité d'une ligne (plafonnée au stock
  /// réel). `quantity <= 0` retire la ligne.
  Future<void> setQuantity(int productId, int quantity) async {
    final userId = _loadedUserId;
    if (userId != null) {
      await DatabaseHelper.instance.updateCartItemQuantity(userId, productId, quantity);
      await _reloadFromDb(userId);
      return;
    }

    final index = _indexOf(productId);
    if (index == -1) return;

    if (quantity <= 0) {
      final updated = List<CartItem>.from(_items)..removeAt(index);
      _items = updated;
      notifyListeners();
      return;
    }

    final item = _items[index];
    final clamped = quantity > item.stock ? item.stock : quantity;
    final updated = List<CartItem>.from(_items);
    updated[index] = item.copyWith(quantity: clamped);
    _items = updated;
    notifyListeners();
  }

  /// Vide le panier affiché. Pour un utilisateur connecté, vide aussi
  /// `cart_items` en base. À NE PAS utiliser après un checkout
  /// réussi (voir [clearLocalAfterCheckout]) : `createOrder` a déjà
  /// vidé le panier en base dans la même transaction que la commande.
  Future<void> clear() async {
    final userId = _loadedUserId;
    if (userId != null) {
      await DatabaseHelper.instance.clearCart(userId);
    }
    if (_items.isEmpty) return;
    _items = const [];
    notifyListeners();
  }

  /// À appeler après un `DatabaseHelper.createOrder` réussi : ne fait
  /// QUE resynchroniser l'état mémoire (la ligne SQLite a déjà été
  /// vidée dans la transaction de `createOrder`), pour éviter un
  /// aller-retour SQLite redondant.
  void clearLocalAfterCheckout() {
    if (_items.isEmpty) return;
    _items = const [];
    notifyListeners();
  }
}