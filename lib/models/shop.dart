/// Représente un commerce (vendeur) de la marketplace.
class Shop {
  final int? id;
  final String name;
  final String description;

  /// Adresse physique lisible du commerce (texte destiné à
  /// l'utilisateur). `null`/vide pour un commerce non physique.
  final String? address;

  /// Position géographique réelle du commerce, issue d'une sélection
  /// Google Places. `null` si aucun emplacement n'a été sélectionné
  /// (commerce virtuel, ou ancien commerce jamais migré).
  final double? latitude;
  final double? longitude;

  /// Identifiant précis du lieu Google sélectionné. `null` dans les
  /// mêmes cas que latitude/longitude.
  ///
  /// Volontairement indépendant de tout SDK Google : simple String,
  /// jamais un objet Google Places brut n'est stocké ici.
  final String? googlePlaceId;

  final String category;
  final String image;
  final int? ownerId;

  const Shop({
    this.id,
    required this.name,
    required this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    required this.category,
    required this.image,
    this.ownerId,
  });

  /// Construit un [Shop] à partir du JSON renvoyé par le backend REST
  /// (`GET /shops`, `GET /shops/:id`, `GET /shops/me`, réponses de
  /// `POST /shops` et `PUT /shops/:id` — voir `shops.controller.ts`,
  /// fonction `toDto`).
  ///
  /// Contrairement à [Shop.fromMap] (colonnes SQLite en snake_case),
  /// le contrat REST utilise des clés camelCase (`ownerId`,
  /// `googlePlaceId`). `id`/`ownerId` sont déjà des `number` JSON sûrs
  /// (voir `toSafeApiId` côté backend) : aucune conversion
  /// supplémentaire n'est nécessaire ni souhaitable ici.
  factory Shop.fromApiJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      googlePlaceId: json['googlePlaceId'] as String?,
      category: json['category'] as String? ?? '',
      image: json['image'] as String? ?? '',
      ownerId: json['ownerId'] as int?,
    );
  }

  /// Sérialise ce [Shop] pour le corps JSON de `POST /shops` /
  /// `PUT /shops/:id` (voir `parseShopInput` côté backend). `id` et
  /// `ownerId` ne sont volontairement jamais inclus : ce sont des
  /// champs déduits côté serveur (route/token), jamais fournis par le
  /// client.
  Map<String, dynamic> toApiJson() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'googlePlaceId': googlePlaceId,
      'category': category,
      'image': image,
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      address: map['address'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      googlePlaceId: map['google_place_id'] as String?,
      category: map['category'] as String? ?? '',
      image: map['image'] as String? ?? '',
      ownerId: map['owner_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'google_place_id': googlePlaceId,
      'category': category,
      'image': image,
      if (ownerId != null) 'owner_id': ownerId,
    };
  }

  /// `true` si le commerce a une adresse physique renseignée.
  bool get hasAddress => address != null && address!.trim().isNotEmpty;

  /// `true` si le commerce possède une localisation structurée
  /// (Place ID et/ou coordonnées) permettant d'ouvrir Google Maps.
  /// Un ancien commerce avec seulement `address` (texte libre, jamais
  /// géocodé automatiquement) retourne `false` ici.
  bool get hasStructuredLocation =>
      (googlePlaceId != null && googlePlaceId!.trim().isNotEmpty) ||
          (latitude != null && longitude != null);

  Shop copyWith({
    int? id,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    String? googlePlaceId,
    String? category,
    String? image,
    int? ownerId,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      category: category ?? this.category,
      image: image ?? this.image,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}