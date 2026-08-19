/// Représente une ligne du panier.
class CartItem {
  final int productId;
  final String productName;
  final double price;
  final String image;
  final int quantity;

  /// Stock du produit connu au moment de l'ajout au panier. Sert à
  /// plafonner les augmentations de quantité côté [CartService] sans
  /// requêter SQLite à chaque interaction.
  final int stock;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.image,
    required this.quantity,
    required this.stock,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['product_id'] as int,
      productName: map['product_name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      image: map['image'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 1,
      stock: map['stock'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'image': image,
      'quantity': quantity,
      'stock': stock,
    };
  }

  double get total => price * quantity;

  CartItem copyWith({
    int? productId,
    String? productName,
    double? price,
    String? image,
    int? quantity,
    int? stock,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
    );
  }
}