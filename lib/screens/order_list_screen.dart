import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/order_status.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

/// Écran "Mes commandes" : liste de toutes les commandes enregistrées
/// localement, les plus récentes en premier.
class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return DatabaseHelper.instance.getOrdersWithItemCount();
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = _load();
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final orders = snapshot.data ?? const [];
          if (orders.isEmpty) {
            return _EmptyState(onRefresh: _refresh);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OrderTile(order: orders[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final status = order['status'] as String? ?? '';
    final createdAt = order['created_at'] as String? ?? '';
    final itemCount = (order['item_count'] as num?)?.toInt() ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Commande #$id', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 6),
            Text(formatOrderDate(createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  itemCount > 1 ? '$itemCount articles' : '$itemCount article',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  formatPriceAr(total),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case OrderStatus.paid:
        return AppColors.accentDark;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return Colors.orange;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        OrderStatus.label(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune commande pour le moment.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vos commandes passées apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
              'Impossible de charger vos commandes.',
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