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