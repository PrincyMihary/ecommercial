// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';
//
// import '../models/order_status.dart';
// import 'seed_data.dart';
//
// class OrderException implements Exception {
//   final String message;
//   const OrderException(this.message);
//   @override
//   String toString() => message;
// }
//
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
//
// class ShopException implements Exception {
//   final String message;
//   const ShopException(this.message);
//   @override
//   String toString() => message;
// }
//
// class PermissionException implements Exception {
//   final String message;
//   const PermissionException(this.message);
//   @override
//   String toString() => message;
// }
//
// class BlockingOrdersException implements Exception {
//   final String message;
//   final List<Map<String, dynamic>> orders;
//   const BlockingOrdersException(this.message, this.orders);
//   @override
//   String toString() => message;
// }
//
// class DatabaseHelper {
//   DatabaseHelper._internal();
//
//   static final DatabaseHelper instance = DatabaseHelper._internal();
//
//   static Database? _database;
//
//   static const String _dbName = 'marketplace.db';
//
//   // v1 -> v2 : orders.payment_method, order_items.product_name.
//   // v2 -> v3 : table `users`.
//   // v3 -> v4 : shops.owner_id (nullable, UNIQUE, FK -> users.id).
//   // v4 -> v5 : orders.user_id ; order_items.product_id nullable
//   //            (ON DELETE SET NULL) + shop_id/shop_name figés.
//   // v5 -> v6 (Étape 5 "panier persisté par utilisateur") :
//   //   - table `carts` : 1 panier par utilisateur (`user_id` UNIQUE,
//   //     NOT NULL, FK -> users.id). Un panier n'existe QUE rattaché à
//   //     un vrai utilisateur — un visiteur n'a jamais de ligne ici
//   //     (son panier reste en mémoire côté `CartService`, jamais
//   //     écrit en base, voir ce fichier).
//   //   - table `cart_items` : lignes du panier, FK `cart_id` ->
//   //     carts(id) ON DELETE CASCADE (si le panier est supprimé, ses
//   //     lignes le sont aussi) et FK `product_id` -> products(id)
//   //     ON DELETE CASCADE — contrairement à `order_items`
//   //     (ON DELETE SET NULL, car une commande doit conserver un
//   //     historique figé même produit supprimé), un panier ne fige
//   //     RIEN : nom/prix/image/stock sont relus depuis `products` à
//   //     chaque lecture. Un produit supprimé n'a donc aucune raison de
//   //     laisser une ligne fantôme dans un panier ; CASCADE la retire
//   //     simplement. UNIQUE(cart_id, product_id) : un produit n'a
//   //     qu'une seule ligne par panier (les +1/-1 mettent à jour la
//   //     quantité existante plutôt que d'empiler des lignes).
//   static const int _dbVersion = 7;
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }
//
//   Future<Database> _initDatabase() async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, _dbName);
//
//     return openDatabase(
//       path,
//       version: _dbVersion,
//       onConfigure: _onConfigure,
//       onCreate: _onCreate,
//       onUpgrade: _onUpgrade,
//     );
//   }
//
//   Future<void> _onConfigure(Database db) async {
//     await db.execute('PRAGMA foreign_keys = ON');
//   }
//
//   Future<void> _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE users (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         full_name TEXT NOT NULL,
//         email TEXT NOT NULL UNIQUE,
//         phone TEXT,
//         password_hash TEXT NOT NULL,
//         password_salt TEXT NOT NULL,
//         created_at TEXT NOT NULL
//       );
//     ''');
//
//     await db.execute('''
//       CREATE TABLE shops (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT NOT NULL,
//         description TEXT,
//         address TEXT,
//         latitude REAL,
//         longitude REAL,
//         google_place_id TEXT,
//         category TEXT,
//         image TEXT,
//         owner_id INTEGER UNIQUE REFERENCES users(id)
//       );
//     ''');
//
//     await db.execute('''
//       CREATE TABLE products (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         shop_id INTEGER NOT NULL,
//         name TEXT NOT NULL,
//         description TEXT,
//         price REAL NOT NULL,
//         stock INTEGER NOT NULL DEFAULT 0,
//         category TEXT,
//         image TEXT,
//         model_3d TEXT,
//         FOREIGN KEY (shop_id) REFERENCES shops(id)
//       );
//     ''');
//
//     await db.execute('''
//       CREATE TABLE carts (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         user_id INTEGER NOT NULL UNIQUE,
//         created_at TEXT NOT NULL,
//         updated_at TEXT NOT NULL,
//         FOREIGN KEY (user_id) REFERENCES users(id)
//       );
//     ''');
//
//     await db.execute('''
//       CREATE TABLE cart_items (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         cart_id INTEGER NOT NULL,
//         product_id INTEGER NOT NULL,
//         quantity INTEGER NOT NULL,
//         FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
//         FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
//         UNIQUE (cart_id, product_id)
//       );
//     ''');
//     await db.execute(
//       'CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON cart_items (cart_id)',
//     );
//
//     await db.execute('''
//       CREATE TABLE orders (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         total REAL NOT NULL,
//         status TEXT NOT NULL,
//         created_at TEXT NOT NULL,
//         payment_method TEXT,
//         user_id INTEGER REFERENCES users(id)
//       );
//     ''');
//
//     await db.execute('''
//       CREATE TABLE order_items (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         order_id INTEGER NOT NULL,
//         product_id INTEGER,
//         product_name TEXT,
//         quantity INTEGER NOT NULL,
//         price REAL NOT NULL,
//         shop_id INTEGER,
//         shop_name TEXT,
//         FOREIGN KEY (order_id) REFERENCES orders(id),
//         FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
//         FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL
//       );
//     ''');
//
//     await SeedData.insertSeed(db);
//   }
//
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     if (oldVersion < 2) {
//       await db.execute('ALTER TABLE orders ADD COLUMN payment_method TEXT');
//       await db.execute('ALTER TABLE order_items ADD COLUMN product_name TEXT');
//     }
//     if (oldVersion < 3) {
//       await db.execute('''
//         CREATE TABLE IF NOT EXISTS users (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           full_name TEXT NOT NULL,
//           email TEXT NOT NULL UNIQUE,
//           phone TEXT,
//           password_hash TEXT NOT NULL,
//           password_salt TEXT NOT NULL,
//           created_at TEXT NOT NULL
//         );
//       ''');
//     }
//     if (oldVersion < 4) {
//       await db.execute(
//         'ALTER TABLE shops ADD COLUMN owner_id INTEGER REFERENCES users(id)',
//       );
//       await db.execute(
//         'CREATE UNIQUE INDEX IF NOT EXISTS ux_shops_owner_id ON shops (owner_id)',
//       );
//     }
//     if (oldVersion < 5) {
//       await db.execute(
//         'ALTER TABLE orders ADD COLUMN user_id INTEGER REFERENCES users(id)',
//       );
//
//       await db.execute('''
//         CREATE TABLE order_items_new (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           order_id INTEGER NOT NULL,
//           product_id INTEGER,
//           product_name TEXT,
//           quantity INTEGER NOT NULL,
//           price REAL NOT NULL,
//           shop_id INTEGER,
//           shop_name TEXT,
//           FOREIGN KEY (order_id) REFERENCES orders(id),
//           FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
//           FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE SET NULL
//         );
//       ''');
//
//       await db.execute('''
//         INSERT INTO order_items_new
//           (id, order_id, product_id, product_name, quantity, price, shop_id, shop_name)
//         SELECT
//           oi.id, oi.order_id, oi.product_id, oi.product_name, oi.quantity, oi.price,
//           p.shop_id, s.name
//         FROM order_items oi
//         LEFT JOIN products p ON p.id = oi.product_id
//         LEFT JOIN shops s ON s.id = p.shop_id;
//       ''');
//
//       await db.execute('DROP TABLE order_items');
//       await db.execute('ALTER TABLE order_items_new RENAME TO order_items');
//     }
//     if (oldVersion < 6) {
//       // Nouvelles tables uniquement : aucune donnée existante n'est
//       // touchée. Les anciens paniers (en mémoire, jamais persistés)
//       // n'ont par définition aucune trace à migrer — ils disparaissent
//       // simplement au prochain démarrage de l'app, comme avant cette
//       // étape (comportement inchangé pour les visiteurs).
//       await db.execute('''
//         CREATE TABLE carts (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           user_id INTEGER NOT NULL UNIQUE,
//           created_at TEXT NOT NULL,
//           updated_at TEXT NOT NULL,
//           FOREIGN KEY (user_id) REFERENCES users(id)
//         );
//       ''');
//
//       await db.execute('''
//         CREATE TABLE cart_items (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           cart_id INTEGER NOT NULL,
//           product_id INTEGER NOT NULL,
//           quantity INTEGER NOT NULL,
//           FOREIGN KEY (cart_id) REFERENCES carts(id) ON DELETE CASCADE,
//           FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
//           UNIQUE (cart_id, product_id)
//         );
//       ''');
//
//       await db.execute(
//         'CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON cart_items (cart_id)',
//       );
//     }
//     if (oldVersion < 7) {
//       // Colonnes nullable : les commerces existants (address non
//       // null, reste null) continuent de fonctionner normalement, cf.
//       // Shop.hasStructuredLocation.
//       await db.execute('ALTER TABLE shops ADD COLUMN latitude REAL');
//       await db.execute('ALTER TABLE shops ADD COLUMN longitude REAL');
//       await db.execute('ALTER TABLE shops ADD COLUMN google_place_id TEXT');
//     }
//   }
//
//   Future<void> ensureSeeded() async {
//     final db = await database;
//     final count = Sqflite.firstIntValue(
//       await db.rawQuery('SELECT COUNT(*) FROM shops'),
//     );
//     if (count == null || count == 0) {
//       await SeedData.insertSeed(db);
//     }
//   }
//
//   // ---------------------------------------------------------------------
//   // Lectures simples
//   // ---------------------------------------------------------------------
//
//   Future<List<Map<String, dynamic>>> getAllShops() async {
//     final db = await database;
//     return db.query('shops', orderBy: 'name ASC');
//   }
//
//   Future<List<Map<String, dynamic>>> getAllProducts() async {
//     final db = await database;
//     return db.query('products', orderBy: 'id DESC');
//   }
//
//   Future<List<Map<String, dynamic>>> getProductsByShop(int shopId) async {
//     final db = await database;
//     return db.query(
//       'products',
//       where: 'shop_id = ?',
//       whereArgs: [shopId],
//       orderBy: 'name ASC',
//     );
//   }
//
//   // ---------------------------------------------------------------------
//   // RECHERCHE / FILTRE
//   // ---------------------------------------------------------------------
//
//   Future<List<Map<String, dynamic>>> searchProducts({
//     String? query,
//     String? category,
//   }) async {
//     final db = await database;
//
//     final conditions = <String>[];
//     final args = <Object?>[];
//
//     final trimmedQuery = query?.trim() ?? '';
//     if (trimmedQuery.isNotEmpty) {
//       final likePattern = '%$trimmedQuery%';
//       conditions.add('''
//         (products.name LIKE ?
//           OR products.description LIKE ?
//           OR products.category LIKE ?
//           OR shops.name LIKE ?)
//       ''');
//       args.addAll([likePattern, likePattern, likePattern, likePattern]);
//     }
//
//     final trimmedCategory = category?.trim() ?? '';
//     if (trimmedCategory.isNotEmpty && trimmedCategory != 'Tout') {
//       conditions.add('products.category = ?');
//       args.add(trimmedCategory);
//     }
//
//     final whereClause =
//     conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
//
//     final sql = '''
//       SELECT products.*
//       FROM products
//       INNER JOIN shops ON products.shop_id = shops.id
//       $whereClause
//       ORDER BY products.name ASC
//     ''';
//
//     return db.rawQuery(sql, args);
//   }
//
//   // ---------------------------------------------------------------------
//   // CRUD PRODUITS
//   // ---------------------------------------------------------------------
//
//   Future<Map<String, dynamic>?> getProductById(int id) async {
//     final db = await database;
//     final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<int> insertProduct(Map<String, dynamic> product) async {
//     final db = await database;
//     return db.insert('products', product);
//   }
//
//   Future<int> updateProduct(int id, Map<String, dynamic> product) async {
//     final db = await database;
//     return db.update('products', product, where: 'id = ?', whereArgs: [id]);
//   }
//
//   Future<int> deleteProduct(int id) async {
//     final db = await database;
//     return db.delete('products', where: 'id = ?', whereArgs: [id]);
//   }
//
//   Future<List<Map<String, dynamic>>> getProductsByOwner(int ownerId) async {
//     final shop = await getShopByOwnerId(ownerId);
//     if (shop == null) return [];
//     final shopId = shop['id'] as int;
//     return getProductsByShop(shopId);
//   }
//
//   Future<int> createProductForOwner(
//       int ownerId,
//       Map<String, dynamic> product,
//       ) async {
//     final shop = await getShopByOwnerId(ownerId);
//     if (shop == null) {
//       throw const ShopException(
//         'Vous devez d\'abord créer votre commerce avant d\'ajouter un produit.',
//       );
//     }
//     final shopId = shop['id'] as int;
//     final data = Map<String, dynamic>.from(product)..['shop_id'] = shopId;
//     final db = await database;
//     return db.insert('products', data);
//   }
//
//   Future<void> assertProductOwnership(int ownerId, int productId) async {
//     final product = await getProductById(productId);
//     if (product == null) {
//       throw const PermissionException('Produit introuvable.');
//     }
//     final shopId = product['shop_id'] as int;
//     await assertShopOwnership(ownerId, shopId);
//   }
//
//   Future<void> deleteProductForOwner(int ownerId, int productId) async {
//     await assertProductOwnership(ownerId, productId);
//
//     final blocking = await getBlockingOrdersForProduct(productId);
//     if (blocking.isNotEmpty) {
//       throw BlockingOrdersException(
//         'Ce produit apparaît dans ${blocking.length} commande(s) non finalisée(s).',
//         blocking,
//       );
//     }
//
//     final db = await database;
//     await db.delete('products', where: 'id = ?', whereArgs: [productId]);
//     // Note : ON DELETE CASCADE retire aussi ce produit de tous les
//     // paniers (cart_items) qui le contenaient — comportement voulu,
//     // voir doc en tête de fichier.
//   }
//
//   Future<void> updateProductForOwner(
//       int ownerId,
//       int productId,
//       Map<String, dynamic> product,
//       ) async {
//     await assertProductOwnership(ownerId, productId);
//     final db = await database;
//     final data = Map<String, dynamic>.from(product)..remove('shop_id');
//     await db.update('products', data, where: 'id = ?', whereArgs: [productId]);
//   }
//
//   // ---------------------------------------------------------------------
//   // CRUD COMMERCES
//   // ---------------------------------------------------------------------
//
//   Future<Map<String, dynamic>?> getShopById(int id) async {
//     final db = await database;
//     final rows = await db.query('shops', where: 'id = ?', whereArgs: [id], limit: 1);
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<Map<String, dynamic>?> getShopByOwnerId(int ownerId) async {
//     final db = await database;
//     final rows = await db.query(
//       'shops',
//       where: 'owner_id = ?',
//       whereArgs: [ownerId],
//       limit: 1,
//     );
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<int> createShopForOwner(
//       int ownerId,
//       Map<String, dynamic> shop,
//       ) async {
//     final db = await database;
//     final data = Map<String, dynamic>.from(shop)..['owner_id'] = ownerId;
//     try {
//       return await db.insert('shops', data);
//     } on DatabaseException catch (e) {
//       if (e.isUniqueConstraintError()) {
//         throw const ShopException('Vous possédez déjà un commerce.');
//       }
//       rethrow;
//     }
//   }
//
//   Future<void> assertShopOwnership(int ownerId, int shopId) async {
//     final shop = await getShopById(shopId);
//     final actualOwner = shop?['owner_id'] as int?;
//     if (shop == null || actualOwner == null || actualOwner != ownerId) {
//       throw const PermissionException(
//         'Vous ne pouvez gérer que votre propre commerce.',
//       );
//     }
//   }
//
//   Future<int> insertShop(Map<String, dynamic> shop) async {
//     final db = await database;
//     return db.insert('shops', shop);
//   }
//
//   Future<int> updateShop(int id, Map<String, dynamic> shop) async {
//     final db = await database;
//     return db.update('shops', shop, where: 'id = ?', whereArgs: [id]);
//   }
//
//   Future<int> countProductsByShop(int shopId) async {
//     final db = await database;
//     final result = await db.rawQuery(
//       'SELECT COUNT(*) AS count FROM products WHERE shop_id = ?',
//       [shopId],
//     );
//     return Sqflite.firstIntValue(result) ?? 0;
//   }
//
//   Future<void> deleteShopCascade(int shopId) async {
//     final blocking = await getBlockingOrdersForShop(shopId);
//     if (blocking.isNotEmpty) {
//       throw BlockingOrdersException(
//         'Ce commerce est concerné par ${blocking.length} commande(s) non finalisée(s).',
//         blocking,
//       );
//     }
//
//     final db = await database;
//     await db.transaction((txn) async {
//       await txn.delete('products', where: 'shop_id = ?', whereArgs: [shopId]);
//       await txn.delete('shops', where: 'id = ?', whereArgs: [shopId]);
//     });
//   }
//
//   Future<int> deleteShop(int id) async {
//     final blocking = await getBlockingOrdersForShop(id);
//     if (blocking.isNotEmpty) {
//       throw BlockingOrdersException(
//         'Ce commerce est concerné par ${blocking.length} commande(s) non finalisée(s).',
//         blocking,
//       );
//     }
//     final db = await database;
//     return db.delete('shops', where: 'id = ?', whereArgs: [id]);
//   }
//
//   // ---------------------------------------------------------------------
//   // PANIER (Étape 5 — persisté, strictement scellé par user_id)
//   // ---------------------------------------------------------------------
//
//   /// Résout (ou crée) l'id du panier de [userId], en utilisant
//   /// l'exécuteur fourni ([exec] peut être `Database` ou `Transaction`
//   /// — les deux implémentent `DatabaseExecutor`), pour pouvoir être
//   /// appelée aussi bien hors transaction que depuis une transaction
//   /// existante sans dupliquer la logique.
//   Future<int> _getOrCreateCartId(DatabaseExecutor exec, int userId) async {
//     final rows = await exec.query(
//       'carts',
//       where: 'user_id = ?',
//       whereArgs: [userId],
//       limit: 1,
//     );
//     if (rows.isNotEmpty) return rows.first['id'] as int;
//
//     final now = DateTime.now().toIso8601String();
//     try {
//       return await exec.insert('carts', {
//         'user_id': userId,
//         'created_at': now,
//         'updated_at': now,
//       });
//     } on DatabaseException catch (e) {
//       // Filet de sécurité en cas d'appel concurrent improbable :
//       // la contrainte UNIQUE(user_id) a pu être violée entre le
//       // SELECT et l'INSERT ci-dessus — on relit alors la ligne créée
//       // entre-temps plutôt que d'échouer.
//       if (e.isUniqueConstraintError()) {
//         final retry = await exec.query(
//           'carts',
//           where: 'user_id = ?',
//           whereArgs: [userId],
//           limit: 1,
//         );
//         if (retry.isNotEmpty) return retry.first['id'] as int;
//       }
//       rethrow;
//     }
//   }
//
//   Future<void> _touchCart(DatabaseExecutor exec, int cartId) async {
//     await exec.update(
//       'carts',
//       {'updated_at': DateTime.now().toIso8601String()},
//       where: 'id = ?',
//       whereArgs: [cartId],
//     );
//   }
//
//   /// Retourne l'id du panier de [userId], en le créant si besoin.
//   Future<int> getOrCreateCart(int userId) async {
//     final db = await database;
//     return _getOrCreateCartId(db, userId);
//   }
//
//   /// Lignes du panier de [userId], résolues (nom/prix/image/stock
//   /// LUS DEPUIS `products`, jamais recopiés/figés) via JOIN. Filtre
//   /// TOUJOURS par `user_id` — jamais un `cart_id` fourni par
//   /// l'appelant. Clés de la map alignées sur `CartItem.fromMap`.
//   Future<List<Map<String, dynamic>>> getCartItems(int userId) async {
//     final db = await database;
//     return db.rawQuery('''
//       SELECT
//         products.id AS product_id,
//         products.name AS product_name,
//         products.price AS price,
//         products.image AS image,
//         products.stock AS stock,
//         cart_items.quantity AS quantity
//       FROM cart_items
//       INNER JOIN carts ON carts.id = cart_items.cart_id
//       INNER JOIN products ON products.id = cart_items.product_id
//       WHERE carts.user_id = ?
//       ORDER BY cart_items.id ASC
//     ''', [userId]);
//   }
//
//   Future<int> getCartItemCount(int userId) async {
//     final db = await database;
//     final result = await db.rawQuery('''
//       SELECT COALESCE(SUM(cart_items.quantity), 0) AS count
//       FROM cart_items
//       INNER JOIN carts ON carts.id = cart_items.cart_id
//       WHERE carts.user_id = ?
//     ''', [userId]);
//     return Sqflite.firstIntValue(result) ?? 0;
//   }
//
//   /// Ajoute [quantity] unité(s) du produit [productId] au panier de
//   /// [userId]. Le stock est TOUJOURS relu depuis `products` dans la
//   /// transaction (jamais une valeur mémorisée côté appelant) et sert
//   /// de plafond. Retourne la quantité réellement ajoutée (peut être
//   /// inférieure à [quantity], ou 0 si rupture/produit introuvable).
//   Future<int> addCartItem(int userId, int productId, int quantity) async {
//     if (quantity <= 0) return 0;
//     final db = await database;
//
//     return db.transaction<int>((txn) async {
//       final cartId = await _getOrCreateCartId(txn, userId);
//
//       final productRows = await txn.query(
//         'products',
//         where: 'id = ?',
//         whereArgs: [productId],
//         limit: 1,
//       );
//       if (productRows.isEmpty) return 0;
//       final stock = productRows.first['stock'] as int? ?? 0;
//       if (stock <= 0) return 0;
//
//       final existing = await txn.query(
//         'cart_items',
//         where: 'cart_id = ? AND product_id = ?',
//         whereArgs: [cartId, productId],
//         limit: 1,
//       );
//
//       int added;
//       if (existing.isEmpty) {
//         added = quantity > stock ? stock : quantity;
//         if (added <= 0) return 0;
//         await txn.insert('cart_items', {
//           'cart_id': cartId,
//           'product_id': productId,
//           'quantity': added,
//         });
//       } else {
//         final current = existing.first['quantity'] as int? ?? 0;
//         final maxAddable = stock - current;
//         if (maxAddable <= 0) return 0;
//         added = quantity > maxAddable ? maxAddable : quantity;
//         await txn.update(
//           'cart_items',
//           {'quantity': current + added},
//           where: 'id = ?',
//           whereArgs: [existing.first['id']],
//         );
//       }
//
//       await _touchCart(txn, cartId);
//       return added;
//     });
//   }
//
//   /// Fixe directement la quantité du produit [productId] dans le
//   /// panier de [userId], plafonnée au stock actuel de `products`.
//   /// `quantity <= 0` retire la ligne. Ne fait rien si le produit
//   /// n'était pas dans le panier ET `quantity <= 0`.
//   Future<void> updateCartItemQuantity(
//       int userId,
//       int productId,
//       int quantity,
//       ) async {
//     final db = await database;
//     await db.transaction((txn) async {
//       final cartId = await _getOrCreateCartId(txn, userId);
//
//       if (quantity <= 0) {
//         await txn.delete(
//           'cart_items',
//           where: 'cart_id = ? AND product_id = ?',
//           whereArgs: [cartId, productId],
//         );
//         await _touchCart(txn, cartId);
//         return;
//       }
//
//       final productRows = await txn.query(
//         'products',
//         where: 'id = ?',
//         whereArgs: [productId],
//         limit: 1,
//       );
//       if (productRows.isEmpty) {
//         await txn.delete(
//           'cart_items',
//           where: 'cart_id = ? AND product_id = ?',
//           whereArgs: [cartId, productId],
//         );
//         await _touchCart(txn, cartId);
//         return;
//       }
//
//       final stock = productRows.first['stock'] as int? ?? 0;
//       final clamped = quantity > stock ? stock : quantity;
//
//       if (clamped <= 0) {
//         await txn.delete(
//           'cart_items',
//           where: 'cart_id = ? AND product_id = ?',
//           whereArgs: [cartId, productId],
//         );
//       } else {
//         final updated = await txn.update(
//           'cart_items',
//           {'quantity': clamped},
//           where: 'cart_id = ? AND product_id = ?',
//           whereArgs: [cartId, productId],
//         );
//         if (updated == 0) {
//           await txn.insert('cart_items', {
//             'cart_id': cartId,
//             'product_id': productId,
//             'quantity': clamped,
//           });
//         }
//       }
//
//       await _touchCart(txn, cartId);
//     });
//   }
//
//   Future<void> removeCartItem(int userId, int productId) async {
//     final db = await database;
//     await db.transaction((txn) async {
//       final cartId = await _getOrCreateCartId(txn, userId);
//       await txn.delete(
//         'cart_items',
//         where: 'cart_id = ? AND product_id = ?',
//         whereArgs: [cartId, productId],
//       );
//       await _touchCart(txn, cartId);
//     });
//   }
//
//   Future<void> clearCart(int userId) async {
//     final db = await database;
//     await db.transaction((txn) async {
//       final cartId = await _getOrCreateCartId(txn, userId);
//       await txn.delete('cart_items', where: 'cart_id = ?', whereArgs: [cartId]);
//       await _touchCart(txn, cartId);
//     });
//   }
//
//   // ---------------------------------------------------------------------
//   // COMMANDES
//   // ---------------------------------------------------------------------
//
//   /// Crée une commande à partir du panier PERSISTÉ de [userId] —
//   /// jamais d'une liste fournie par l'appelant. Séquence, dans une
//   /// transaction unique :
//   /// 1. résout le panier de [userId] (aucune commande créée si vide
//   ///    ou inexistant) ;
//   /// 2. pour chaque ligne, relit le produit en base (stock/prix
//   ///    actuels, jamais une valeur mise en cache) ;
//   /// 3. calcule le total, crée `orders` (status pending, user_id) ;
//   /// 4. crée chaque `order_items` (nom/prix/commerce figés à cet
//   ///    instant) et décrémente le stock ;
//   /// 5. VIDE `cart_items` de ce panier, dans la même transaction :
//   ///    si une étape échoue avant, le rollback restaure le panier
//   ///    intact — le client ne perd jamais son panier sur une commande
//   ///    ratée.
//   ///
//   /// Retourne l'identifiant de la commande créée.
//   Future<int> createOrder({
//     required int userId,
//     required String paymentMethod,
//   }) async {
//     final db = await database;
//
//     return db.transaction<int>((txn) async {
//       final cartRows = await txn.query(
//         'carts',
//         where: 'user_id = ?',
//         whereArgs: [userId],
//         limit: 1,
//       );
//       if (cartRows.isEmpty) {
//         throw const OrderException('Le panier est vide.');
//       }
//       final cartId = cartRows.first['id'] as int;
//
//       final itemRows = await txn.rawQuery('''
//         SELECT
//           products.id AS product_id,
//           products.name AS product_name,
//           products.price AS price,
//           products.stock AS stock,
//           products.shop_id AS shop_id,
//           cart_items.quantity AS quantity
//         FROM cart_items
//         INNER JOIN products ON products.id = cart_items.product_id
//         WHERE cart_items.cart_id = ?
//       ''', [cartId]);
//
//       if (itemRows.isEmpty) {
//         throw const OrderException('Le panier est vide.');
//       }
//
//       double total = 0;
//       final resolvedItems = <Map<String, dynamic>>[];
//
//       for (final row in itemRows) {
//         final productId = row['product_id'] as int;
//         final productName = row['product_name'] as String? ?? '';
//         final currentPrice = (row['price'] as num?)?.toDouble() ?? 0.0;
//         final currentStock = row['stock'] as int? ?? 0;
//         final shopId = row['shop_id'] as int?;
//         final quantity = row['quantity'] as int? ?? 0;
//
//         if (currentStock < quantity) {
//           throw OrderException(
//             'Stock insuffisant pour "$productName" '
//                 '(disponible : $currentStock, demandé : $quantity).',
//           );
//         }
//
//         String? shopName;
//         if (shopId != null) {
//           final shopRows = await txn.query(
//             'shops',
//             columns: ['name'],
//             where: 'id = ?',
//             whereArgs: [shopId],
//             limit: 1,
//           );
//           if (shopRows.isNotEmpty) {
//             shopName = shopRows.first['name'] as String?;
//           }
//         }
//
//         total += currentPrice * quantity;
//         resolvedItems.add({
//           'product_id': productId,
//           'product_name': productName,
//           'quantity': quantity,
//           'price': currentPrice,
//           'new_stock': currentStock - quantity,
//           'shop_id': shopId,
//           'shop_name': shopName,
//         });
//       }
//
//       final orderId = await txn.insert('orders', {
//         'total': total,
//         'status': OrderStatus.pending,
//         'created_at': DateTime.now().toIso8601String(),
//         'payment_method': paymentMethod,
//         'user_id': userId,
//       });
//
//       for (final resolved in resolvedItems) {
//         await txn.insert('order_items', {
//           'order_id': orderId,
//           'product_id': resolved['product_id'],
//           'product_name': resolved['product_name'],
//           'quantity': resolved['quantity'],
//           'price': resolved['price'],
//           'shop_id': resolved['shop_id'],
//           'shop_name': resolved['shop_name'],
//         });
//
//         await txn.update(
//           'products',
//           {'stock': resolved['new_stock']},
//           where: 'id = ?',
//           whereArgs: [resolved['product_id']],
//         );
//       }
//
//       // Panier vidé DANS la transaction : atomique avec la création
//       // de la commande (voir doc ci-dessus).
//       await txn.delete('cart_items', where: 'cart_id = ?', whereArgs: [cartId]);
//
//       return orderId;
//     });
//   }
//
//   Future<void> markOrderAsPaid(int orderId) async {
//     final db = await database;
//     final updated = await db.update(
//       'orders',
//       {'status': OrderStatus.paid},
//       where: 'id = ?',
//       whereArgs: [orderId],
//     );
//     if (updated == 0) {
//       throw OrderException(
//         'Impossible de mettre à jour le statut : commande #$orderId introuvable.',
//       );
//     }
//   }
//
//   Future<List<Map<String, dynamic>>> getOrdersWithItemCount() async {
//     final db = await database;
//     return db.rawQuery('''
//       SELECT
//         orders.*,
//         COALESCE(SUM(order_items.quantity), 0) AS item_count
//       FROM orders
//       LEFT JOIN order_items ON order_items.order_id = orders.id
//       GROUP BY orders.id
//       ORDER BY orders.created_at DESC
//     ''');
//   }
//
//   Future<List<Map<String, dynamic>>> getOrdersByUser(int userId) async {
//     final db = await database;
//     return db.rawQuery('''
//       SELECT
//         orders.*,
//         COALESCE(SUM(order_items.quantity), 0) AS item_count
//       FROM orders
//       LEFT JOIN order_items ON order_items.order_id = orders.id
//       WHERE orders.user_id = ?
//       GROUP BY orders.id
//       ORDER BY orders.created_at DESC
//     ''', [userId]);
//   }
//
//   Future<List<Map<String, dynamic>>> getOrdersForShopOwner(int ownerId) async {
//     final shop = await getShopByOwnerId(ownerId);
//     if (shop == null) return [];
//     final shopId = shop['id'] as int;
//
//     final db = await database;
//     return db.rawQuery('''
//       SELECT
//         orders.*,
//         COALESCE(SUM(
//           CASE WHEN order_items.shop_id = ? THEN order_items.quantity ELSE 0 END
//         ), 0) AS shop_item_count,
//         COALESCE(SUM(
//           CASE WHEN order_items.shop_id = ? THEN order_items.quantity * order_items.price ELSE 0 END
//         ), 0.0) AS shop_total
//       FROM orders
//       INNER JOIN order_items ON order_items.order_id = orders.id
//       WHERE orders.id IN (
//         SELECT DISTINCT order_id FROM order_items WHERE shop_id = ?
//       )
//       GROUP BY orders.id
//       ORDER BY orders.created_at DESC
//     ''', [shopId, shopId, shopId]);
//   }
//
//   Future<Map<String, dynamic>?> getOrderById(int id) async {
//     final db = await database;
//     final rows = await db.query('orders', where: 'id = ?', whereArgs: [id], limit: 1);
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
//     final db = await database;
//     return db.query(
//       'order_items',
//       where: 'order_id = ?',
//       whereArgs: [orderId],
//       orderBy: 'id ASC',
//     );
//   }
//
//   Future<List<Map<String, dynamic>>> getOrderItemsForShop(
//       int orderId,
//       int shopId,
//       ) async {
//     final db = await database;
//     return db.query(
//       'order_items',
//       where: 'order_id = ? AND shop_id = ?',
//       whereArgs: [orderId, shopId],
//       orderBy: 'id ASC',
//     );
//   }
//
//   Future<List<Map<String, dynamic>>> getBlockingOrdersForProduct(
//       int productId,
//       ) async {
//     final db = await database;
//     final placeholders =
//     List.filled(OrderStatus.terminalStatuses.length, '?').join(',');
//     return db.rawQuery('''
//       SELECT DISTINCT orders.*
//       FROM orders
//       INNER JOIN order_items ON order_items.order_id = orders.id
//       WHERE order_items.product_id = ?
//         AND orders.status NOT IN ($placeholders)
//       ORDER BY orders.created_at DESC
//     ''', [productId, ...OrderStatus.terminalStatuses]);
//   }
//
//   Future<List<Map<String, dynamic>>> getBlockingOrdersForShop(
//       int shopId,
//       ) async {
//     final db = await database;
//     final placeholders =
//     List.filled(OrderStatus.terminalStatuses.length, '?').join(',');
//     return db.rawQuery('''
//       SELECT DISTINCT orders.*
//       FROM orders
//       INNER JOIN order_items ON order_items.order_id = orders.id
//       WHERE order_items.shop_id = ?
//         AND orders.status NOT IN ($placeholders)
//       ORDER BY orders.created_at DESC
//     ''', [shopId, ...OrderStatus.terminalStatuses]);
//   }
//
//   Future<void> advanceOrderStatusForShop(
//       int ownerId,
//       int orderId,
//       String newStatus,
//       ) async {
//     final shop = await getShopByOwnerId(ownerId);
//     if (shop == null) {
//       throw const PermissionException('Vous ne possédez pas de commerce.');
//     }
//     final shopId = shop['id'] as int;
//
//     final relevant = await getOrderItemsForShop(orderId, shopId);
//     if (relevant.isEmpty) {
//       throw const PermissionException(
//         'Cette commande ne concerne pas votre commerce.',
//       );
//     }
//
//     final orderRow = await getOrderById(orderId);
//     if (orderRow == null) {
//       throw const OrderException('Commande introuvable.');
//     }
//     final currentStatus = orderRow['status'] as String? ?? '';
//
//     if (!OrderStatus.canTransition(currentStatus, newStatus)) {
//       throw OrderException(
//         'Transition invalide : '
//             '"${OrderStatus.label(currentStatus)}" -> "${OrderStatus.label(newStatus)}".',
//       );
//     }
//
//     final db = await database;
//     await db.update(
//       'orders',
//       {'status': newStatus},
//       where: 'id = ?',
//       whereArgs: [orderId],
//     );
//   }
//
//   Future<void> refundOrderForShop(int ownerId, int orderId) async {
//     final shop = await getShopByOwnerId(ownerId);
//     if (shop == null) {
//       throw const PermissionException('Vous ne possédez pas de commerce.');
//     }
//     final shopId = shop['id'] as int;
//
//     final relevant = await getOrderItemsForShop(orderId, shopId);
//     if (relevant.isEmpty) {
//       throw const PermissionException(
//         'Cette commande ne concerne pas votre commerce.',
//       );
//     }
//
//     final orderRow = await getOrderById(orderId);
//     if (orderRow == null) {
//       throw const OrderException('Commande introuvable.');
//     }
//     final currentStatus = orderRow['status'] as String? ?? '';
//
//     if (!OrderStatus.canTransition(currentStatus, OrderStatus.refunded)) {
//       throw OrderException(
//         'Impossible de rembourser une commande "${OrderStatus.label(currentStatus)}".',
//       );
//     }
//
//     final db = await database;
//     await db.transaction((txn) async {
//       await txn.update(
//         'orders',
//         {'status': OrderStatus.refunded},
//         where: 'id = ?',
//         whereArgs: [orderId],
//       );
//
//       for (final item in relevant) {
//         final productId = item['product_id'] as int?;
//         if (productId == null) continue;
//         final quantity = item['quantity'] as int? ?? 0;
//         await txn.rawUpdate(
//           'UPDATE products SET stock = stock + ? WHERE id = ?',
//           [quantity, productId],
//         );
//       }
//     });
//   }
//
//   // ---------------------------------------------------------------------
//   // UTILISATEURS
//   // ---------------------------------------------------------------------
//
//   Future<int> createUser(Map<String, dynamic> userData) async {
//     final db = await database;
//     try {
//       return await db.insert('users', userData);
//     } on DatabaseException catch (e) {
//       if (e.isUniqueConstraintError()) {
//         throw const AuthException('Cet email est déjà utilisé.');
//       }
//       rethrow;
//     }
//   }
//
//   Future<Map<String, dynamic>?> getUserByEmail(String email) async {
//     final db = await database;
//     final rows = await db.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<Map<String, dynamic>?> getUserById(int id) async {
//     final db = await database;
//     final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
//     if (rows.isEmpty) return null;
//     return rows.first;
//   }
//
//   Future<void> close() async {
//     final db = _database;
//     if (db != null) {
//       await db.close();
//       _database = null;
//     }
//   }
// }