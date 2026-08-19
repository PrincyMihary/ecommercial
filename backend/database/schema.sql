-- Schéma PostgreSQL cible pour "ecommercial".
-- Traduction directe du schéma SQLite réel (marketplace.db, version 7),
-- voir migration_plan.md §4-6 pour la justification de chaque écart.
--
-- Contexte dev local (§17) : ce script est destiné à être ré-exécuté
-- librement sur une base de développement -> DROP TABLE en tête.

DROP TABLE IF EXISTS order_items, orders, cart_items, carts, products, shops, users CASCADE;

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id             BIGSERIAL PRIMARY KEY,
  full_name      TEXT NOT NULL,
  email          CITEXT NOT NULL UNIQUE,
  phone          TEXT,
  password_hash  TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Note : pas de colonne password_salt séparée en PostgreSQL — bcrypt
-- embarque le sel dans le hash lui-même (voir §10).

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
-- autorisés).

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
