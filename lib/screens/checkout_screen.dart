import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_image.dart';
import 'login_screen.dart';
import 'order_confirmation_screen.dart';
import 'payment_method_screen.dart';

/// Écran "Checkout" : résumé en lecture seule du panier avant
/// paiement.
///
/// Étape 5 : `DatabaseHelper.createOrder` exige désormais un `userId`
/// non nul et relit lui-même le panier PERSISTÉ de cet utilisateur en
/// SQLite — jamais une liste transmise par cet écran. Le checkout
/// nécessite donc explicitement une session ; un visiteur (ou un
/// utilisateur déconnecté entre-temps) est bloqué avec une invitation
/// à se connecter plutôt que de risquer une commande sans propriétaire.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;

  Future<void> _startPayment() async {
    final cart = CartService.instance;
    final userId = AuthService.instance.currentUser?.id;
    if (cart.isEmpty || _isProcessing || userId == null) return;

    final totalAmount = cart.totalAmount;

    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(totalAmount: totalAmount),
      ),
    );

    if (result == null || !mounted) return; // paiement annulé

    await _finalizeOrder(userId, result);
  }

  Future<void> _finalizeOrder(int userId, PaymentResult payment) async {
    setState(() => _isProcessing = true);

    try {
      // Le panier lu ici est celui de `userId`, résolu par
      // DatabaseHelper directement en SQLite — jamais une liste
      // passée par cet écran.
      final orderId = await DatabaseHelper.instance.createOrder(
        userId: userId,
        paymentMethod: payment.methodId,
      );
      await DatabaseHelper.instance.markOrderAsPaid(orderId);

      // cart_items a déjà été vidé dans la transaction de
      // createOrder : on ne fait ici que resynchroniser l'état
      // mémoire, sans repasser par SQLite.
      CartService.instance.clearLocalAfterCheckout();

      if (!mounted) return;

      final order = await DatabaseHelper.instance.getOrderById(orderId);
      final total = (order?['total'] as num?)?.toDouble() ?? 0.0;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            total: total,
            paymentMethodLabel: payment.methodLabel,
          ),
        ),
      );
    } on OrderException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la finalisation de la commande : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final items = cart.items;
    final isGuest = !AuthService.instance.isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: isGuest
          ? _buildGuestBlock()
          : items.isEmpty
          ? const Center(child: Text('Votre panier est vide.'))
          : Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _SummaryTile(item: items[index]),
            ),
          ),
          _buildFooter(cart),
        ],
      ),
    );
  }

  Widget _buildGuestBlock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Connectez-vous pour finaliser votre commande.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(CartService cart) {
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
                  'Total à payer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  formatPriceAr(cart.totalAmount),
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
              onPressed: _isProcessing ? null : _startPayment,
              child: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Choisir le moyen de paiement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final CartItem item;

  const _SummaryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AppImage(
            path: item.image,
            width: 56,
            height: 56,
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
                  'x${item.quantity} · ${formatPriceAr(item.price)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            formatPriceAr(item.total),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark),
          ),
        ],
      ),
    );
  }
}