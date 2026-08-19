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

## Vérifié dans cette session

Un test de bout en bout (schéma + seed appliqués sur un PostgreSQL local,
serveur démarré, requêtes réelles) a confirmé : inscription/connexion,
unicité email et commerce (409), création commerce/produit, panier avec
plafonnement au stock, checkout transactionnel avec décrément de stock,
contrôle d'accès `GET /orders/:id` (acheteur / commerçant / tiers refusé),
blocage de suppression tant qu'une commande non finalisée existe,
transitions de statut valides/invalides, et upload d'image (succès,
extension refusée, taille dépassée, non authentifié).
