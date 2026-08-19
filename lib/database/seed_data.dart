import 'package:sqflite/sqflite.dart';

/// Données de démonstration insérées au premier lancement uniquement.
///
/// Objectif : garantir que l'application n'est jamais vide, avec des
/// données réalistes pour une marketplace locale (commerces, produits).
class SeedData {
  SeedData._();

  static Future<void> insertSeed(Database db) async {
    await db.transaction((txn) async {
      final shopIds = await _insertShops(txn);
      await _insertProducts(txn, shopIds);
    });
  }

  static Future<Map<String, int>> _insertShops(Transaction txn) async {
    final shops = <Map<String, dynamic>>[
      {
        'name': 'Maison & Bois',
        'description':
            'Mobilier artisanal en bois massif, fabriqué localement avec des essences durables.',
        'address': '12 Rue des Artisans, Antananarivo',
        'category': 'Mobilier',
        'image': 'assets/images/shop_maison_bois.jpg',
      },
      {
        'name': 'Déco Mada',
        'description':
            'Objets de décoration et pièces uniques inspirées du savoir-faire malgache.',
        'address': '5 Avenue de l\'Indépendance, Antananarivo',
        'category': 'Décoration',
        'image': 'assets/images/shop_deco_mada.jpg',
      },
      {
        'name': 'Tech Corner',
        'description':
            'Accessoires électroniques et gadgets pratiques pour la maison et le bureau.',
        'address': '8 Rue du Commerce, Toamasina',
        'category': 'Électronique',
        'image': 'assets/images/shop_tech_corner.jpg',
      },
      {
        'name': 'Mode Urbaine',
        'description':
            'Vêtements et accessoires tendances pour un style urbain et décontracté.',
        'address': '21 Boulevard Central, Antsirabe',
        'category': 'Mode',
        'image': 'assets/images/shop_mode_urbaine.jpg',
      },
      {
        'name': 'Atelier Fianar',
        'description':
            'Créations artisanales en raphia, bois et textiles tissés à la main.',
        'address': '3 Rue de l\'Artisanat, Fianarantsoa',
        'category': 'Artisanat',
        'image': 'assets/images/shop_atelier_fianar.jpg',
      },
    ];

    final ids = <String, int>{};
    for (final shop in shops) {
      final id = await txn.insert('shops', shop);
      ids[shop['name'] as String] = id;
    }
    return ids;
  }

  static Future<void> _insertProducts(
    Transaction txn,
    Map<String, int> shopIds,
  ) async {
    final maisonBois = shopIds['Maison & Bois']!;
    final decoMada = shopIds['Déco Mada']!;
    final techCorner = shopIds['Tech Corner']!;
    final modeUrbaine = shopIds['Mode Urbaine']!;
    final atelierFianar = shopIds['Atelier Fianar']!;

    final products = <Map<String, dynamic>>[
      // Maison & Bois
      {
        'shop_id': maisonBois,
        'name': 'Chaise en bois massif',
        'description':
            'Chaise robuste en bois d\'eucalyptus, finition huilée, assise confortable.',
        'price': 89000.0,
        'stock': 14,
        'category': 'Mobilier',
        'image': 'assets/images/product_chaise.jpg',
        'model_3d': 'assets/models/chair.glb',
      },
      {
        'shop_id': maisonBois,
        'name': 'Table basse ronde',
        'description':
            'Table basse en bois de palissandre, plateau rond et pieds effilés.',
        'price': 245000.0,
        'stock': 6,
        'category': 'Mobilier',
        'image': 'assets/images/product_table.jpg',
        'model_3d': 'assets/models/table.glb',
      },
      {
        'shop_id': maisonBois,
        'name': 'Étagère murale 3 niveaux',
        'description':
            'Étagère compacte en bois clair, idéale pour salon ou bureau.',
        'price': 76000.0,
        'stock': 9,
        'category': 'Mobilier',
        'image': 'assets/images/product_etagere.jpg',
        'model_3d': null,
      },
      {
        'shop_id': maisonBois,
        'name': 'Banc en bois recyclé',
        'description':
            'Banc deux places fabriqué à partir de bois de récupération, style brut.',
        'price': 132000.0,
        'stock': 4,
        'category': 'Mobilier',
        'image': 'assets/images/product_banc.jpg',
        'model_3d': null,
      },

      // Déco Mada
      {
        'shop_id': decoMada,
        'name': 'Lampe suspendue en rotin',
        'description':
            'Suspension artisanale en rotin tressé, diffuse une lumière douce et chaleureuse.',
        'price': 58000.0,
        'stock': 11,
        'category': 'Décoration',
        'image': 'assets/images/product_lampe.jpg',
        'model_3d': 'assets/models/lamp.glb',
      },
      {
        'shop_id': decoMada,
        'name': 'Vase en terre cuite',
        'description':
            'Vase fait main, décor géométrique peint, parfait pour fleurs séchées.',
        'price': 32000.0,
        'stock': 20,
        'category': 'Décoration',
        'image': 'assets/images/product_vase.jpg',
        'model_3d': null,
      },
      {
        'shop_id': decoMada,
        'name': 'Miroir cadre bambou',
        'description':
            'Miroir rond encadré de bambou naturel, format moyen.',
        'price': 47500.0,
        'stock': 8,
        'category': 'Décoration',
        'image': 'assets/images/product_miroir.jpg',
        'model_3d': null,
      },
      {
        'shop_id': decoMada,
        'name': 'Coussin brodé motifs locaux',
        'description':
            'Coussin en coton brodé à la main avec des motifs traditionnels.',
        'price': 21000.0,
        'stock': 25,
        'category': 'Décoration',
        'image': 'assets/images/product_coussin.jpg',
        'model_3d': null,
      },
      {
        'shop_id': decoMada,
        'name': 'Panier de rangement tressé',
        'description':
            'Panier en fibres naturelles tressées, idéal pour le rangement décoratif.',
        'price': 27500.0,
        'stock': 17,
        'category': 'Décoration',
        'image': 'assets/images/product_panier.jpg',
        'model_3d': null,
      },

      // Tech Corner
      {
        'shop_id': techCorner,
        'name': 'Enceinte Bluetooth portable',
        'description':
            'Enceinte compacte avec autonomie de 10 heures et son puissant.',
        'price': 98000.0,
        'stock': 15,
        'category': 'Électronique',
        'image': 'assets/images/product_enceinte.jpg',
        'model_3d': null,
      },
      {
        'shop_id': techCorner,
        'name': 'Chargeur solaire portable',
        'description':
            'Batterie externe avec panneau solaire intégré, idéale en déplacement.',
        'price': 64000.0,
        'stock': 12,
        'category': 'Électronique',
        'image': 'assets/images/product_chargeur.jpg',
        'model_3d': null,
      },
      {
        'shop_id': techCorner,
        'name': 'Casque audio sans fil',
        'description':
            'Casque circum-aural avec réduction de bruit passive et micro intégré.',
        'price': 145000.0,
        'stock': 7,
        'category': 'Électronique',
        'image': 'assets/images/product_casque.jpg',
        'model_3d': null,
      },
      {
        'shop_id': techCorner,
        'name': 'Support téléphone ajustable',
        'description':
            'Support de bureau réglable, compatible avec la plupart des smartphones.',
        'price': 15500.0,
        'stock': 30,
        'category': 'Électronique',
        'image': 'assets/images/product_support.jpg',
        'model_3d': null,
      },

      // Mode Urbaine
      {
        'shop_id': modeUrbaine,
        'name': 'Veste en jean oversize',
        'description':
            'Veste en denim coupe ample, doublure douce, style intemporel.',
        'price': 72000.0,
        'stock': 10,
        'category': 'Mode',
        'image': 'assets/images/product_veste.jpg',
        'model_3d': null,
      },
      {
        'shop_id': modeUrbaine,
        'name': 'Sneakers toile blanche',
        'description':
            'Baskets légères en toile respirante, semelle confort.',
        'price': 68000.0,
        'stock': 18,
        'category': 'Mode',
        'image': 'assets/images/product_sneakers.jpg',
        'model_3d': null,
      },
      {
        'shop_id': modeUrbaine,
        'name': 'Sac à dos en toile',
        'description':
            'Sac à dos résistant avec compartiment pour ordinateur portable.',
        'price': 54000.0,
        'stock': 13,
        'category': 'Mode',
        'image': 'assets/images/product_sac.jpg',
        'model_3d': null,
      },
      {
        'shop_id': modeUrbaine,
        'name': 'Casquette brodée',
        'description':
            'Casquette ajustable en coton avec broderie discrète.',
        'price': 19000.0,
        'stock': 22,
        'category': 'Mode',
        'image': 'assets/images/product_casquette.jpg',
        'model_3d': null,
      },

      // Atelier Fianar
      {
        'shop_id': atelierFianar,
        'name': 'Chapeau en raphia',
        'description':
            'Chapeau tissé main en raphia naturel, protection solaire et style estival.',
        'price': 26000.0,
        'stock': 16,
        'category': 'Artisanat',
        'image': 'assets/images/product_chapeau.jpg',
        'model_3d': null,
      },
      {
        'shop_id': atelierFianar,
        'name': 'Sac cabas tissé',
        'description':
            'Cabas en fibres végétales tressées, doublure intérieure en coton.',
        'price': 38000.0,
        'stock': 11,
        'category': 'Artisanat',
        'image': 'assets/images/product_cabas.jpg',
        'model_3d': null,
      },
      {
        'shop_id': atelierFianar,
        'name': 'Set de sous-verres en bois',
        'description':
            'Lot de 6 sous-verres gravés à la main, bois local verni.',
        'price': 18500.0,
        'stock': 24,
        'category': 'Artisanat',
        'image': 'assets/images/product_sousverre.jpg',
        'model_3d': null,
      },
      {
        'shop_id': atelierFianar,
        'name': 'Tapis tissé traditionnel',
        'description':
            'Tapis fait main aux motifs traditionnels, tissage serré et durable.',
        'price': 115000.0,
        'stock': 5,
        'category': 'Artisanat',
        'image': 'assets/images/product_tapis.jpg',
        'model_3d': null,
      },
    ];

    for (final product in products) {
      await txn.insert('products', product);
    }
  }
}
