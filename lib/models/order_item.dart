/// Représente une ligne de commande (historique).
///
/// [productName]/[price] sont figés au moment de l'achat et ne sont
/// JAMAIS recalculés depuis le produit actuel. Étape 4 : [shopId] et
/// [shopName] sont eux aussi figés au moment de l'achat (même
/// philosophie), pour que l'attribution "cette ligne appartient à ce
/// commerce" survive à la suppression ultérieure du produit ou du
/// commerce.
///
/// [productId] et [shopId] deviennent nullable (Étape 4) : la
/// suppression d'un produit met `product_id` à NULL
/// (`ON DELETE SET NULL`, voir migration v4 -> v5) plutôt que
/// d'échouer avec une erreur de contrainte FK opaque.
class OrderItem {
  final int? id;
  final int orderId;
  final int? productId;
  final String productName;
  final int quantity;
  final double price;
  final int? shopId;
  final String? shopName;

  const OrderItem({
    this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.shopId,
    this.shopName,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String? ?? 'Produit',
      quantity: map['quantity'] as int? ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      shopId: map['shop_id'] as int?,
      shopName: map['shop_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'shop_id': shopId,
      'shop_name': shopName,
    };
  }
}