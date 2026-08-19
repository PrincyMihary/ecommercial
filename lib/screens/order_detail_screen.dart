import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../services/auth_service.dart';
import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class _OrderDetailData {
  final Order order;
  final List<OrderItem> allItems;
  final int? myShopId;
  final bool isBuyer;

  const _OrderDetailData({
    required this.order,
    required this.allItems,
    required this.myShopId,
    required this.isBuyer,
  });

  List<OrderItem> get myShopItems =>
      myShopId == null ? const [] : allItems.where((i) => i.shopId == myShopId).toList();

  bool get isMerchantHere => myShopItems.isNotEmpty;

  bool get hasAccess => isBuyer || isMerchantHere;

  double get myShopTotal =>
      myShopItems.fold(0.0, (sum, item) => sum + item.subtotal);
}

/// Détail d'une commande.
///
/// Étape 4 : deux vues possibles, jamais mélangées :
/// - CLIENT (acheteur) : toutes les lignes, total complet — inchangé.
/// - COMMERÇANT (au moins une ligne de son commerce dans cette
///   commande) : uniquement SES lignes, son sous-total, et des
///   actions de gestion (avancer le statut, rembourser). Si le
///   commerçant n'est PAS l'acheteur, il ne voit QUE sa portion (pas
///   les lignes des autres commerces, pas le total global).
/// Un utilisateur qui n'est ni l'acheteur ni concerné en tant que
/// commerçant (y compris un visiteur) n'a accès à rien.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<_OrderDetailData?> _future;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OrderDetailData?> _load() async {
    final db = DatabaseHelper.instance;
    final orderMap = await db.getOrderById(widget.orderId);
    if (orderMap == null) return null;

    final order = Order.fromMap(orderMap);
    final itemMaps = await db.getOrderItems(widget.orderId);
    final allItems = itemMaps.map(OrderItem.fromMap).toList();

    final currentUserId = AuthService.instance.currentUser?.id;
    int? myShopId;
    if (currentUserId != null) {
      final myShop = await db.getShopByOwnerId(currentUserId);
      myShopId = myShop?['id'] as int?;
    }
    final isBuyer = currentUserId != null &&
        order.userId != null &&
        order.userId == currentUserId;

    return _OrderDetailData(
      order: order,
      allItems: allItems,
      myShopId: myShopId,
      isBuyer: isBuyer,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
  }

  Future<void> _changeStatus(String newStatus) async {
    final user = AuthService.instance.currentUser;
    if (user == null || _isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(
          'Faire passer cette commande au statut "${OrderStatus.label(newStatus)}" ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await DatabaseHelper.instance.advanceOrderStatusForShop(
        user.id,
        widget.orderId,
        newStatus,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _refund(Order order) async {
    final user = AuthService.instance.currentUser;
    if (user == null || _isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rembourser cette commande ?'),
        content: const Text(
          'Un remboursement mocké va être simulé, puis la commande '
              'passera au statut "Remboursée". Le stock de vos produits '
              'concernés sera réapprovisionné.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rembourser', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      // Réutilise le système de paiement mocké existant (symétrique
      // de MockPaymentService.pay), pas un nouveau système.
      await MockPaymentService.refund(
        methodId: order.paymentMethod ?? '',
        detail: 'Remboursement commande #${order.id}',
      );
      await DatabaseHelper.instance.refundOrderForShop(user.id, widget.orderId);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remboursement effectué.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.orderId}')),
      body: FutureBuilder<_OrderDetailData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Cette commande est introuvable.'));
          }
          if (!data.hasAccess) {
            return const _AccessDeniedState();
          }

          return AbsorbPointer(
            absorbing: _isUpdating,
            child: _buildContent(data),
          );
        },
      ),
    );
  }

  Widget _buildContent(_OrderDetailData data) {
    final order = data.order;
    // Vue client complète si acheteur ; sinon vue commerçant limitée
    // à ses propres lignes (voir C. dans l'énoncé : "voir un produit"
    // ≠ "gérer un produit" — ici, "faire partie de la commande" ≠
    // "voir toute la commande").
    final displayItems = data.isBuyer ? data.allItems : data.myShopItems;
    final displayTotal = data.isBuyer ? order.total : data.myShopTotal;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Commande #${order.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            _StatusPill(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(formatOrderDateTime(order.createdAt), style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        if (order.status == OrderStatus.cancelled || order.status == OrderStatus.refunded)
          _TerminalBanner(status: order.status)
        else
          _ProgressTracker(status: order.status),
        const SizedBox(height: 24),
        if (!data.isBuyer && data.isMerchantHere)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Vous voyez uniquement les produits de votre commerce dans cette commande.',
              style: TextStyle(fontSize: 12, color: AppColors.accentDark),
            ),
          ),
        Text(
          data.isBuyer ? 'Produits' : 'Vos produits dans cette commande',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...displayItems.map((item) => _OrderItemTile(item: item, showShop: data.isBuyer)),
        const Divider(height: 32),
        if (data.isBuyer)
          _SummaryRow(label: 'Moyen de paiement', value: PaymentMethodId.label(order.paymentMethod ?? '')),
        const SizedBox(height: 8),
        _SummaryRow(
          label: data.isBuyer ? 'Total' : 'Total (votre commerce)',
          value: formatPriceAr(displayTotal),
          emphasize: true,
        ),
        if (data.isMerchantHere) ...[
          const SizedBox(height: 28),
          const Text('Gestion commerçant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          _MerchantActions(
            status: order.status,
            isUpdating: _isUpdating,
            onAdvance: _changeStatus,
            onRefund: () => _refund(order),
          ),
        ],
      ],
    );
  }
}

class _MerchantActions extends StatelessWidget {
  final String status;
  final bool isUpdating;
  final ValueChanged<String> onAdvance;
  final VoidCallback onRefund;

  const _MerchantActions({
    required this.status,
    required this.isUpdating,
    required this.onAdvance,
    required this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final transitions = OrderStatus.availableTransitions(status);
    if (transitions.isEmpty) {
      return Text(
        OrderStatus.isTerminal(status)
            ? 'Cette commande est dans un état final.'
            : 'Aucune action disponible pour le moment.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: transitions.map((next) {
        final isRefund = next == OrderStatus.refunded;
        return isRefund
            ? OutlinedButton.icon(
          onPressed: isUpdating ? null : onRefund,
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('Rembourser'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
        )
            : ElevatedButton(
          onPressed: isUpdating ? null : () => onAdvance(next),
          child: Text('Passer à "${OrderStatus.label(next)}"'),
        );
      }).toList(),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  final bool showShop;

  const _OrderItemTile({required this.item, required this.showShop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (showShop && (item.shopName?.isNotEmpty ?? false))
                  Text(
                    item.shopName!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} x ${formatPriceAr(item.price)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(formatPriceAr(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: emphasize ? 18 : 14,
            color: emphasize ? AppColors.accentDark : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        OrderStatus.label(status),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.accentDark),
      ),
    );
  }
}

class _TerminalBanner extends StatelessWidget {
  final String status;

  const _TerminalBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRefunded = status == OrderStatus.refunded;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isRefunded ? Icons.replay : Icons.cancel_outlined, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Text(
            isRefunded ? 'Cette commande a été remboursée.' : 'Cette commande a été annulée.',
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _ProgressTracker extends StatelessWidget {
  final String status;

  const _ProgressTracker({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.progression;
    final currentIndex = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStepIndex = i ~/ 2;
          final isDone = leftStepIndex < currentIndex;
          return Expanded(
            child: Container(height: 2, color: isDone ? AppColors.accentDark : AppColors.border),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone = stepIndex <= currentIndex;
        return Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppColors.accentDark : AppColors.border,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                OrderStatus.label(steps[stepIndex]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
                  color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _AccessDeniedState extends StatelessWidget {
  const _AccessDeniedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous n\'avez pas accès à cette commande.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger cette commande.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}