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

  const Order({
    this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    this.paymentMethod,
    this.userId,
  });

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