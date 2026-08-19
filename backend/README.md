# Backend — ecommercial

Backend Node.js + Express + TypeScript + PostgreSQL pour la migration de
l'application Flutter marketplace (actuellement SQLite).

Ce dossier contient uniquement la **fondation** du backend : configuration,
connexion PostgreSQL, schéma de base de données, serveur Express minimal
avec `GET /health`. Les modules métier (Auth, Shops, Products, Cart,
Orders, Uploads) seront ajoutés par la suite.

Le backend est prévu pour tourner **localement** dans un premier temps.

## 1. Prérequis

- Node.js 18 ou supérieur
- PostgreSQL 14 ou supérieur, installé et lancé localement (ce projet ne
  l'installe pas automatiquement — utilisez votre gestionnaire de paquets
  habituel, Docker, ou l'installeur officiel PostgreSQL)
- Une base de données PostgreSQL vide créée pour ce projet, par exemple :

```bash
createdb ecommercial
```

## 2. Installation des dépendances

Depuis le dossier `backend/` :

```bash
npm install
```

## 3. Configuration (.env)

Copier le fichier d'exemple puis l'adapter :

```bash
cp .env.example .env
```

Éditer `.env` et renseigner au minimum :

```
PORT=3000
DATABASE_URL=postgres://VOTRE_USER:VOTRE_MOT_DE_PASSE@localhost:5432/ecommercial
JWT_SECRET=une-valeur-longue-et-aleatoire-jamais-committee
JWT_EXPIRES_IN=7d
```

`JWT_SECRET` est **obligatoire** : le serveur refuse de démarrer si elle
est absente (fail-fast, voir `src/config/env.ts`). Générez-en une
localement, par exemple :

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

`JWT_EXPIRES_IN` est optionnelle (défaut `7d`) et accepte un format court
type `ms` (`7d`, `12h`, `30m`, ...).

`.env` n'est jamais commité (voir `.gitignore`) — chaque développeur a sa
propre configuration locale.

## 4. Création du schéma

Exécute `database/schema.sql` contre votre base PostgreSQL locale. Ce
script peut être relancé autant de fois que nécessaire pour réinitialiser
la base (il supprime et recrée les tables).

```bash
psql "$DATABASE_URL" -f database/schema.sql
```

(Remplacez `"$DATABASE_URL"` par la valeur de votre `.env`, ou exportez la
variable au préalable : `export DATABASE_URL=...`.)

## 5. Exécution du seed

Insère les données de démonstration (5 commerces, 20 produits), fidèles à
`seed_data.dart` :

```bash
psql "$DATABASE_URL" -f database/seed.sql
```

À exécuter **après** `schema.sql`, sur une base fraîchement recréée
(sinon risque de doublons, le script n'est pas idempotent).

## 6. Lancement du serveur

Mode développement (rechargement automatique) :

```bash
npm run dev
```

Mode production (build puis exécution) :

```bash
npm run build
npm start
```

Le serveur écoute sur le port défini par `PORT` dans `.env` (`3000` par
défaut). Le port est **toujours configurable** — ne jamais le hardcoder
dans l'app Flutter.

## 7. Test de GET /health

```bash
curl http://localhost:3000/health
```

Réponse attendue :

```json
{
  "status": "ok",
  "timestamp": "2026-08-20T12:00:00.000Z"
}
```

## 8. Module Authentification (Agent 2)

### Routes

| Méthode | Route            | Protégée | Description                          |
|---------|-------------------|:--------:|---------------------------------------|
| POST    | `/auth/register`  | non      | Crée un compte et retourne `{ user, token }` |
| POST    | `/auth/login`     | non      | Connecte un utilisateur, retourne `{ user, token }` |
| GET     | `/users/me`       | oui      | Retourne l'utilisateur courant (`{ user }`) |

### Authentification des requêtes protégées

Envoyer le JWT obtenu via `/auth/register` ou `/auth/login` dans l'en-tête :

```
Authorization: Bearer <token>
```

### Exemples curl

**Inscription**

```bash
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
        "full_name": "Alice Rasoa",
        "email": "alice@example.com",
        "phone": "0341234567",
        "password": "secret123"
      }'
```

Réponse (`201 Created`) :

```json
{
  "user": {
    "id": 1,
    "full_name": "Alice Rasoa",
    "email": "alice@example.com",
    "phone": "0341234567",
    "created_at": "2026-08-20T10:00:00.000Z"
  },
  "token": "eyJhbGciOi..."
}
```

**Connexion**

```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{ "email": "alice@example.com", "password": "secret123" }'
```

Réponse (`200 OK`) : même forme que l'inscription (`{ user, token }`).

**Utilisateur courant**

```bash
curl http://localhost:3000/users/me \
  -H "Authorization: Bearer eyJhbGciOi..."
```

Réponse (`200 OK`) :

```json
{
  "user": {
    "id": 1,
    "full_name": "Alice Rasoa",
    "email": "alice@example.com",
    "phone": "0341234567",
    "created_at": "2026-08-20T10:00:00.000Z"
  }
}
```

### Format d'erreur

Toutes les erreurs (Auth et futurs modules, via `AppError` /
`src/middleware/errorHandler.ts`) suivent ce format JSON plat :

```json
{ "code": "AUTH_INVALID_CREDENTIALS", "message": "Email ou mot de passe incorrect." }
```

> Ce format (plat, au niveau racine) est celui prescrit par le plan de
> migration §16, pour permettre à un futur `ApiClient` Flutter de
> reconstruire directement les exceptions Dart existantes
> (`AuthException`, etc.) à partir du champ `code`. Le document de
> mission transmis à cet agent donnait un exemple de format imbriqué
> (`{ "error": { "code": ..., "message": ... } }`) ; en cas de
> contradiction explicite avec le plan de migration, ce dernier a été
> retenu — voir section "Points transmis à l'agent suivant" plus bas.

### Codes HTTP utilisés

| Code | Cas |
|------|-----|
| 201  | Inscription réussie |
| 200  | Connexion réussie / `GET /users/me` réussi |
| 400  | Champ manquant/invalide (nom, email, mot de passe trop court) |
| 401  | Identifiants invalides, token manquant/invalide/expiré |
| 409  | Email déjà utilisé |

### Codes d'erreur (`code`)

`AUTH_NAME_REQUIRED`, `AUTH_INVALID_EMAIL`, `AUTH_PASSWORD_TOO_SHORT`,
`AUTH_EMAIL_ALREADY_USED`, `AUTH_INVALID_CREDENTIALS`,
`AUTH_TOKEN_MISSING`, `AUTH_TOKEN_INVALID`, `AUTH_USER_NOT_FOUND`.

### Sécurité

- Mots de passe hashés avec **bcrypt** (cost factor 12), jamais stockés
  en clair, jamais renvoyés dans une réponse HTTP.
- JWT signé avec `JWT_SECRET` (variable d'environnement uniquement,
  jamais hardcodé), non stocké en base de données.
- SQL paramétré uniquement (`pg`, placeholders `$1`, `$2`, ...).
- Les erreurs SQL brutes ne sont jamais exposées au client (voir
  `src/middleware/errorHandler.ts`).

### Tests

```bash
npm test
```

Nécessite une base PostgreSQL de test (voir `tests/setup-env.ts` pour la
variable `DATABASE_URL` par défaut), avec le schéma déjà appliqué :

```bash
createdb ecommercial_test
psql "$DATABASE_URL" -f database/schema.sql
```

Couvre : inscription réussie, email déjà utilisé (409), mot de passe
trop court (400), login réussi, mauvais mot de passe (401), email
inconnu (401), `GET /users/me` sans token (401), avec token invalide
(401), avec token valide (200).

## Structure du projet

```
backend/
├── src/
│   ├── config/env.ts             # Variables d'environnement (+ JWT_SECRET, JWT_EXPIRES_IN)
│   ├── db/pool.ts                 # Pool de connexion PostgreSQL centralisé (pg.Pool)
│   ├── errors/AppError.ts         # Erreur métier générique -> réponse JSON { code, message }
│   ├── middleware/
│   │   ├── auth.ts                 # Middleware JWT `authenticate`, réutilisable par tous les modules
│   │   └── errorHandler.ts         # Handler d'erreurs centralisé
│   ├── modules/
│   │   ├── auth/                    # register / login (auth.routes/controller/service/repository)
│   │   └── users/                   # GET /users/me (protégée par `authenticate`)
│   ├── api/
│   │   ├── id-paths.ts             # Allowlist explicite des chemins d'ID BIGINT/BIGSERIAL
│   │   └── serialization.ts        # Sérialisation API centralisée et sûre
│   ├── types/express.d.ts         # Typage `req.user`
│   ├── app.ts                      # Application Express (JSON, /health, /auth, /users, erreurs)
│   └── server.ts                   # Point d'entrée : démarre le serveur HTTP
├── database/
│   ├── schema.sql          # Schéma PostgreSQL (reproductible)
│   └── seed.sql             # Données de démonstration
├── tests/
│   ├── setup-env.ts          # Valeurs d'environnement par défaut pour les tests
│   └── auth.test.ts           # Tests d'intégration du module Auth (voir section Tests)
├── uploads/
│   ├── shops/               # Images de commerces (à venir, module Uploads)
│   ├── products/            # Images de produits (à venir, module Uploads)
│   └── models/               # Modèles 3D .glb (à venir, module Uploads)
├── .env.example
├── .gitignore
├── jest.config.js
├── package.json
├── tsconfig.json
└── README.md
```

## Points transmis à l'agent suivant (Claude 3)

- **Format d'erreur retenu** : `{ code, message, ...extra }` à plat, pas de
  clé `error` englobante (voir §8 "Format d'erreur" — contradiction avec
  l'exemple du document de mission d'Agent 2, tranchée en faveur du plan de
  migration §16 qui est explicite sur ce point). Réutilisez `AppError` /
  `errorHandler` tels quels pour rester cohérent : `throw new AppError(status,
  code, message, extraFields?)`.
- **Middleware réutilisable** : `authenticate` (`src/middleware/auth.ts`)
  expose `req.user = { id }`. Rechargez l'utilisateur complet depuis
  PostgreSQL si nécessaire (jamais de données utilisateur mises en cache
  dans le JWT au-delà de l'id).
- **`payment_method`** : toujours aucune contrainte `CHECK` en base — décision
  à prendre par le module Orders (non traité ici, hors périmètre Auth).
- **Statut `cancelled`** : toujours présent dans le `CHECK` de
  `orders.status` sans déclencheur connu — à clarifier avant le module
  Orders (non traité ici).
- **Email** : la colonne `users.email` reste un `TEXT UNIQUE` classique
  (pas `CITEXT`), la comparaison insensible à la casse est gérée en
  normalisant en minuscules côté application (`auth.service.ts`). Si un
  futur module fait des requêtes directes sur `users.email`, penser à la
  même normalisation.
- **Tests d'intégration Auth** : écrits (`tests/auth.test.ts`) mais **non
  exécutés** dans cet environnement (pas d'accès réseau/PostgreSQL ici) —
  à lancer par l'équipe (`npm test`) avant de considérer le module validé.
