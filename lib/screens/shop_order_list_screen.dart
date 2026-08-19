import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/order_status.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

/// Étape 4 : "Commandes reçues" côté COMMERÇANT — uniquement les
/// commandes contenant au moins une ligne de SON commerce (résolu
/// depuis `AuthService.currentUser`, jamais un shopId externe).
class ShopOrderListScreen extends StatefulWidget {
  const ShopOrderListScreen({super.key});

  @override
  State<ShopOrderListScreen> createState() => _ShopOrderListScreenState();
}

class _ShopOrderListScreenState extends State<ShopOrderListScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final user = AuthService.instance.currentUser;
    if (user == null) return Future.value(const []);
    return DatabaseHelper.instance.getOrdersForShopOwner(user.id);
  }

  Future<void> _refresh() async {
    setState(() => _ordersFuture = _load());
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commandes reçues')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            final orders = snapshot.data ?? const [];
            if (orders.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                        child: Text(
                          'Aucune commande ne concerne encore votre commerce.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ShopOrderTile(order: orders[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ShopOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;

  const _ShopOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final status = order['status'] as String? ?? '';
    final createdAt = order['created_at'] as String? ?? '';
    final shopItemCount = (order['shop_item_count'] as num?)?.toInt() ?? 0;
    final shopTotal = (order['shop_total'] as num?)?.toDouble() ?? 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
      ),
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
            const SizedBox(height: 6),
            Text(formatOrderDate(createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shopItemCount > 1
                      ? '$shopItemCount article(s) de votre commerce'
                      : '$shopItemCount article de votre commerce',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  formatPriceAr(shopTotal),
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