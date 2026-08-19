import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import 'checkout_screen.dart';
import 'order_list_screen.dart';
import 'login_screen.dart';
/// Écran "Panier" (onglet dédié).
///
/// S'abonne à [CartService] pour se reconstruire automatiquement à
/// chaque changement (ajout, quantité, suppression).
///
/// Le bouton "Passer la commande" n'appelle plus directement
/// `DatabaseHelper.createOrder` : il ouvre désormais [CheckoutScreen],
/// qui orchestre le paiement mocké puis la création réelle de la
/// commande. Cet écran garde uniquement l'accès à l'historique
/// ("Mes commandes"), placé ici plutôt que dans "Profil" (voir
/// explication de ce choix dans la réponse accompagnant ce fichier).
class CartScreen extends StatefulWidget {
  final VoidCallback onGoToHome;

  const CartScreen({
    super.key,
    required this.onGoToHome,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _goToCheckout() {
    final cart = CartService.instance;
    if (cart.isEmpty) return;
    // Étape 5 : le checkout nécessite un userId réel côté DB — un
    // visiteur est redirigé vers la connexion plutôt que de tenter
    // un checkout qui échouerait de toute façon.
    if (!AuthService.instance.isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }
  void _goToOrderHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderListScreen()),
    );
  }

  String _formatPrice(double price) {
    final rounded = price.round();
    final asString = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < asString.length; i++) {
      final positionFromEnd = asString.length - i;
      buffer.write(asString[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${buffer.toString()} Ar';
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final items = cart.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: [
          IconButton(
            tooltip: 'Mes commandes',
            onPressed: _goToOrderHistory,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: items.isEmpty ? _buildEmptyState() : _buildCartBody(items, cart),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Votre panier est vide.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ajoutez des produits depuis l'accueil ou la recherche.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onGoToHome,
              child: const Text('Retour aux produits'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goToOrderHistory,
              child: const Text('Voir mes commandes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBody(List<CartItem> items, CartService cart) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _CartItemTile(
                item: item,
                onIncrease: () => cart.increaseQuantity(item.productId),
                onDecrease: () => cart.decreaseQuantity(item.productId),
                onRemove: () => cart.removeProduct(item.productId),
                formatPrice: _formatPrice,
              );
            },
          ),
        ),
        _buildSummary(cart),
      ],
    );
  }

  Widget _buildSummary(CartService cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatPrice(cart.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _goToCheckout,
              child: const Text('Passer la commande'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final String Function(double) formatPrice;

  const _CartItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            path: item.image,
            width: 64,
            height: 64,
            borderRadius: BorderRadius.circular(12),
            fallbackIcon: Icons.shopping_bag_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPrice(item.price),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyButton(icon: Icons.remove, onPressed: onDecrease),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onPressed: item.quantity >= item.stock ? null : onIncrease,
                    ),
                    const Spacer(),
                    Text(
                      formatPrice(item.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onPressed == null ? AppColors.border : AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}