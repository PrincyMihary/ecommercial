import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../repositories/shop_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import 'shop_detail_screen.dart';
import 'shop_form_screen.dart';

/// Liste/grille des commerces ("Mes commerces" depuis l'onglet Vendre).
class ShopListScreen extends StatefulWidget {
  const ShopListScreen({super.key});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  final ShopRepository _shopRepository = ShopRepository();

  late Future<List<Shop>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _load();
  }

  Future<List<Shop>> _load() => _shopRepository.getAll();

  Future<void> _refresh() async {
    setState(() {
      _shopsFuture = _load();
    });
    await _shopsFuture;
  }

  Future<void> _openShop(Shop shop) async {
    if (shop.id == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ShopDetailScreen(shopId: shop.id!)),
    );
    if (changed == true) _refresh();
  }

  Future<void> _addShop() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ShopFormScreen()),
    );
    if (created == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commerce ajouté')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes commerces')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShop,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau commerce'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Shop>>(
          future: _shopsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }

            final shops = snapshot.data ?? [];

            if (shops.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                    child: Center(
                      child: Text(
                        'Aucun commerce pour le moment.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: shops.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final shop = shops[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openShop(shop),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        AppImage(
                          path: shop.image,
                          width: 64,
                          height: 64,
                          borderRadius: BorderRadius.circular(14),
                          fallbackIcon: Icons.storefront_outlined,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shop.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.accentDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (shop.hasAddress) ? shop.address! : 'Commerce en ligne',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}