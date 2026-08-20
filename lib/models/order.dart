class Order {
  final int? id;
  final double total;
  final String status;
  final String createdAt;
  final String? paymentMethod;

  /// Étape 4 : utilisateur ayant passé la commande. Nullable pour les
  /// commandes créées avant cette étape (voir migration v4 -> v5) :
  /// comme `shops.owner_id`, on ne leur invente pas de propriétaire.
  final int? userId;

  /// Nombre total d'articles de la commande. Présent uniquement sur
  /// les réponses REST qui l'agrègent côté backend (`GET /orders` —
  /// voir `orders.mapper.ts`, `orderDto`, champ `itemCount`
  /// optionnel) ; `null` sinon (ex : `Order.fromMap`, réponse de
  /// `POST /orders/checkout`).
  final int? itemCount;

  /// Nombre d'articles concernant spécifiquement le commerce du
  /// vendeur authentifié. Présent uniquement sur
  /// `GET /orders/shop` (champ `shopItemCount` optionnel de
  /// `orderDto`) ; `null` sinon.
  final int? shopItemCount;

  /// Sous-total (prix × quantité) concernant spécifiquement le
  /// commerce du vendeur authentifié. Présent uniquement sur
  /// `GET /orders/shop` (champ `shopTotal` optionnel de `orderDto`) ;
  /// `null` sinon.
  final double? shopTotal;

  const Order({
    this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    this.paymentMethod,
    this.userId,
    this.itemCount,
    this.shopItemCount,
    this.shopTotal,
  });

  /// Construit un [Order] à partir du JSON renvoyé par le backend
  /// REST (`orderDto`, voir `orders.mapper.ts`) : utilisé par
  /// `POST /orders/checkout`, `GET /orders`, `GET /orders/shop`,
  /// `GET /orders/:id`, `PATCH /orders/:id/status`,
  /// `POST /orders/:id/refund`, ainsi que
  /// `GET /shops/:id/blocking-orders` et
  /// `GET /products/:id/blocking-orders` (même DTO, voir
  /// `migration_plan.md` §9).
  ///
  /// Contrairement à [Order.fromMap] (colonnes SQLite en snake_case),
  /// le contrat REST utilise des clés camelCase. `id`/`userId` sont
  /// déjà des `number` JSON sûrs (voir `toSafeApiId` côté backend).
  factory Order.fromApiJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String?,
      userId: json['userId'] as int?,
      itemCount: json['itemCount'] as int?,
      shopItemCount: json['shopItemCount'] as int?,
      shopTotal: (json['shopTotal'] as num?)?.toDouble(),
    );
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      paymentMethod: map['payment_method'] as String?,
      userId: map['user_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'total': total,
      'status': status,
      'created_at': createdAt,
      'payment_method': paymentMethod,
      if (userId != null) 'user_id': userId,
    };
  }

  Order copyWith({
    int? id,
    double? total,
    String? status,
    String? createdAt,
    String? paymentMethod,
    int? userId,
  }) {
    return Order(
      id: id ?? this.id,
      total: total ?? this.total,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      userId: userId ?? this.userId,
    );
  }
}