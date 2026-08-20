import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Détail d'une commande.
///
/// Migration REST : `OrderRepository.getDetail()` (`GET /orders/:id`)
/// renvoie déjà `items` filtrés selon le rôle de l'appelant, ainsi
/// que les booléens `isBuyer`/`isMerchant` — voir [OrderDetail] dans
/// `order_repository.dart`. La règle d'accès (acheteur voit tout ;
/// commerçant ne voit que ses propres lignes ; ni l'un ni l'autre =
/// refus) est désormais appliquée CÔTÉ BACKEND avant l'envoi des
/// données : cet écran ne recalcule plus rien lui-même (l'ancienne
/// classe locale `_OrderDetailData`, qui recroisait `allItems` avec
/// `myShopId` résolu via `getShopByOwnerId`, a été supprimée).
///
/// Un accès refusé remonte sous forme d'`ApiException` avec
/// `statusCode == 403` (distinct de `404`, commande introuvable).
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderRepository _orderRepository = OrderRepository();

  late Future<OrderDetail> _future;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<OrderDetail> _load() {
    return _orderRepository.getDetail(widget.orderId);
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
      // Le backend applique `assertShopOwnership` puis
      // `OrderStatus.canTransition` avant d'accepter la transition —
      // mêmes règles, mêmes messages, que l'ancien
      // `DatabaseHelper.advanceOrderStatusForShop`.
      await _orderRepository.advanceStatus(widget.orderId, newStatus);
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
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
      // de MockPaymentService.pay), pas un nouveau système. Le
      // remboursement effectif (changement de statut + réapprovisionnement
      // du stock, dans une même transaction) est désormais côté
      // backend, voir `OrderRepository.refund`.
      await MockPaymentService.refund(
        methodId: order.paymentMethod ?? '',
        detail: 'Remboursement commande #${order.id}',
      );
      await _orderRepository.refund(widget.orderId);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remboursement effectué.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.message}')),
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
      body: FutureBuilder<OrderDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is ApiException && error.statusCode == 403) {
              return const _AccessDeniedState();
            }
            if (error is ApiException && error.statusCode == 404) {
              return const Center(child: Text('Cette commande est introuvable.'));
            }
            return _ErrorState(onRetry: _refresh);
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Cette commande est introuvable.'));
          }

          return AbsorbPointer(
            absorbing: _isUpdating,
            child: _buildContent(data),
          );
        },
      ),
    );
  }

  Widget _buildContent(OrderDetail data) {
    final order = data.order;
    final items = data.items;
    // Vue client complète si acheteur ; sinon vue commerçant limitée
    // à ses propres lignes — `items` est déjà le bon sous-ensemble,
    // renvoyé tel quel par le backend (voir doc de classe). Le total
    // affiché à un commerçant est calculé localement à partir de ces
    // lignes déjà filtrées (aucune règle d'accès recalculée ici, à
    // la différence de l'ancienne `myShopTotal`, qui recroisait
    // `allItems` avec un `myShopId` résolu côté client).
    final displayTotal = data.isBuyer
        ? order.total
        : items.fold<double>(0.0, (sum, item) => sum + item.subtotal);

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
        if (!data.isBuyer && data.isMerchant)
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
        ...items.map((item) => _OrderItemTile(item: item, showShop: data.isBuyer)),
        const Divider(height: 32),
        if (data.isBuyer)
          _SummaryRow(label: 'Moyen de paiement', value: PaymentMethodId.label(order.paymentMethod ?? '')),
        const SizedBox(height: 8),
        _SummaryRow(
          label: data.isBuyer ? 'Total' : 'Total (votre commerce)',
          value: formatPriceAr(displayTotal),
          emphasize: true,
        ),
        if (data.isMerchant) ...[
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