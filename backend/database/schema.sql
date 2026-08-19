-- ============================================================================
-- schema.sql
-- Transposition fidèle du schéma SQLite (marketplace.db, version 7) vers
-- PostgreSQL. Voir README.md pour les instructions d'exécution.
--
-- Ce script est reproductible : il peut être exécuté plusieurs fois pour
-- réinitialiser la base locale (DROP puis CREATE, dans l'ordre compatible
-- avec les foreign keys).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Nettoyage
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS carts CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS shops CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP FUNCTION IF EXISTS set_updated_at() CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Fonction générique de mise à jour de updated_at
-- ----------------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. users
-- ----------------------------------------------------------------------------
-- NOTE (adaptation) : la colonne `password_salt` du schéma SQLite d'origine
-- n'est PAS reprise ici. bcrypt/argon2 (recommandés pour le module Auth)
-- embarquent le sel directement dans `password_hash`. Ce choix concerne
-- l'agent en charge d'Auth ; il n'est pas décidé/implémenté par cet agent.
CREATE TABLE users (
  id             BIGSERIAL PRIMARY KEY,
  full_name      TEXT NOT NULL,
  email          TEXT NOT NULL UNIQUE,
  phone          TEXT,
  password_hash  TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX users_email_idx ON users (email);

-- ----------------------------------------------------------------------------
-- 3. shops
-- ----------------------------------------------------------------------------
-- owner_id nullable + UNIQUE : reproduit exactement la règle SQLite
-- (1 utilisateur = 0 ou 1 commerce ; les commerces seedés n'ont pas de
-- propriétaire).
CREATE TABLE shops (
  id               BIGSERIAL PRIMARY KEY,
  owner_id         BIGINT UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  description      TEXT,
  address          TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  google_place_id  TEXT,
  category         TEXT,
  image            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX shops_category_idx ON shops (category);

CREATE TRIGGER trg_shops_updated_at
  BEFORE UPDATE ON shops
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----------------------------------------------------------------------------
-- 4. products
-- ----------------------------------------------------------------------------
-- shop_id NOT NULL : un produit appartient obligatoirement à un commerce.
-- ON DELETE RESTRICT : la suppression d'un commerce avec produits doit
-- passer par une suppression explicite des produits au préalable (comme le
-- fait déjà deleteShopCascade côté Flutter) ; la contrainte agit comme un
-- filet de sécurité.
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

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----------------------------------------------------------------------------
-- 5. carts
-- ----------------------------------------------------------------------------
-- Un panier n'existe QUE rattaché à un utilisateur connecté (user_id NOT
-- NULL UNIQUE). Le panier visiteur reste entièrement côté Flutter et n'a
-- aucune représentation ici.
CREATE TABLE carts (
  id          BIGSERIAL PRIMARY KEY,
  user_id     BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_carts_updated_at
  BEFORE UPDATE ON carts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----------------------------------------------------------------------------
-- 6. cart_items
-- ----------------------------------------------------------------------------
-- ON DELETE CASCADE sur les deux FK (contrairement à order_items) : un
-- panier ne fige rien, nom/prix/stock sont relus depuis `products` à chaque
-- lecture. UNIQUE(cart_id, product_id) : un produit n'a qu'une seule ligne
-- par panier.
CREATE TABLE cart_items (
  id          BIGSERIAL PRIMARY KEY,
  cart_id     BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity    INTEGER NOT NULL CHECK (quantity > 0),
  UNIQUE (cart_id, product_id)
);

CREATE INDEX cart_items_cart_id_idx ON cart_items (cart_id);

-- ----------------------------------------------------------------------------
-- 7. orders
-- ----------------------------------------------------------------------------
-- user_id nullable (cohérence de modèle avec le SQLite d'origine).
-- payment_method : AUCUNE contrainte CHECK sur les valeurs possibles —
-- l'énumération exacte n'apparaît dans aucun fichier fourni. À trancher par
-- l'agent en charge du module Orders/Checkout.
-- status : reprend exactement les 7 valeurs de order_status.dart. Le statut
-- `cancelled` est conservé bien qu'aucun code fourni ne le déclenche
-- (aucune transition dans merchantTransitions) — signalé comme point ouvert,
-- non retiré ici par prudence.
CREATE TABLE orders (
  id              BIGSERIAL PRIMARY KEY,
  user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,
  total           NUMERIC(12,2) NOT NULL CHECK (total >= 0),
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','paid','preparing','ready','completed','cancelled','refunded')),
  payment_method  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX orders_status_idx ON orders (status);

CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ----------------------------------------------------------------------------
-- 8. order_items
-- ----------------------------------------------------------------------------
-- product_name / shop_name / price : snapshots figés à l'achat, jamais
-- recalculés (voir order_item.dart). product_id / shop_id passent à NULL
-- si le produit/commerce est supprimé ensuite (ON DELETE SET NULL), pour
-- que l'historique reste lisible.
-- order_id : ON DELETE CASCADE (SQLite ne le déclare pas explicitement,
-- mais aucune méthode ne supprime une commande dans le code fourni ; table
-- purement additive).
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
CREATE INDEX order_items_product_id_idx ON order_items (product_id);
CREATE INDEX order_items_shop_id_idx ON order_items (shop_id);
