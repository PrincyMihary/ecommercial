import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

/// Étape 4 : écran affiché à la place d'un message d'erreur opaque
/// quand une suppression (produit ou commerce) est refusée à cause de
/// commandes non finalisées. Liste les commandes concernées, avec
/// leurs lignes pertinentes, et permet d'ouvrir leur détail pour les
/// faire avancer / les rembourser.
class BlockingOrdersScreen extends StatelessWidget {
  final String title;
  final String explanation;
  final List<Map<String, dynamic>> orders;

  /// Si fourni, les lignes affichées par commande sont filtrées sur
  /// ce produit (cas "suppression d'un produit"). Sinon [shopId] sert
  /// de filtre (cas "suppression d'un commerce").
  final int? productId;
  final int? shopId;

  const BlockingOrdersScreen({
    super.key,
    required this.title,
    required this.explanation,
    required this.orders,
    this.productId,
    this.shopId,
  });

  Future<List<OrderItem>> _relevantItems(int orderId) async {
    final db = DatabaseHelper.instance;
    final rows = shopId != null
        ? await db.getOrderItemsForShop(orderId, shopId!)
        : await db.getOrderItems(orderId);
    final items = rows.map(OrderItem.fromMap).toList();
    if (productId != null) {
      return items.where((i) => i.productId == productId).toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(explanation, style: const TextStyle(height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ces commandes doivent être finalisées ou remboursées avant de réessayer.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...orders.map((order) => _BlockingOrderTile(
            order: order,
            itemsFuture: _relevantItems(order['id'] as int),
          )),
        ],
      ),
    );
  }
}

class _BlockingOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<List<OrderItem>> itemsFuture;

  const _BlockingOrderTile({required this.order, required this.itemsFuture});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final status = order['status'] as String? ?? '';
    final createdAt = order['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Text('Commande #$id', style: const TextStyle(fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  OrderStatus.label(status),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(formatOrderDate(createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          FutureBuilder<List<OrderItem>>(
            future: itemsFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${item.productName} × ${item.quantity} — ${formatPriceAr(item.subtotal)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
                );
              },
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('Voir la commande'),
            ),
          ),
        ],
      ),
    );
  }
}