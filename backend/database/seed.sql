-- Traduction directe de lib/database/seed_data.dart (5 commerces, 20 produits).
-- Tous les commerces sont créés sans propriétaire (owner_id NULL), comme
-- dans le seed Flutter/SQLite d'origine (voir migration_plan.md §7).
-- Aucun utilisateur n'est créé par ce seed.

BEGIN;

WITH ins_shops AS (
  INSERT INTO shops (name, description, address, category, image) VALUES
    ('Maison & Bois', 'Mobilier artisanal en bois massif, fabriqué localement avec des essences durables.', '12 Rue des Artisans, Antananarivo', 'Mobilier', 'assets/images/shop_maison_bois.jpg'),
    ('Déco Mada', 'Objets de décoration et pièces uniques inspirées du savoir-faire malgache.', E'5 Avenue de l\'Indépendance, Antananarivo', 'Décoration', 'assets/images/shop_deco_mada.jpg'),
    ('Tech Corner', 'Accessoires électroniques et gadgets pratiques pour la maison et le bureau.', '8 Rue du Commerce, Toamasina', 'Électronique', 'assets/images/shop_tech_corner.jpg'),
    ('Mode Urbaine', 'Vêtements et accessoires tendances pour un style urbain et décontracté.', '21 Boulevard Central, Antsirabe', 'Mode', 'assets/images/shop_mode_urbaine.jpg'),
    ('Atelier Fianar', 'Créations artisanales en raphia, bois et textiles tissés à la main.', E'3 Rue de l\'Artisanat, Fianarantsoa', 'Artisanat', 'assets/images/shop_atelier_fianar.jpg')
  RETURNING id, name
)
INSERT INTO products (shop_id, name, description, price, stock, category, image, model_3d)
SELECT s.id, p.name, p.description, p.price, p.stock, p.category, p.image, p.model_3d
FROM ins_shops s
JOIN (VALUES
  -- Maison & Bois
  ('Maison & Bois', 'Chaise en bois massif', 'Chaise robuste en bois d''eucalyptus, finition huilée, assise confortable.', 89000.0, 14, 'Mobilier', 'assets/images/product_chaise.jpg', 'assets/models/chair.glb'),
  ('Maison & Bois', 'Table basse ronde', 'Table basse en bois de palissandre, plateau rond et pieds effilés.', 245000.0, 6, 'Mobilier', 'assets/images/product_table.jpg', 'assets/models/table.glb'),
  ('Maison & Bois', 'Étagère murale 3 niveaux', 'Étagère compacte en bois clair, idéale pour salon ou bureau.', 76000.0, 9, 'Mobilier', 'assets/images/product_etagere.jpg', NULL),
  ('Maison & Bois', 'Banc en bois recyclé', 'Banc deux places fabriqué à partir de bois de récupération, style brut.', 132000.0, 4, 'Mobilier', 'assets/images/product_banc.jpg', NULL),
  -- Déco Mada
  ('Déco Mada', 'Lampe suspendue en rotin', 'Suspension artisanale en rotin tressé, diffuse une lumière douce et chaleureuse.', 58000.0, 11, 'Décoration', 'assets/images/product_lampe.jpg', 'assets/models/lamp.glb'),
  ('Déco Mada', 'Vase en terre cuite', 'Vase fait main, décor géométrique peint, parfait pour fleurs séchées.', 32000.0, 20, 'Décoration', 'assets/images/product_vase.jpg', NULL),
  ('Déco Mada', 'Miroir cadre bambou', 'Miroir rond encadré de bambou naturel, format moyen.', 47500.0, 8, 'Décoration', 'assets/images/product_miroir.jpg', NULL),
  ('Déco Mada', 'Coussin brodé motifs locaux', 'Coussin en coton brodé à la main avec des motifs traditionnels.', 21000.0, 25, 'Décoration', 'assets/images/product_coussin.jpg', NULL),
  ('Déco Mada', 'Panier de rangement tressé', 'Panier en fibres naturelles tressées, idéal pour le rangement décoratif.', 27500.0, 17, 'Décoration', 'assets/images/product_panier.jpg', NULL),
  -- Tech Corner
  ('Tech Corner', 'Enceinte Bluetooth portable', 'Enceinte compacte avec autonomie de 10 heures et son puissant.', 98000.0, 15, 'Électronique', 'assets/images/product_enceinte.jpg', NULL),
  ('Tech Corner', 'Chargeur solaire portable', 'Batterie externe avec panneau solaire intégré, idéale en déplacement.', 64000.0, 12, 'Électronique', 'assets/images/product_chargeur.jpg', NULL),
  ('Tech Corner', 'Casque audio sans fil', 'Casque circum-aural avec réduction de bruit passive et micro intégré.', 145000.0, 7, 'Électronique', 'assets/images/product_casque.jpg', NULL),
  ('Tech Corner', 'Support téléphone ajustable', 'Support de bureau réglable, compatible avec la plupart des smartphones.', 15500.0, 30, 'Électronique', 'assets/images/product_support.jpg', NULL),
  -- Mode Urbaine
  ('Mode Urbaine', 'Veste en jean oversize', 'Veste en denim coupe ample, doublure douce, style intemporel.', 72000.0, 10, 'Mode', 'assets/images/product_veste.jpg', NULL),
  ('Mode Urbaine', 'Sneakers toile blanche', 'Baskets légères en toile respirante, semelle confort.', 68000.0, 18, 'Mode', 'assets/images/product_sneakers.jpg', NULL),
  ('Mode Urbaine', 'Sac à dos en toile', 'Sac à dos résistant avec compartiment pour ordinateur portable.', 54000.0, 13, 'Mode', 'assets/images/product_sac.jpg', NULL),
  ('Mode Urbaine', 'Casquette brodée', 'Casquette ajustable en coton avec broderie discrète.', 19000.0, 22, 'Mode', 'assets/images/product_casquette.jpg', NULL),
  -- Atelier Fianar
  ('Atelier Fianar', 'Chapeau en raphia', 'Chapeau tissé main en raphia naturel, protection solaire et style estival.', 26000.0, 16, 'Artisanat', 'assets/images/product_chapeau.jpg', NULL),
  ('Atelier Fianar', 'Sac cabas tissé', 'Cabas en fibres végétales tressées, doublure intérieure en coton.', 38000.0, 11, 'Artisanat', 'assets/images/product_cabas.jpg', NULL),
  ('Atelier Fianar', 'Set de sous-verres en bois', 'Lot de 6 sous-verres gravés à la main, bois local verni.', 18500.0, 24, 'Artisanat', 'assets/images/product_sousverre.jpg', NULL),
  ('Atelier Fianar', 'Tapis tissé traditionnel', 'Tapis fait main aux motifs traditionnels, tissage serré et durable.', 115000.0, 5, 'Artisanat', 'assets/images/product_tapis.jpg', NULL)
) AS p(shop_name, name, description, price, stock, category, image, model_3d)
  ON p.shop_name = s.name;

COMMIT;
