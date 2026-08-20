/// Représente un produit vendu par un commerce.
class Product {
  final int? id;
  final int shopId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String category;
  final String image;
  final String? model3d;

  const Product({
    this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.image,
    this.model3d,
  });

  /// Construit un [Product] à partir du JSON renvoyé par le backend
  /// REST (`GET /products`, `GET /products/:id`,
  /// `GET /shops/:shopId/products`, réponses de `POST /products` et
  /// `PUT /products/:id` — voir `products.controller.ts`, fonction
  /// `toDto`).
  ///
  /// Contrairement à [Product.fromMap] (colonnes SQLite en
  /// snake_case), le contrat REST utilise des clés camelCase
  /// (`shopId`, `model3d`). `id`/`shopId` sont déjà des `number` JSON
  /// sûrs (voir `toSafeApiId` côté backend).
  factory Product.fromApiJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int?,
      shopId: json['shopId'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      image: json['image'] as String? ?? '',
      model3d: json['model3d'] as String?,
    );
  }

  /// Sérialise ce [Product] pour le corps JSON de `POST /products` /
  /// `PUT /products/:id` (voir `parseProductInput` côté backend).
  /// `id`/`shopId` ne sont volontairement jamais inclus : `id` est
  /// déduit de la route, `shopId` est déduit du commerce du vendeur
  /// authentifié (jamais fourni par le client, voir
  /// `createProductForOwner`).
  Map<String, dynamic> toApiJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'image': image,
      'model3d': model3d,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      shopId: map['shop_id'] as int,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      stock: map['stock'] as int? ?? 0,
      category: map['category'] as String? ?? '',
      image: map['image'] as String? ?? '',
      model3d: map['model_3d'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'category': category,
      'image': image,
      'model_3d': model3d,
    };
  }

  Product copyWith({
    int? id,
    int? shopId,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? category,
    String? image,
    String? model3d,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      image: image ?? this.image,
      model3d: model3d ?? this.model3d,
    );
  }
}