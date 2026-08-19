-- ============================================================================
-- seed.sql
-- Traduction fidèle de lib/database/seed_data.dart (5 commerces, 20 produits).
--
-- Aucune donnée inventée : noms, descriptions, prix, stocks, catégories et
-- chemins d'images/modèles sont repris à l'identique du seed Flutter.
--
-- Points signalés (non modifiés silencieusement, cf. consigne) :
--   - Les commerces seedés n'ont pas de propriétaire (owner_id NULL),
--     comme dans seed_data.dart.
--   - Aucun utilisateur n'est créé ici : seed_data.dart n'insère aucune
--     ligne dans `users`.
--   - latitude / longitude / google_place_id restent NULL pour tous les
--     commerces seedés : seed_data.dart ne renseigne que `address` (texte
--     libre), jamais de localisation structurée.
--   - Les catégories ('Mobilier', 'Décoration', 'Électronique', 'Mode',
--     'Artisanat') sont reprises telles quelles, sans les faire
--     correspondre à une éventuelle liste de catégories plus détaillée
--     utilisée ailleurs dans l'app Flutter (hors du périmètre de cet agent).
--   - Les chemins 'assets/images/...' et 'assets/models/...' sont des
--     assets Flutter embarqués, pas des fichiers uploadés : ils sont
--     conservés tels quels (aucune incompatibilité PostgreSQL détectée).
--
-- Ce script suppose schema.sql fraîchement exécuté (tables vides).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Commerces (owner_id NULL : aucun propriétaire, comme dans le seed Flutter)
-- ----------------------------------------------------------------------------
INSERT INTO shops (name, description, address, category, image) VALUES
  ('Maison & Bois',
   'Mobilier artisanal en bois massif, fabriqué localement avec des essences durables.',
   '12 Rue des Artisans, Antananarivo',
   'Mobilier',
   'assets/images/shop_maison_bois.jpg'),

  ('Déco Mada',
   'Objets de décoration et pièces uniques inspirées du savoir-faire malgache.',
   '5 Avenue de l''Indépendance, Antananarivo',
   'Décoration',
   'assets/images/shop_deco_mada.jpg'),

  ('Tech Corner',
   'Accessoires électroniques et gadgets pratiques pour la maison et le bureau.',
   '8 Rue du Commerce, Toamasina',
   'Électronique',
   'assets/images/shop_tech_corner.jpg'),

  ('Mode Urbaine',
   'Vêtements et accessoires tendances pour un style urbain et décontracté.',
   '21 Boulevard Central, Antsirabe',
   'Mode',
   'assets/images/shop_mode_urbaine.jpg'),

  ('Atelier Fianar',
   'Créations artisanales en raphia, bois et textiles tissés à la main.',
   '3 Rue de l''Artisanat, Fianarantsoa',
   'Artisanat',
   'assets/images/shop_atelier_fianar.jpg');

-- ----------------------------------------------------------------------------
-- Produits — Maison & Bois
-- ----------------------------------------------------------------------------
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Chaise en bois massif',
       'Chaise robuste en bois d''eucalyptus, finition huilée, assise confortable.',
       89000.00, 14, 'Mobilier', 'assets/images/product_chaise.jpg', 'assets/models/chair.glb'
FROM shops WHERE name = 'Maison & Bois';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Table basse ronde',
       'Table basse en bois de palissandre, plateau rond et pieds effilés.',
       245000.00, 6, 'Mobilier', 'assets/images/product_table.jpg', 'assets/models/table.glb'
FROM shops WHERE name = 'Maison & Bois';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Étagère murale 3 niveaux',
       'Étagère compacte en bois clair, idéale pour salon ou bureau.',
       76000.00, 9, 'Mobilier', 'assets/images/product_etagere.jpg', NULL
FROM shops WHERE name = 'Maison & Bois';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Banc en bois recyclé',
       'Banc deux places fabriqué à partir de bois de récupération, style brut.',
       132000.00, 4, 'Mobilier', 'assets/images/product_banc.jpg', NULL
FROM shops WHERE name = 'Maison & Bois';

-- ----------------------------------------------------------------------------
-- Produits — Déco Mada
-- ----------------------------------------------------------------------------
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Lampe suspendue en rotin',
       'Suspension artisanale en rotin tressé, diffuse une lumière douce et chaleureuse.',
       58000.00, 11, 'Décoration', 'assets/images/product_lampe.jpg', 'assets/models/lamp.glb'
FROM shops WHERE name = 'Déco Mada';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Vase en terre cuite',
       'Vase fait main, décor géométrique peint, parfait pour fleurs séchées.',
       32000.00, 20, 'Décoration', 'assets/images/product_vase.jpg', NULL
FROM shops WHERE name = 'Déco Mada';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Miroir cadre bambou',
       'Miroir rond encadré de bambou naturel, format moyen.',
       47500.00, 8, 'Décoration', 'assets/images/product_miroir.jpg', NULL
FROM shops WHERE name = 'Déco Mada';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Coussin brodé motifs locaux',
       'Coussin en coton brodé à la main avec des motifs traditionnels.',
       21000.00, 25, 'Décoration', 'assets/images/product_coussin.jpg', NULL
FROM shops WHERE name = 'Déco Mada';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Panier de rangement tressé',
       'Panier en fibres naturelles tressées, idéal pour le rangement décoratif.',
       27500.00, 17, 'Décoration', 'assets/images/product_panier.jpg', NULL
FROM shops WHERE name = 'Déco Mada';

-- ----------------------------------------------------------------------------
-- Produits — Tech Corner
-- ----------------------------------------------------------------------------
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Enceinte Bluetooth portable',
       'Enceinte compacte avec autonomie de 10 heures et son puissant.',
       98000.00, 15, 'Électronique', 'assets/images/product_enceinte.jpg', NULL
FROM shops WHERE name = 'Tech Corner';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Chargeur solaire portable',
       'Batterie externe avec panneau solaire intégré, idéale en déplacement.',
       64000.00, 12, 'Électronique', 'assets/images/product_chargeur.jpg', NULL
FROM shops WHERE name = 'Tech Corner';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Casque audio sans fil',
       'Casque circum-aural avec réduction de bruit passive et micro intégré.',
       145000.00, 7, 'Électronique', 'assets/images/product_casque.jpg', NULL
FROM shops WHERE name = 'Tech Corner';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Support téléphone ajustable',
       'Support de bureau réglable, compatible avec la plupart des smartphones.',
       15500.00, 30, 'Électronique', 'assets/images/product_support.jpg', NULL
FROM shops WHERE name = 'Tech Corner';

-- ----------------------------------------------------------------------------
-- Produits — Mode Urbaine
-- ----------------------------------------------------------------------------
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Veste en jean oversize',
       'Veste en denim coupe ample, doublure douce, style intemporel.',
       72000.00, 10, 'Mode', 'assets/images/product_veste.jpg', NULL
FROM shops WHERE name = 'Mode Urbaine';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Sneakers toile blanche',
       'Baskets légères en toile respirante, semelle confort.',
       68000.00, 18, 'Mode', 'assets/images/product_sneakers.jpg', NULL
FROM shops WHERE name = 'Mode Urbaine';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Sac à dos en toile',
       'Sac à dos résistant avec compartiment pour ordinateur portable.',
       54000.00, 13, 'Mode', 'assets/images/product_sac.jpg', NULL
FROM shops WHERE name = 'Mode Urbaine';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Casquette brodée',
       'Casquette ajustable en coton avec broderie discrète.',
       19000.00, 22, 'Mode', 'assets/images/product_casquette.jpg', NULL
FROM shops WHERE name = 'Mode Urbaine';

-- ----------------------------------------------------------------------------
-- Produits — Atelier Fianar
-- ----------------------------------------------------------------------------
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Chapeau en raphia',
       'Chapeau tissé main en raphia naturel, protection solaire et style estival.',
       26000.00, 16, 'Artisanat', 'assets/images/product_chapeau.jpg', NULL
FROM shops WHERE name = 'Atelier Fianar';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Sac cabas tissé',
       'Cabas en fibres végétales tressées, doublure intérieure en coton.',
       38000.00, 11, 'Artisanat', 'assets/images/product_cabas.jpg', NULL
FROM shops WHERE name = 'Atelier Fianar';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Set de sous-verres en bois',
       'Lot de 6 sous-verres gravés à la main, bois local verni.',
       18500.00, 24, 'Artisanat', 'assets/images/product_sousverre.jpg', NULL
FROM shops WHERE name = 'Atelier Fianar';

INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT id, 'Tapis tissé traditionnel',
       'Tapis fait main aux motifs traditionnels, tissage serré et durable.',
       115000.00, 5, 'Artisanat', 'assets/images/product_tapis.jpg', NULL
FROM shops WHERE name = 'Atelier Fianar';

COMMIT;
