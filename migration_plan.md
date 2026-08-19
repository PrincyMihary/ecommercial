# Plan de migration — "ecommercial" (Flutter/SQLite → Flutter + Node/Express/TypeScript + PostgreSQL)

> **Statut de ce document (v2)** : rédigé après réception de `database_helper.dart`, `seed_data.dart`, tous les modèles (`user`, `product`, `shop`, `order`, `order_item`, `order_status`, `cart_item`), tous les services (`auth_service`, `cart_service`, `image_storage_service`, `model_3d_storage_service`, `location_service`, `places_service`) et tous les écrans manquants (`login`, `signup`, `product_form`, `shop_form`, `product_detail`, `shop_detail`, `home`, `search`, `cart`, `checkout`, `profile`). Le schéma SQLite réel est maintenant connu avec certitude (lu directement dans `_onCreate`/`_onUpgrade`), donc l'essentiel des "À confirmer" de la v1 est levé. Les points encore ouverts sont listés en Section 23.
>
> Fichiers encore non fournis et hors du périmètre couvert avec certitude par ce document : `ar_view_screen.dart`, `ar_plugin_compile_check.dart`, `placeholder_screen.dart`, `place_search_screen.dart`. Ils n'affectent pas le schéma de données ni l'API REST (l'AR est un rendu 100% client à partir du `model_3d` déjà migré en §14 ; `place_search_screen.dart` est un simple écran de recherche consommant `PlacesService`, déjà analysé via son propre fichier).

---

# 1. État actuel

Application Flutter (`marketplace_app`) en couches simples, sans réseau :

```
Écrans (StatefulWidget)
   ↓
DatabaseHelper.instance (lib/database/database_helper.dart), singleton
   ↓
SQLite (sqflite), fichier `marketplace.db`, version de schéma 7
```

Trois services singleton `ChangeNotifier`/`Listenable`, tous en mémoire (aucune persistance de session) :
- `AuthService.instance` : email + mot de passe (SHA-256 salé, sel aléatoire 16 octets), `currentUser`/`isLoggedIn`, **aucune persistance entre redémarrages de l'app** (confirmé explicitement en commentaire de fin de fichier : *"La session vit uniquement en mémoire ... Fermer et rouvrir l'application ramène donc l'utilisateur en état visiteur"*).
- `CartService.instance` : double régime — panier **persisté SQLite** (`carts`/`cart_items`) pour un utilisateur connecté, panier **éphémère en mémoire** pour un visiteur (jamais écrit en base). Bascule automatique à la connexion/déconnexion, avec transfert des articles du panier visiteur vers le panier persisté lors d'une connexion.
- Pas de service équivalent pour les commerces/produits : accès direct via `DatabaseHelper`.

Le paiement (`MockPaymentService`) reste 100% mocké, sans réseau ni donnée bancaire persistée — inchangé par rapport à la v1 de ce plan.

Le stockage de fichiers (`ImageStorageService`, `Model3dStorageService`) copie les fichiers choisis dans `<Documents>/uploads/{shops,products,models}/` avec un nom généré (jamais le nom original), et supprime en best-effort. Formats et tailles limités : images `jpg/jpeg/png/webp` ≤ 8 Mo, modèles `.glb` ≤ 50 Mo.

La géolocalisation (`LocationService`, `PlacesService`) est **confirmée** : `shops` porte `latitude`, `longitude`, `google_place_id`, en plus de `address` (texte libre). `PlacesService` interroge l'API Google Places (New) en HTTP direct (pas de SDK), avec un **mode mock intégré** (actif tant qu'aucune clé `GOOGLE_PLACES_API_KEY` n'est fournie via `--dart-define`) qui simule l'autocomplétion sur un jeu de lieux fixes cohérents avec les villes du seed. `LocationService` construit une URL Google Maps (priorité au `place_id`, sinon lat/lng) et l'ouvre via `url_launcher`.

# 2. Architecture actuelle

```
Flutter UI
   │
   ├── AuthService (mémoire, SHA-256 salé, pas de session persistée)
   ├── CartService (panier persisté si connecté / mémoire si visiteur)
   ├── ImageStorageService / Model3dStorageService (fichiers locaux, uploads/)
   ├── LocationService / PlacesService (Google Maps / Places, mode mock par défaut)
   │
   ▼
DatabaseHelper.instance
   ▼
SQLite (marketplace.db, PRAGMA foreign_keys = ON, version 7)
```

Toutes les opérations sensibles (création de commande, remboursement, suppression de commerce/produit) sont déjà **transactionnelles** côté SQLite (`db.transaction`) et déjà **protégées par des contrôles de propriété explicites** (`assertShopOwnership`, `assertProductOwnership`, exceptions dédiées `PermissionException`, `ShopException`, `OrderException`, `BlockingOrdersException`). C'est un point important : la migration backend n'invente pas ces règles, elle **transpose une logique métier déjà entièrement écrite et testée côté Flutter**.

# 3. Architecture cible

```
Flutter UI
   ↓
Services / Repository (AuthService, CartService, ShopApiService, ProductApiService,
                        OrderApiService... — même noms de classes que l'existant
                        quand possible, implémentation interne remplacée)
   ↓
HTTP (package http, déjà présent)
   ↓
Express (Node.js + TypeScript)
   ↓
PostgreSQL (une instance locale par développeur)
```

Le `DatabaseHelper` reste en place jusqu'à la fin de la Phase G (§11). `AuthService` et `CartService` **gardent leurs noms de classe et leur interface publique** (`currentUser`, `isLoggedIn`, `items`, `totalAmount`, `addProduct`, etc.) — seule leur implémentation interne change, ce qui est le point clé pour ne pas casser `cart_screen.dart`, `checkout_screen.dart`, `product_detail_screen.dart`, `profile_screen.dart`, `sell_screen.dart`, etc. qui s'abonnent à ces singletons.

# 4. Modèle de données actuel (certain, lu directement dans `database_helper.dart`)

## `users`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
full_name TEXT NOT NULL
email TEXT NOT NULL UNIQUE
phone TEXT
password_hash TEXT NOT NULL
password_salt TEXT NOT NULL
created_at TEXT NOT NULL
```
Hash = `sha256('$salt:$password')`, salt = 16 octets aléatoires (`Random.secure`) encodés en base64url. Le modèle Dart `User` **ignore volontairement** `password_hash`/`password_salt` (jamais exposés à l'UI).

## `shops`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
name TEXT NOT NULL
description TEXT
address TEXT
latitude REAL
longitude REAL
google_place_id TEXT
category TEXT
image TEXT
owner_id INTEGER UNIQUE REFERENCES users(id)
```
`owner_id` est `UNIQUE` (index unique ajouté en v4, migration `ux_shops_owner_id`) → **1 utilisateur = 0 ou 1 commerce, contrainte SQL réelle, pas seulement applicative**. `owner_id` est nullable : les commerces du seed n'ont pas de propriétaire (`owner_id IS NULL`), et ne sont administrables par personne (`ShopFormScreen`/`ShopDetailScreen` le vérifient explicitement).

## `products`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
shop_id INTEGER NOT NULL REFERENCES shops(id)
name TEXT NOT NULL
description TEXT
price REAL NOT NULL
stock INTEGER NOT NULL DEFAULT 0
category TEXT
image TEXT
model_3d TEXT
```
Pas de `ON DELETE CASCADE` déclaré sur `products.shop_id → shops.id` : la suppression d'un commerce avec produits passe par `deleteShopCascade` (transaction applicative qui supprime d'abord les produits, puis le commerce), jamais par une cascade SQL.

## `carts` (persisté uniquement pour utilisateurs connectés)
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
user_id INTEGER NOT NULL UNIQUE REFERENCES users(id)
created_at TEXT NOT NULL
updated_at TEXT NOT NULL
```

## `cart_items`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
cart_id INTEGER NOT NULL REFERENCES carts(id) ON DELETE CASCADE
product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE
quantity INTEGER NOT NULL
UNIQUE (cart_id, product_id)
INDEX idx_cart_items_cart_id (cart_id)
```
`ON DELETE CASCADE` (contrairement à `order_items`) : un panier ne fige rien, un produit supprimé disparaît simplement des paniers qui le contenaient.

## `orders`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
total REAL NOT NULL
status TEXT NOT NULL
created_at TEXT NOT NULL
payment_method TEXT
user_id INTEGER REFERENCES users(id)
```
`user_id` nullable (commandes créées avant la migration v4→v5 dans l'historique de l'app, non pertinent pour une V1 backend qui démarre propre — mais la colonne doit rester nullable pour cohérence de modèle).

## `order_items`
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
order_id INTEGER NOT NULL REFERENCES orders(id)
product_id INTEGER REFERENCES products(id) ON DELETE SET NULL
product_name TEXT
quantity INTEGER NOT NULL
price REAL NOT NULL
shop_id INTEGER REFERENCES shops(id) ON DELETE SET NULL
shop_name TEXT
```
`product_name`, `shop_name`, `price` sont des **snapshots figés à l'achat**, jamais recalculés. `product_id`/`shop_id` passent à `NULL` si le produit/commerce est supprimé ensuite (`ON DELETE SET NULL`), mais le nom reste lisible dans l'historique.

## Statuts de commande (`order_status.dart`, confirmé)
```
pending → paid → preparing → ready → completed        (progression normale)
cancelled, refunded                                    (états terminaux hors progression)
terminalStatuses = [completed, cancelled, refunded]
merchantTransitions = { paid: [preparing, refunded], preparing: [ready, refunded], ready: [completed, refunded] }
```
`pending → paid` est **automatique** (déclenché par `markOrderAsPaid` juste après un paiement mocké réussi), **jamais** une transition manuelle commerçant. `cancelled` n'apparaît dans **aucune** transition définie dans `merchantTransitions` — aucun code fourni ne déclenche ce statut ; il existe dans le modèle mais son déclencheur réel n'est pas visible dans les fichiers fournis (**à confirmer** — potentiellement une fonctionnalité prévue mais pas encore câblée, ou gérée ailleurs).

# 5. Modèle PostgreSQL proposé

```sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id             BIGSERIAL PRIMARY KEY,
  full_name      TEXT NOT NULL,
  email          CITEXT NOT NULL UNIQUE,
  phone          TEXT,
  password_hash  TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Note : pas de colonne password_salt séparée en PostgreSQL — bcrypt/argon2
-- embarquent le sel dans le hash lui-même (voir §10). C'est un changement
-- de mécanisme assumé, pas une simple recopie du schéma SQLite.

CREATE TABLE shops (
  id               BIGSERIAL PRIMARY KEY,
  owner_id         BIGINT UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  description      TEXT,
  address          TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  google_place_id  TEXT,
  category         TEXT NOT NULL,
  image            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- owner_id nullable + UNIQUE : reproduit exactement la règle SQLite
-- (1 utilisateur = 0 ou 1 commerce ; commerces "seedés" sans propriétaire
-- autorisés). ON DELETE SET NULL (pas RESTRICT) : si le compte d'un
-- commerçant est supprimé, son commerce redevient "orphelin" plutôt que
-- de bloquer la suppression du compte — comportement à valider avec
-- l'équipe (§23), SQLite ne tranche pas ce cas puisqu'il n'existe aucune
-- fonctionnalité "supprimer mon compte" dans le code fourni.

CREATE TABLE products (
  id           BIGSERIAL PRIMARY KEY,
  shop_id      BIGINT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  name         TEXT NOT NULL,
  description  TEXT,
  price        NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  stock        INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  category     TEXT,
  image        TEXT,
  model_3d     TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX products_shop_id_idx ON products (shop_id);
CREATE INDEX products_category_idx ON products (category);
-- ON DELETE RESTRICT (au lieu d'une simple absence de contrainte comme en
-- SQLite) : empêche une suppression physique de shop tant que des
-- produits existent, cohérent avec deleteShopCascade() qui supprime déjà
-- explicitement les produits avant le commerce — la contrainte devient un
-- filet de sécurité, pas un obstacle au comportement existant.

CREATE TABLE carts (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cart_items (
  id          BIGSERIAL PRIMARY KEY,
  cart_id     BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity    INTEGER NOT NULL CHECK (quantity > 0),
  UNIQUE (cart_id, product_id)
);
CREATE INDEX cart_items_cart_id_idx ON cart_items (cart_id);

CREATE TABLE orders (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,
  total           NUMERIC(12,2) NOT NULL CHECK (total >= 0),
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','paid','preparing','ready','completed','cancelled','refunded')),
  payment_method  TEXT CHECK (payment_method IN ('orange_money','yas','visa')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX orders_status_idx ON orders (status);

CREATE TABLE order_items (
  id            BIGSERIAL PRIMARY KEY,
  order_id      BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id    BIGINT REFERENCES products(id) ON DELETE SET NULL,
  product_name  TEXT,
  quantity      INTEGER NOT NULL CHECK (quantity > 0),
  price         NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  shop_id       BIGINT REFERENCES shops(id) ON DELETE SET NULL,
  shop_name     TEXT
);
CREATE INDEX order_items_order_id_idx ON order_items (order_id);
CREATE INDEX order_items_shop_id_idx ON order_items (shop_id);
CREATE INDEX order_items_product_id_idx ON order_items (product_id);
-- ON DELETE CASCADE sur order_items.order_id (SQLite ne le déclare pas
-- explicitement mais aucune méthode ne supprime une commande — table
-- purement additive dans le code fourni). ON DELETE SET NULL conservé à
-- l'identique pour product_id/shop_id (reproduit exactement le
-- comportement SQLite confirmé en v4→v5).

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_shops_updated_at BEFORE UPDATE ON shops
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_carts_updated_at BEFORE UPDATE ON carts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

**Aucune table `payments`** : confirmé, `orders.payment_method` reste le seul champ lié au paiement, aucune donnée bancaire n'existe nulle part dans le code Flutter fourni.

**Panier persisté (`carts`/`cart_items`)** : contrairement à l'hypothèse de la v1 de ce plan, la table existe bel et bien côté Flutter/SQLite (Étape 5 du projet). Elle est donc reprise telle quelle côté PostgreSQL. Le panier "visiteur" (non connecté), lui, reste **purement côté client**, jamais migré vers le backend — aucune table PostgreSQL ne le concerne.

# 6. Script schema.sql à prévoir

Fichier : `backend/database/schema.sql`, contenant exactement le bloc SQL de la Section 5, dans l'ordre `users` → `shops` → `products` → `carts` → `cart_items` → `orders` → `order_items` (ordre imposé par les FK), précédé de `DROP TABLE IF EXISTS order_items, orders, cart_items, carts, products, shops, users CASCADE;` en tête (contexte dev local, cf. §17), et de la fonction/triggers `set_updated_at`.

Ce script correspond désormais à une **traduction directe et non spéculative** du schéma SQLite réel (v7), avec les adaptations PostgreSQL justifiées ci-dessus (types, `CHECK`, `ON DELETE`, `updated_at` géré par trigger plutôt que manuellement).

# 7. Seed PostgreSQL à prévoir

`seed_data.dart` fournit **5 commerces et 20 produits réels**, insérés via `SeedData.insertSeed(db)` dans une transaction unique, ré-exécutée automatiquement si `shops` est vide (`ensureSeeded()`, appelée à part de `_onCreate`).

Contenu exact à traduire en `backend/database/seed.sql` :
- 5 `INSERT INTO shops` : Maison & Bois (Antananarivo), Déco Mada (Antananarivo), Tech Corner (Toamasina), Mode Urbaine (Antsirabe), Atelier Fianar (Fianarantsoa) — tous avec `owner_id = NULL` (aucun propriétaire, cohérent avec le seed SQLite), `latitude`/`longitude`/`google_place_id = NULL` (le seed ne renseigne pas de localisation structurée, seulement `address` en texte libre)
- 20 `INSERT INTO products`, répartis 4 par commerce, avec `price`, `stock`, `category`, `image` (chemins `assets/images/...`), `model_3d` (chemins `assets/models/...` pour 2 produits seulement : chaise et table de "Maison & Bois", lampe de "Déco Mada" — les 17 autres ont `model_3d = NULL`)
- Les valeurs `category` du seed (`'Mobilier'`, `'Décoration'`, `'Électronique'`, `'Mode'`, `'Artisanat'`) sont des libellés **courts**, différents de la liste détaillée `kProductCategories` (13 valeurs type "Mobilier — Assise & Repos") utilisée par `product_form_screen.dart`/`search_screen.dart`. **Incohérence réelle du projet, à signaler à l'équipe** (voir §23) — le seed n'a pas été mis à jour en même temps que la liste de catégories.
- Les chemins d'images/modèles du seed sont des **assets Flutter embarqués** (`assets/images/...`, `assets/models/...`), pas des fichiers utilisateur : ils ne passent donc **pas** par la migration de stockage de la Section 14 (pas d'upload nécessaire) — le backend peut les référencer tels quels comme des chemins constants, ou (mieux) les servir aussi depuis `backend/uploads/seed/` si l'on veut que `AppImage` traite uniformément tout ce qui n'est pas un vrai asset Flutter. Choix à trancher en Section 19 selon la stratégie retenue en §14.
- Les mots de passe : le seed ne crée **aucun utilisateur** (`users` reste vide après seed) — aucun mot de passe à migrer/re-hasher pour les données de démo.

# 8. Architecture Node.js / Express / TypeScript

Inchangée par rapport à la v1 de ce plan (structure par domaine, `pg` + SQL paramétré sans ORM, justification identique — le code SQLite fourni renforce d'ailleurs ce choix : `DatabaseHelper` est déjà écrit en SQL explicite avec transactions manuelles, la transposition vers `pg` est directe méthode par méthode) :

```
backend/
├── src/
│   ├── config/env.ts
│   ├── db/pool.ts
│   ├── middleware/{requireAuth,errorHandler,validate}.ts
│   ├── modules/
│   │   ├── auth/       (register/login/me)
│   │   ├── shops/      (CRUD + ownership)
│   │   ├── products/   (CRUD + ownership via shop)
│   │   ├── cart/       (NOUVEAU — voir §12, absent du plan v1)
│   │   └── orders/     (checkout, historique, statuts, remboursement, blocages)
│   ├── types/express.d.ts
│   ├── app.ts
│   └── server.ts
├── database/{schema.sql,seed.sql}
├── uploads/{shops,products,models}/   (voir §14)
├── .env.example / .gitignore
├── package.json / tsconfig.json
└── README.md
```

Ajout par rapport à la v1 : un module **`cart`** dédié (absent du premier plan car `cart_item.dart`/`cart_service.dart` n'étaient pas encore fournis). C'est un module à part entière, pas une sous-partie d'`orders`, car il a son propre cycle de vie (persisté par utilisateur, indépendant des commandes).

# 9. API REST proposée

```
AUTH
POST   /auth/register        # AuthService.signUp
POST   /auth/login           # AuthService.login
GET    /users/me

SHOPS
GET    /shops                        # getAllShops
GET    /shops/:id                    # getShopById
GET    /shops/me                     # getShopByOwnerId(currentUser)
POST   /shops                        # createShopForOwner — 409 si déjà propriétaire (contrainte UNIQUE)
PUT    /shops/:id                    # updateShop — vérifie assertShopOwnership
DELETE /shops/:id                    # deleteShopCascade — 409 BlockingOrdersException si commandes non terminales

PRODUCTS
GET    /products                     # getAllProducts (home, hors filtre)
GET    /products/search?q=&category= # searchProducts
GET    /products/:id                 # getProductById
GET    /products/mine                # getProductsByOwner(currentUser)
POST   /products                     # createProductForOwner — 409 si pas de commerce
PUT    /products/:id                 # updateProductForOwner
DELETE /products/:id                 # deleteProductForOwner — 409 BlockingOrdersException

CART (nouveau module, absent du plan v1)
GET    /cart                         # getCartItems(currentUser)
POST   /cart/items                   # addCartItem(currentUser, productId, quantity)
PUT    /cart/items/:productId        # updateCartItemQuantity
DELETE /cart/items/:productId        # removeCartItem
DELETE /cart                         # clearCart
GET    /cart/count                   # getCartItemCount (badge UI)

ORDERS
POST   /orders/checkout              # createOrder(currentUser, paymentMethod) — équivalent createOrder + markOrderAsPaid enchaînés
GET    /orders                       # getOrdersByUser(currentUser)
GET    /orders/:id                   # getOrderById + getOrderItems, contrôle d'accès acheteur/commerçant
GET    /orders/shop                  # getOrdersForShopOwner(currentUser)
GET    /orders/:id/items/shop        # getOrderItemsForShop (pour blocking_order_screen)
PATCH  /orders/:id/status            # advanceOrderStatusForShop
POST   /orders/:id/refund            # refundOrderForShop
GET    /shops/:id/blocking-orders    # getBlockingOrdersForShop (avant suppression commerce)
GET    /products/:id/blocking-orders # getBlockingOrdersForProduct (avant suppression produit)

UPLOADS
POST   /uploads/image?owner=shop|product   # ImageStorageService équivalent serveur
POST   /uploads/model                      # Model3dStorageService équivalent serveur
```

Ces routes sont maintenant une **transposition directe et quasi-exhaustive** des méthodes publiques de `DatabaseHelper` — plus une hypothèse comme en v1.

# 10. Authentification et autorisation

Ce qui existe (confirmé) : `AuthService` gère `signUp`/`login`/`logout` en mémoire, hash SHA-256 salé, aucune session persistée entre redémarrages, aucune contrainte de connexion imposée par défaut (l'app reste utilisable sans compte — c'est chaque écran qui restreint ponctuellement une action).

Ce qui est conservé côté Flutter : le pattern singleton `ChangeNotifier`, l'interface publique (`currentUser`, `isLoggedIn`, `signUp`, `login`, `logout`), les exceptions `AuthException` déjà levées avec des messages prêts pour l'UI (email déjà utilisé, mot de passe trop court, email/mot de passe incorrect — messages **déjà écrits**, à réutiliser tels quels côté backend pour ne rien changer à l'UX).

Ce qui migre vers le backend :
- **Hash du mot de passe** : SHA-256 salé maison → **bcrypt** ou **argon2** (recommandation : `bcrypt`, cost factor 10-12, suffisant pour ce contexte). C'est un changement de mécanisme, pas une simple portée de colonnes — la colonne `password_salt` séparée disparaît (bcrypt embarque le sel dans le hash).
- **Session** : aujourd'hui inexistante entre redémarrages → le backend introduit un **JWT** signé, ce qui est en réalité une **amélioration** de l'existant (aujourd'hui, fermer l'app déconnecte systématiquement ; avec un JWT stocké côté Flutter — `flutter_secure_storage`, à ajouter —, la session peut survivre à un redémarrage si souhaité). Point à valider avec l'équipe : est-ce un comportement voulu ou faut-il reproduire l'expiration immédiate actuelle ? Recommandation : profiter de la migration pour persister la session (meilleure UX), sauf avis contraire.

Contrôle de propriété (déjà entièrement spécifié par le code existant, à reproduire à l'identique côté middleware/repository) :
- `shops.owner_id` UNIQUE → 1 commerce max par utilisateur, erreur 409 explicite si violé (reproduit `ShopException('Vous possédez déjà un commerce.')`, déjà catché sur `DatabaseException.isUniqueConstraintError()` côté Flutter — le backend doit catcher l'équivalent PostgreSQL, code erreur `23505`)
- `products.shop_id` → propriété transitive via le commerce (`assertProductOwnership` résout d'abord le produit, puis vérifie le commerce) — logique à copier telle quelle dans le repository backend
- `getOrderById`/`getOrderItems` côté commande : la règle d'accès fine (acheteur = tout voir ; commerçant = seulement ses lignes ; ni l'un ni l'autre = rien) **n'est pas dans `DatabaseHelper`** mais dans `order_detail_screen.dart` (logique `_OrderDetailData.hasAccess`/`isBuyer`/`isMerchantHere`, actuellement calculée **côté client** après avoir tout récupéré). **Point de durcissement nécessaire lors de la migration** : côté backend, `GET /orders/:id` doit appliquer ce filtre **avant** d'envoyer les données (ne jamais renvoyer les lignes des autres commerces à un commerçant, ni la commande d'un autre acheteur) — aujourd'hui le client SQLite a accès à toute la base localement donc ce n'est pas un problème, mais un serveur partagé entre 3 développeurs (et futurs utilisateurs) l'exige.

# 11. Migration Flutter

Stratégie affinée (les Phases C/D/E/F de la v1 restent valables, complétées par le panier) :

```
Phase A — Actuel : SQLite exclusif (inchangé)

Phase B — Fondations réseau
  ApiClient (http + JWT), config adresse backend

Phase C — Auth
  AuthService garde signUp/login/logout/currentUser/isLoggedIn,
  implémentation interne devient HTTP. Écrans impactés (imports
  DatabaseHelper à retirer, aucune logique à changer) :
  login_screen.dart, signup_screen.dart — ils n'appellent QUE
  AuthService, jamais DatabaseHelper directement : bascule quasi
  gratuite.

Phase D — Shops
  ShopApiService (mêmes signatures que les méthodes DatabaseHelper
  shops : getAllShops, getShopByOwnerId, createShopForOwner,
  updateShop, deleteShopCascade, assertShopOwnership consommé côté
  serveur). Écrans : shop_list_screen.dart, shop_form_screen.dart,
  shop_detail_screen.dart, sell_screen.dart, profile_screen.dart.

Phase E — Products
  ProductApiService (getAllProducts, searchProducts,
  getProductsByOwner, createProductForOwner, updateProductForOwner,
  deleteProductForOwner). Écrans : product_list_screen.dart,
  product_form_screen.dart, product_detail_screen.dart,
  home_screen.dart, search_screen.dart, shop_detail_screen.dart.

Phase F1 — Cart (NOUVEAU, séparé des Orders — absent du plan v1)
  CartService garde items/totalAmount/addProduct/removeProduct/
  increaseQuantity/decreaseQuantity/setQuantity/clear, implémentation
  interne devient HTTP pour un utilisateur connecté — le régime
  "panier visiteur en mémoire" est INCHANGÉ (reste局 100% local, ne
  doit jamais appeler le backend). Seule la bascule connecté/visiteur
  change de mécanique interne (_reloadFromDb devient un appel HTTP).
  Écran : cart_screen.dart (aucun changement de logique d'écran,
  CartService absorbe tout).

Phase F2 — Orders
  OrderApiService (createOrder+markOrderAsPaid fusionnés en un
  /orders/checkout côté serveur — transaction unique, voir §13),
  getOrdersByUser, getOrdersForShopOwner, getOrderById+items avec
  contrôle d'accès désormais appliqué SERVEUR (voir §10, durcissement
  nécessaire), advanceOrderStatusForShop, refundOrderForShop,
  getOrderItemsForShop, getBlockingOrdersForProduct/Shop. Écrans :
  order_list_screen.dart, order_detail_screen.dart,
  shop_order_list_screen.dart, blocking_order_screen.dart,
  checkout_screen.dart, order_confirmation_screen.dart.

Phase G — Nettoyage SQLite (méthode par méthode, écran par écran)
```

Point de vigilance particulier pour la Phase F2 : `order_detail_screen.dart` calcule aujourd'hui `isBuyer`/`myShopItems`/`hasAccess` **en mémoire côté client** après avoir chargé toute la commande. Une fois migré, l'écran doit recevoir **déjà filtré** ce que le serveur autorise à voir (voir §10) — la logique d'affichage (`displayItems`, `displayTotal`) reste identique, mais la source de la donnée change de nature (pré-filtrée par le serveur, plus par le client).

# 12. Migration du panier et des commandes

**Différence majeure avec la v1 de ce plan** : le panier **est** persisté en SQLite pour les utilisateurs connectés (table `carts`/`cart_items`, Étape 5 du projet), contrairement à l'hypothèse initiale. La Section 5 en tient maintenant compte.

Logique de `CartService` à reproduire fidèlement côté backend :
- Le panier est **résolu côté serveur depuis le token JWT**, jamais depuis un `cart_id`/`user_id` transmis par le client — c'est déjà exactement le principe appliqué en SQLite (`_getOrCreateCartId` résout toujours via `user_id`, jamais un `cart_id` fourni par l'appelant) ; le backend doit reproduire cette même discipline avec `req.user.id`.
- **Un produit n'a qu'une ligne par panier** (`UNIQUE(cart_id, product_id)`) : ajouter un produit déjà présent incrémente la quantité existante, plafonnée au stock.
- Le **stock est toujours relu en base à l'écriture**, jamais depuis une valeur mémorisée côté client (`CartItem.stock` n'est qu'un indicatif d'affichage) — comportement à reproduire strictement côté backend (`SELECT stock FROM products WHERE id = $1` avant chaque `INSERT`/`UPDATE` de `cart_items`).
- Le panier **visiteur** ne migre jamais vers le backend — aucun changement à ce sujet.
- Transfert panier visiteur → panier persisté à la connexion (`CartService.loadForUser`) : logique **purement côté Flutter**, à conserver telle quelle (elle appelle simplement le nouvel `addCartItem` HTTP pour chaque article en mémoire, au lieu de l'appel SQLite).

Création de commande (`createOrder`) — logique déjà transactionnelle et complète côté SQLite, à transposer **quasiment ligne à ligne** en SQL PostgreSQL (voir §13 pour le détail) : lecture du panier persisté → relecture des prix/stock actuels depuis `products` → calcul du total → insertion `orders` (status `pending`) → insertion des `order_items` (snapshots figés) → décrément du stock → vidage de `cart_items` — **le tout dans une seule transaction**, garantissant qu'un échec à n'importe quelle étape restaure le panier intact (déjà le comportement SQLite, à ne pas régresser).

`markOrderAsPaid` (appelé juste après par `checkout_screen.dart`) : côté backend, il est recommandé de **fusionner** cette étape dans la même transaction que `createOrder` (un seul endpoint `POST /orders/checkout` qui fait les deux), puisque le paiement est de toute façon mocké et toujours réussi — inutile de laisser une fenêtre où une commande existe en `pending` sans être `paid`. **Différence volontaire et positive par rapport au SQLite actuel**, à signaler à l'équipe (§23).

# 13. Migration du stock

Le code SQLite fourni gère déjà correctement le risque de survente **au niveau applicatif** (transaction unique, relecture du stock en base, jamais de valeur mise en cache) — mais **sans verrou explicite** puisque SQLite est mono-utilisateur par nature ici (chaque développeur a son propre fichier local). Ce n'est **plus suffisant** dès que PostgreSQL est partagé entre requêtes concurrentes (plusieurs utilisateurs achetant en même temps le même produit).

Transposition recommandée de `createOrder` en transaction PostgreSQL :
```sql
BEGIN;
-- pour chaque ligne du panier :
SELECT id, name, price, stock, shop_id FROM products WHERE id = $1 FOR UPDATE;
-- vérifier stock >= quantité demandée ; sinon ROLLBACK + 409 avec le nom du produit
-- (reproduit exactement le message actuel :
--  'Stock insuffisant pour "X" (disponible : N, demandé : M).')
UPDATE products SET stock = stock - $qty WHERE id = $1;
INSERT INTO orders (user_id, total, status, payment_method) VALUES (...) RETURNING id;
INSERT INTO order_items (order_id, product_id, product_name, quantity, price, shop_id, shop_name)
  VALUES (...);  -- une ligne par article, shop_name résolu par jointure comme en SQLite
DELETE FROM cart_items WHERE cart_id = $cartId;
UPDATE orders SET status = 'paid' WHERE id = $orderId;  -- si fusion recommandée en §12
COMMIT;
```
`FOR UPDATE` (verrou pessimiste ligne par ligne) est l'ajout nécessaire par rapport à SQLite, pour bloquer les lectures concurrentes du même produit pendant la transaction — sans quoi deux commandes simultanées pourraient toutes deux lire `stock = 1` et le décrémenter chacune, aboutissant à un stock négatif malgré le `CHECK (stock >= 0)`.

Remboursement (`refundOrderForShop`) : transaction identique à l'existant — passage du statut à `refunded` + `UPDATE products SET stock = stock + quantity` pour chaque ligne du commerce concerné, avec la même vérification de transition autorisée (`OrderStatus.canTransition`) à réimplémenter côté backend TypeScript (constantes copiées de `order_status.dart`).

# 14. Migration des images et fichiers GLB

Confirmé : deux services quasi-jumeaux (`ImageStorageService`, `Model3dStorageService`), même structure (dossier dédié dans `<Documents>/uploads/`, nom de fichier généré `préfixe_timestamp_random.ext`, jamais le nom original, suppression best-effort, distinction `assets/...` vs fichier local dans `AppImage`).

Transposition backend :
- `POST /uploads/image?owner=shop|product` : reçoit un fichier `multipart/form-data` (via `multer`), valide extension (`jpg/jpeg/png/webp`) et taille (≤ 8 Mo) **avec les mêmes messages d'erreur** que `ImageStorageException` actuels, écrit dans `backend/uploads/{shops,products}/` avec un nom généré côté serveur (même logique `préfixe_timestamp_random.ext`), retourne un chemin/URL relatif (ex. `/files/products/product_1723999999_ab12cd.jpg`)
- `POST /uploads/model` : idem pour `.glb`, limite 50 Mo, dossier `backend/uploads/models/`
- Express sert `backend/uploads/` statiquement sous `/files/...` (`express.static`)
- `AppImage` doit être étendu pour un 3ᵉ cas (URL réseau `http://.../files/...`) en plus de `assets/` et fichier local — à faire en Phase D/E (§11), en gardant la détection `_isAsset` inchangée et en ajoutant une détection `_isNetworkUrl` (`startsWith('http')`)
- `ImagePickerField`/`ModelPickerField` (widgets) n'ont **aucune logique de stockage propre** — ils délèguent déjà entièrement à `ImageStorageService`/`Model3dStorageService` via `onChanged(path)`. Il suffit de remplacer le corps de ces deux services (Phase D/E) : `pickAndStoreImage`/`pickAndStoreModel` font l'upload HTTP au lieu de la copie locale, et retournent l'URL serveur au lieu du chemin local — **aucun widget d'écran n'a besoin d'être modifié**, seule l'implémentation interne des deux services change. C'est le point de conception le plus favorable de toute cette migration : l'app a déjà été écrite avec cette séparation en tête.
- Suppression : `deleteImage`/`deleteModel` deviennent des appels `DELETE /uploads/...` — mécanique best-effort identique.
- Les fichiers du **seed** (`assets/images/...`, `assets/models/...`) restent des assets Flutter embarqués, non concernés par cette migration (voir §7).

# 15. Migration de la géolocalisation

Confirmé en détail (`location_service.dart`, `places_service.dart`) :
- `shops.latitude`/`longitude`/`google_place_id` déjà en Section 5, valeurs correctement typées `DOUBLE PRECISION`/`TEXT`
- **`PlacesService` ne touche jamais à la base ni au backend** : c'est un appel direct Flutter → API Google Places (HTTP), avec un **mode mock local** actif par défaut (pas de clé API configurée). Rien à migrer côté backend pour l'autocomplétion elle-même — le flux `place_search_screen.dart → PlacesService → ShopFormScreen` reste 100% côté client, avant/après migration.
- Seul le **résultat** de la sélection (`PlaceSelection` : name, formattedAddress, latitude, longitude, placeId) est envoyé au backend via `POST/PUT /shops`, exactement comme aujourd'hui il est envoyé à `DatabaseHelper.createShopForOwner`/`updateShop`.
- `LocationService.buildMapsUri`/`openShopLocation` restent **entièrement côté client** (construction d'URL Google Maps + `url_launcher`), aucune dépendance backend.
- **Conclusion** : la géolocalisation ne nécessite **aucune adaptation d'API en plus de la Section 9** (`POST/PUT /shops` transporte déjà `latitude`/`longitude`/`google_place_id`) — c'est la partie la plus simple de toute la migration, contrairement à ce que laissait supposer l'absence d'information en v1.
- **Point réel à surveiller** : si l'équipe active un jour une vraie clé `GOOGLE_PLACES_API_KEY`, cette clé reste **côté Flutter** (`--dart-define`), donc **jamais dans le `.env` backend** — à ne pas confondre avec les secrets serveur de la Section 17.

# 16. Gestion des erreurs

Le code SQLite fourni définit déjà 5 exceptions métier dédiées, avec des **messages déjà rédigés pour l'utilisateur final** : `OrderException`, `AuthException`, `ShopException`, `PermissionException`, `BlockingOrdersException` (celle-ci porte en plus la liste des commandes bloquantes, consommée par `blocking_order_screen.dart`).

Recommandation forte : le backend doit lever des erreurs **portant les mêmes messages**, pour que les écrans Flutter existants (qui catchent déjà `on AuthException catch (e) { ... e.message ... }`, `on BlockingOrdersException catch (e) { ... e.orders ... }`) continuent de fonctionner **sans modification de leur logique d'affichage**, seule la source de l'exception change (HTTP → parsing d'une réponse d'erreur JSON → reconstruction de la même classe d'exception Dart côté `ApiClient`).

Mapping HTTP recommandé :
- `AuthException` → 400/401 selon le cas (email déjà utilisé = 409 en réalité, à corriger par rapport au comportement SQLite actuel qui lève la même exception dans les deux cas — amélioration mineure à signaler)
- `ShopException` ("Vous possédez déjà un commerce", "Vous devez d'abord créer votre commerce...") → 409
- `PermissionException` → 403
- `OrderException` (stock insuffisant, transition invalide, commande introuvable) → 409 ou 404 selon le cas précis
- `BlockingOrdersException` → 409, avec le payload `orders` inclus dans le corps JSON pour que `blocking_order_screen.dart` puisse les afficher exactement comme aujourd'hui

`ApiClient` (Phase B) doit donc savoir **reconstruire la bonne classe d'exception Dart** à partir d'un champ `code` dans la réponse d'erreur JSON (ex. `{ "code": "BLOCKING_ORDERS", "message": "...", "orders": [...] }`), pour que tous les `try/catch` déjà écrits dans les écrans (`on BlockingOrdersException catch`, `on OrderException catch`, etc.) continuent de fonctionner à l'identique.

# 17. Configuration locale des trois développeurs

Inchangé par rapport à la v1 (voir ce plan précédent), avec une précision supplémentaire : `GOOGLE_PLACES_API_KEY` (si utilisée) est un `--dart-define` **Flutter**, jamais une variable du `.env` backend (voir §15) — à ne pas ajouter par erreur à `backend/.env.example`.

```
PORT=3000
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=ecommercial
DATABASE_USER=postgres
DATABASE_PASSWORD=
JWT_SECRET=change-me-in-each-local-env
JWT_EXPIRES_IN=7d
```

# 18. Organisation Git et travail à trois

Reprend la v1, avec l'ajout du module `cart` (§8/§9) comme unité de travail indépendante supplémentaire — peut être développé par le même développeur que `orders` (dépendance logique forte entre panier et checkout) ou séparément si la charge le justifie.

Ordre de dépendance affiné :
1. `schema.sql` (bloquant, Section 5-6)
2. Backend Auth (bloque le middleware `requireAuth`)
3. Backend Shops et Products (parallèle, une fois Auth prêt)
4. Backend Cart (dépend de Products pour la lecture du stock)
5. Backend Orders (dépend de Cart, Products, Shops)
6. Flutter Phase C dès que Auth backend répond
7. Flutter Phases D/E en parallèle une fois Shops/Products stables
8. Flutter Phase F1 (Cart) une fois le module Cart backend stable
9. Flutter Phase F2 (Orders) en dernier, dépend de F1

# 19. Ordre exact des étapes d'implémentation

1. Initialiser `backend/` (structure Section 8)
2. Écrire et valider `backend/database/schema.sql` (Section 5-6)
3. `.env.example`, `.gitignore`
4. Module Auth (bcrypt, JWT, middleware `requireAuth`)
5. Module Shops (CRUD, contrainte 1 commerce/user, ownership)
6. Module Products (CRUD, ownership via shop, recherche `searchProducts` équivalente)
7. Module Cart (persisted uniquement, résolu par JWT)
8. Module Orders (checkout transactionnel avec `FOR UPDATE`, historique, statuts, remboursement, blocages)
9. Module Uploads (images + modèles `.glb`, `multer`, `express.static`)
10. `backend/database/seed.sql` (Section 7, traduction directe de `seed_data.dart` — aucun blocage restant)
11. Trancher la stratégie de catégories incohérentes (§7/§23) avant d'écrire le seed définitif
12. Flutter Phase B (ApiClient)
13. Flutter Phase C (Auth) — bascule quasi gratuite (voir §11)
14. Flutter Phases D/E (Shops, Products) en parallèle
15. Migration images/GLB (§14) — dès que D/E sont stables, transparente pour les widgets
16. Flutter Phase F1 (Cart)
17. Flutter Phase F2 (Orders), avec durcissement du contrôle d'accès `GET /orders/:id` (§10)
18. Migration géolocalisation : aucune action backend requise (§15), juste vérifier que `POST/PUT /shops` transporte bien les 3 champs
19. Tests (Section 24)
20. Phase G — nettoyage progressif de `database_helper.dart`

# 20. Liste exacte des fichiers à créer

Backend :
```
backend/package.json, tsconfig.json, .env.example, .gitignore, README.md
backend/database/schema.sql, seed.sql
backend/src/app.ts, server.ts
backend/src/config/env.ts
backend/src/db/pool.ts
backend/src/middleware/requireAuth.ts, errorHandler.ts, validate.ts
backend/src/modules/auth/{auth.routes,auth.controller,auth.repository}.ts
backend/src/modules/shops/{shops.routes,shops.controller,shops.repository}.ts
backend/src/modules/products/{products.routes,products.controller,products.repository}.ts
backend/src/modules/cart/{cart.routes,cart.controller,cart.repository}.ts
backend/src/modules/orders/{orders.routes,orders.controller,orders.repository}.ts
backend/src/modules/uploads/{uploads.routes,uploads.controller}.ts
backend/src/types/express.d.ts
```

Flutter :
```
lib/services/api_client.dart
lib/services/shop_api_service.dart   (ou fusion directe dans un DatabaseHelper-like au choix de l'équipe)
lib/services/product_api_service.dart
lib/config/api_config.dart
```
Note : `auth_service.dart` et `cart_service.dart` ne sont **pas de nouveaux fichiers** — leur contenu interne est réécrit sur place (voir §11), leur nom de fichier et leur interface publique restent identiques.

# 21. Liste exacte des fichiers Flutter à modifier

- `auth_service.dart` — corps réécrit (HTTP), signatures publiques inchangées
- `cart_service.dart` — corps réécrit pour la branche "utilisateur connecté" (HTTP), branche "visiteur" **inchangée**
- `image_storage_service.dart`, `model_3d_storage_service.dart` — corps réécrit (upload HTTP), signatures publiques inchangées (aucun widget appelant à modifier)
- `shop_list_screen.dart`, `shop_form_screen.dart`, `shop_detail_screen.dart`, `sell_screen.dart`, `profile_screen.dart` — import `DatabaseHelper` remplacé par le nouveau service Shops
- `product_list_screen.dart`, `product_form_screen.dart`, `product_detail_screen.dart`, `home_screen.dart`, `search_screen.dart` — import `DatabaseHelper` remplacé par le nouveau service Products
- `order_list_screen.dart`, `order_detail_screen.dart`, `shop_order_list_screen.dart`, `blocking_order_screen.dart`, `checkout_screen.dart`, `order_confirmation_screen.dart` — import `DatabaseHelper` remplacé par le nouveau service Orders
- `login_screen.dart`, `signup_screen.dart` — **aucun changement de logique**, ils n'appellent que `AuthService` (déjà migré en interne)
- `app_image.dart` — ajout du 3ᵉ cas URL réseau
- `pubspec.yaml` — ajout éventuel de `flutter_secure_storage` (persistance JWT, voir §10)

# 22. Liste des fichiers à supprimer à terme

- `lib/database/database_helper.dart` — en tout dernier, une fois Phase G terminée
- `lib/database/seed_data.dart` — supprimable dès que le seed PostgreSQL est validé et que `ensureSeeded()` n'est plus appelé (Phase C ou plus tard, non bloquant)
- Aucun modèle (`user.dart`, `product.dart`, etc.) n'est supprimé — ils continuent de représenter les données, `fromMap` fonctionnant identiquement sur une réponse JSON HTTP désérialisée en `Map<String, dynamic>` (aucune modification de ces modèles n'est même nécessaire, un avantage direct du choix historique de `fromMap`/`toMap`)

# 23. Risques et points à confirmer

**Résolu depuis la v1** : schéma de données, panier, authentification, stockage fichiers, géolocalisation — tous confirmés avec le code source réel.

**Points encore ouverts** :
1. **Statut `cancelled`** : présent dans `OrderStatus` mais **aucun code fourni** ne le déclenche (absent de `merchantTransitions`). À clarifier avec l'équipe avant d'écrire le module Orders — s'agit-il d'une fonctionnalité prévue (ex. annulation par l'acheteur, non encore implémentée), ou d'un statut mort à retirer ? Ne pas l'implémenter par supposition côté backend.
2. **Incohérence des catégories produit** : le seed utilise 5 valeurs courtes (`'Mobilier'`, `'Décoration'`, etc.) tandis que `kProductCategories` en définit 13 différentes et plus précises. Les 20 produits seedés ont donc des catégories qui **ne correspondront à aucune option du formulaire `ProductFormScreen`** une fois édités (le formulaire gère ce cas via un item "(ancienne valeur)" ajouté dynamiquement — donc pas un bug bloquant, mais une incohérence de contenu à trancher : réécrire le seed avec les nouvelles catégories, ou laisser tel quel ?
3. **`home_screen.dart` a sa propre liste de catégories** (`_categories` locale : Tout, Mobilier, Décoration, Électronique, Mode, Artisanat), **différente** de `kProductCategories` utilisée par `search_screen.dart`. Cela signifie que le filtre catégorie de l'accueil et celui de la recherche ne proposent pas les mêmes options aujourd'hui — comportement existant, non introduit par la migration, mais à signaler car une migration bien faite ne doit pas le "corriger" silencieusement sans validation de l'équipe.
4. **Suppression de compte utilisateur** : aucune fonctionnalité de ce type dans le code fourni. La Section 5 propose `shops.owner_id ON DELETE SET NULL` par analogie avec le comportement "commerce orphelin" déjà toléré par le schéma SQLite (commerces seedés sans propriétaire) — mais ce choix n'a jamais été testé dans le contexte "un utilisateur avec un commerce actif supprime son compte", puisque cette fonctionnalité n'existe pas encore. À valider si elle est prévue.
5. **`markOrderAsPaid` fusionné dans `createOrder`** (§12) est une proposition d'amélioration, pas une simple transposition — à faire valider explicitement par l'équipe avant implémentation, même si le risque est faible (le paiement mocké réussit toujours).
6. **Fichiers non analysés** : `ar_view_screen.dart`, `ar_plugin_compile_check.dart`, `placeholder_screen.dart`, `place_search_screen.dart` restent non fournis. Aucun n'est bloquant pour le schéma de données ou l'API (voir note en tête de document), mais `place_search_screen.dart` devra être vérifié en Phase D pour confirmer qu'il n'appelle bien que `PlacesService` (déjà migré nulle part, §15) et pas `DatabaseHelper`.

# 24. Plan de tests

Reprend la v1 (tests d'intégration `jest`/`supertest` par module contre une base PostgreSQL de test), avec des cas supplémentaires rendus possibles par la connaissance exacte du code :
- Un ajout au panier au-delà du stock disponible plafonne exactement à la quantité restante (reproduit le comportement `addCartItem`/`updateCartItemQuantity` : `added < requested` géré avec un message dédié côté `product_detail_screen.dart`, à ne pas casser)
- Un panier vide empêche `POST /orders/checkout` avec le message exact `"Le panier est vide."`
- Une transition de statut hors `merchantTransitions` renvoie le message exact `'Transition invalide : "X" -> "Y".'`
- Un remboursement réapprovisionne le stock **uniquement** pour les lignes du commerce du commerçant qui rembourse (pas toutes les lignes de la commande)
- Concurrence : deux requêtes `POST /orders/checkout` simultanées sur un produit à stock `1` ne doivent jamais toutes les deux réussir (test avec `FOR UPDATE`, §13)
- `GET /orders/:id` par un utilisateur qui n'est ni l'acheteur ni un commerçant concerné doit renvoyer 403, jamais les données partielles

# 25. Première étape concrète

Le plan est maintenant exécutable sans blocage majeur. Première action concrète : **initialiser `backend/`** (Section 20) et **écrire `schema.sql`** à partir du bloc SQL final de la Section 5 — plus aucune donnée manquante n'empêche cette étape, contrairement à la v1. Il est toutefois recommandé de trancher au préalable le point 1 de la Section 23 (statut `cancelled`) avec l'équipe, pour éviter de devoir modifier la contrainte `CHECK` sur `orders.status` juste après l'avoir écrite.

---

## Checklist de migration (v2)

1. [x] ~~Fournir `database_helper.dart` et les fichiers modèles manquants~~ — fait
2. [x] ~~Fournir `seed_data.dart`~~ — fait
3. [x] ~~Fournir `auth_service.dart`, `user.dart`, `cart_service.dart`, `cart_item.dart`~~ — fait
4. [x] ~~Fournir les fichiers de géolocalisation~~ — fait
5. [x] ~~Fournir les écrans restants~~ — fait (sauf AR/placeholder/place_search, non bloquants)
6. [ ] Trancher avec l'équipe : statut `cancelled` (§23.1), incohérence catégories seed (§23.2), double liste de catégories home/search (§23.3), suppression de compte (§23.4), fusion `markOrderAsPaid` (§23.5)
7. [ ] Initialiser `backend/` (structure, package.json, tsconfig.json)
8. [ ] Écrire et valider `backend/database/schema.sql`
9. [ ] `.env.example`, `.gitignore`
10. [ ] Module Auth (bcrypt, JWT, middleware)
11. [ ] Module Shops
12. [ ] Module Products
13. [ ] Module Cart
14. [ ] Module Orders (transaction `FOR UPDATE`, statuts, remboursement, blocages, contrôle d'accès fin)
15. [ ] Module Uploads (images + `.glb`)
16. [ ] `backend/database/seed.sql`
17. [ ] Flutter Phase B — ApiClient
18. [ ] Flutter Phase C — Auth
19. [ ] Flutter Phases D/E — Shops, Products
20. [ ] Migration images/GLB (`AppImage` étendu)
21. [ ] Flutter Phase F1 — Cart
22. [ ] Flutter Phase F2 — Orders
23. [ ] Vérifier géolocalisation (aucune action backend attendue, juste validation bout-en-bout)
24. [ ] Vérifier `place_search_screen.dart` (fichier non fourni) une fois disponible
25. [ ] Tests d'intégration backend (dont concurrence stock)
26. [ ] Tests manuels croisés entre les 3 développeurs
27. [ ] Flutter Phase G — nettoyage progressif de `database_helper.dart`, `seed_data.dart`
28. [ ] Suppression finale de `database_helper.dart`