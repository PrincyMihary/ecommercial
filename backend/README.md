# ecommercial-backend

API REST Node.js / Express / TypeScript pour la marketplace **ecommercial**,
qui remplace `DatabaseHelper` (Flutter/SQLite) par un backend PostgreSQL
partagé entre les développeurs. Voir `../migration_plan.md` pour le
détail des choix de conception (schéma, transactions, contrôle d'accès,
messages d'erreur repris à l'identique de l'app Flutter).

## Démarrage rapide

Prérequis : Node.js ≥ 18, une instance PostgreSQL locale (voir §17 du
plan de migration — une instance par développeur).

```bash
cd backend
cp .env.example .env        # puis ajuster DATABASE_PASSWORD, JWT_SECRET...
npm install

# Créer la base (une fois), puis appliquer le schéma + le seed :
createdb ecommercial          # ou : psql -c "CREATE DATABASE ecommercial;"
npm run db:schema
npm run db:seed

npm run dev                   # démarre sur http://localhost:3000 (rechargement à chaud)
# ou, en production :
npm run build && npm start
```

`GET /health` doit répondre `{"status":"ok"}` une fois le serveur démarré.

## Structure

```
backend/
├── database/schema.sql   # schéma PostgreSQL (§5-6 du plan)
├── database/seed.sql     # 5 commerces / 21 produits, traduits de seed_data.dart
├── src/
│   ├── api/               # convention de sérialisation BIGINT/BIGSERIAL -> JSON (voir section dédiée ci-dessous)
│   │   ├── serialization.ts
│   │   └── id-paths.ts
│   ├── config/env.ts     # variables d'environnement
│   ├── db/pool.ts        # pool pg + helper de transaction
│   ├── errors.ts         # exceptions métier (miroir des exceptions Dart)
│   ├── middleware/       # requireAuth (JWT), errorHandler (mapping HTTP)
│   ├── modules/
│   │   ├── auth/         # POST /auth/register, /auth/login, GET /users/me
│   │   ├── shops/        # CRUD commerces + ownership
│   │   ├── products/     # CRUD produits + recherche + ownership
│   │   ├── cart/         # panier persisté, résolu strictement via JWT
│   │   ├── orders/       # checkout, historique, statuts, remboursement
│   │   └── uploads/      # upload images/.glb via multer, servi sous /files
│   ├── app.ts
│   └── server.ts
├── tests/                # tests Jest + Supertest (voir section Tests ci-dessous)
└── uploads/{shops,products,models}/   # fichiers uploadés (voir .gitignore)
```

## Routes principales

Voir `../migration_plan.md` §9 pour la liste complète et la
correspondance avec les méthodes `DatabaseHelper` d'origine. Résumé :

- `POST /auth/register`, `POST /auth/login`, `GET /users/me`
- `GET /shops`, `GET /shops/:id`, `GET /shops/me`, `GET /shops/:id/products`,
  `POST /shops`, `PUT /shops/:id`, `DELETE /shops/:id`, `GET /shops/:id/blocking-orders`
- `GET /products`, `GET /products/search`, `GET /products/:id`, `GET /products/mine`,
  `POST /products`, `PUT /products/:id`, `DELETE /products/:id`, `GET /products/:id/blocking-orders`
- `GET /cart`, `GET /cart/count`, `POST /cart/items`, `PUT /cart/items/:productId`,
  `DELETE /cart/items/:productId`, `DELETE /cart`
- `POST /orders/checkout`, `GET /orders`, `GET /orders/shop`, `GET /orders/:id`,
  `GET /orders/:id/items/shop`, `PATCH /orders/:id/status`, `POST /orders/:id/refund`
- `POST /uploads/image?owner=shop|product`, `POST /uploads/model`, `DELETE /uploads`

Toutes les routes protégées attendent `Authorization: Bearer <token>`
(JWT retourné par `/auth/register` ou `/auth/login`).

## Erreurs

Les réponses d'erreur suivent le format `{ "code": "...", "message": "..." }`
(ou `{ "code": "BLOCKING_ORDERS", "message": "...", "orders": [...] }` pour
les suppressions bloquées), avec des messages identiques à ceux déjà
écrits côté Flutter (`AuthException`, `ShopException`, `PermissionException`,
`OrderException`, `BlockingOrdersException` — voir migration_plan.md §16).

## Convention de sérialisation des BIGINT/BIGSERIAL

PostgreSQL utilise `BIGINT`/`BIGSERIAL` pour toutes les clés primaires
(`users.id`, `shops.id`, `products.id`, `orders.id`, `order_items.id`,
ainsi que les colonnes `carts.id`/`cart_items.id` en usage interne).
Le driver `pg` renvoie ces valeurs sous forme de `string` JavaScript par
défaut (`"1"`), afin de ne jamais perdre de précision au-delà de
`Number.MAX_SAFE_INTEGER`. Les modèles Flutter attendent en revanche un
`number` JSON (`id: map['id'] as int`), qui échoue avec une `TypeError`
si le JSON contient `"id": "1"` au lieu de `"id": 1`.

**La conversion est explicite et centralisée**, jamais globale :

- `src/api/serialization.ts` expose `toSafeApiId(value, fieldName?)`,
  utilisé directement dans le DTO/mapper de chaque module concerné
  (`auth.repository.toPublicUser`, `shops.controller.toDto`,
  `products.controller.toDto`, `orders.mapper.orderDto`/`orderItemDto`,
  `cart.controller.toDto`) pour convertir uniquement les champs
  identifiants listés dans `src/api/id-paths.ts`.
- Une variante `serializeApiResponse`/`sendApiJson` (mêmes garanties,
  déclarée par chemins `"user.id"`, `"items[].id"`) reste disponible
  pour un futur endpoint qui préfère convertir un corps de réponse déjà
  construit plutôt que d'appeler `toSafeApiId` champ par champ.
- **Aucune conversion globale/naïve n'est appliquée** : `src/db/pool.ts`
  ne reconfigure plus le type parser `pg` global
  (`types.setTypeParser(20, ...)`, OID 20 = BIGINT) — cette approche,
  présente dans une version antérieure du backend, convertissait *tout*
  BIGINT de la connexion sans jamais vérifier la plage entière sûre de
  JavaScript. Les identifiants restent des `string` en interne
  (comparaisons, requêtes SQL, `sub` du JWT) ; seule la réponse JSON
  finale expose des `number`.
- Une valeur hors de `[Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER]`
  fait lever une erreur explicite par `toSafeApiId`/`serializeApiResponse`
  plutôt que d'être tronquée silencieusement.
- Toute autre chaîne numérique de l'API (téléphone, référence, code
  postal...) n'est **jamais** convertie : seuls les champs listés dans
  `src/api/id-paths.ts` le sont.

## Tests

```bash
npm test
```

Les tests (`tests/*.test.ts`, Jest + Supertest) sont des tests
**d'intégration réels** : ils démarrent l'application Express en
mémoire et exécutent de vraies requêtes SQL contre une base PostgreSQL
de test (variables `DATABASE_*`, voir `tests/setup-env.ts` — par défaut
`ecommercial_test` sur `localhost:5432`). Le schéma doit y être
appliqué au préalable :

```bash
createdb ecommercial_test
DATABASE_NAME=ecommercial_test npm run db:schema
```

- `tests/serialization.test.ts` — tests unitaires purs (sans base) du
  serializer BIGINT : id simple, id imbriqué, tableau, non-conversion
  des autres chaînes numériques, précision autour de
  `Number.MAX_SAFE_INTEGER`.
- `tests/auth.test.ts` — `POST /auth/register`, `/auth/login`,
  `GET /users/me` : vérifie `typeof id === 'number'` et l'absence de
  `"id":"1"` dans le JSON brut.
- `tests/shops.test.ts`, `tests/products.test.ts` — mêmes vérifications
  sur `shops.id`/`ownerId` et `products.id`/`shopId`.
- `tests/orders.test.ts` — non-régression Cart/Orders (modules non
  réécrits) : ajout au panier, checkout, détail de commande — vérifie
  que `order.id`, `order.userId`, `order_item.id/orderId/productId`
  restent des `number` JSON après l'intégration de la convention BIGINT.

## Vérifié dans cette session

Un test de bout en bout (schéma + seed appliqués sur un PostgreSQL local,
serveur démarré, requêtes réelles) a confirmé : inscription/connexion,
unicité email et commerce (409), création commerce/produit, panier avec
plafonnement au stock, checkout transactionnel avec décrément de stock,
contrôle d'accès `GET /orders/:id` (acheteur / commerçant / tiers refusé),
blocage de suppression tant qu'une commande non finalisée existe,
transitions de statut valides/invalides, et upload d'image (succès,
extension refusée, taille dépassée, non authentifié).
