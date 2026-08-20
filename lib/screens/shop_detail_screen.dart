import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../repositories/product_repository.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/product_card.dart';
import 'blocking_order_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'shop_form_screen.dart';
import '../services/location_service.dart';

class _ShopDetailData {
  final Shop shop;
  final List<Product> products;

  const _ShopDetailData({required this.shop, required this.products});
}

/// Page détail d'un commerce : infos, liste de ses produits.
///
/// CONSULTATION : accessible à tout le monde (visiteur inclus).
/// ADMINISTRATION (modifier/supprimer le commerce, ajouter un
/// produit) : réservée au propriétaire connecté de CE commerce — un
/// commerce seedé sans owner_id n'est administrable par personne.
class ShopDetailScreen extends StatefulWidget {
  final int shopId;

  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final ShopRepository _shopRepository = ShopRepository();
  final ProductRepository _productRepository = ProductRepository();

  late Future<_ShopDetailData?> _future;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// `GET /shops/:id` répond 404 (`ApiException`) si le commerce
  /// n'existe pas ; on traduit ce cas en `null`, comme avec
  /// `DatabaseHelper.getShopById` auparavant.
  Future<_ShopDetailData?> _load() async {
    Shop shop;
    try {
      shop = await _shopRepository.getById(widget.shopId);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }

    final products = await _productRepository.getByShop(widget.shopId);

    return _ShopDetailData(shop: shop, products: products);
  }
  Future<void> _openMaps(Shop shop) async {
    try {
      await LocationService.instance.openShopLocation(shop);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
  /// `true` si l'utilisateur connecté est le propriétaire de [shop].
  /// Un commerce seedé (ownerId == null) n'est jamais "possédé" par
  /// qui que ce soit ici.
  bool _isOwner(Shop shop) {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;
    return shop.ownerId != null && shop.ownerId == user.id;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editShop(Shop shop) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ShopFormScreen(shop: shop)),
    );
    if (changed == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commerce modifié')),
        );
      }
    }
  }

  Future<void> _addProduct() async {
    // Ne prend plus de shop en paramètre : le formulaire produit
    // résout lui-même le commerce depuis l'utilisateur connecté (voir
    // ProductFormScreen). Ce bouton n'est de toute façon visible que
    // pour le propriétaire de CE commerce (voir build()).
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (created == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit ajouté')),
        );
      }
    }
  }

  Future<void> _openProduct(Product product) async {
    if (product.id == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id!)),
    );
    if (changed == true) _reload();
  }

  Future<void> _deleteShop(Shop shop, List<Product> products) async {
    if (shop.id == null) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final productCount = products.length;
    final message = productCount > 0
        ? 'Ce commerce possède $productCount produit(s). Voulez-vous vraiment le supprimer ? '
        'Tous ses produits seront également supprimés.'
        : 'Voulez-vous vraiment supprimer ce commerce ?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le commerce ?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      // L'ownership (et la suppression en cascade des produits du
      // commerce) est désormais entièrement vérifiée/appliquée côté
      // backend (`assertShopOwnership` + cascade serveur) : un seul
      // appel REST couvre les deux anciens cas SQLite
      // (`deleteShop`/`deleteShopCascade`).
      await _shopRepository.delete(shop.id!);

      // Les fichiers ne sont supprimés qu'après confirmation que la
      // suppression REST a réussi (sinon on serait passé par le
      // catch ci-dessous avant d'atteindre ces lignes).
      for (final product in products) {
        await ImageStorageService.instance.deleteImage(product.image);
      }
      await ImageStorageService.instance.deleteImage(shop.image);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Le backend refuse (409) si ce commerce apparaît dans des
        // commandes non finalisées, avec le même message que
        // l'ancienne `BlockingOrdersException`. Contrairement à
        // celle-ci, l'exception REST ne transporte pas la liste des
        // commandes concernées : on la récupère explicitement via
        // `GET /shops/:id/blocking-orders` (même DTO `Order` que la
        // table locale `orders`, voir `Order.toMap`), pour réutiliser
        // [BlockingOrdersScreen] sans le modifier.
        setState(() => _isDeleting = false);
        try {
          final blockingOrders = await _shopRepository.getBlockingOrders(shop.id!);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlockingOrdersScreen(
                title: 'Suppression impossible',
                explanation:
                'Impossible de supprimer « ${shop.name} ». ${e.message}',
                orders: blockingOrders.map((o) => o.toMap()).toList(),
                shopId: shop.id,
              ),
            ),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } else {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text('Détail commerce'),
      ),
      body: FutureBuilder<_ShopDetailData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Commerce introuvable.'));
          }

          final shop = data.shop;
          final products = data.products;
          final isOwner = _isOwner(shop);

          return AbsorbPointer(
            absorbing: _isDeleting,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AspectRatio(
                  aspectRatio: 1.8,
                  child: AppImage(
                    path: shop.image,
                    fallbackIcon: Icons.storefront_outlined,
                    fallbackIconSize: 56,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InfoChip(icon: Icons.category_outlined, label: shop.category),
                          if (shop.hasAddress)
                            _InfoChip(icon: Icons.place_outlined, label: shop.address!)
                          else
                            const _InfoChip(
                              icon: Icons.public,
                              label: 'Commerce en ligne',
                            ),
                          _InfoChip(
                            icon: Icons.shopping_bag_outlined,
                            label: '${products.length} produit(s)',
                          ),
                        ],
                      ),
                      if (shop.hasStructuredLocation) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openMaps(shop),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Voir sur Google Maps'),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shop.description.isEmpty ? 'Aucune description.' : shop.description,
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      // ADMINISTRATION : uniquement pour le propriétaire connecté.
                      if (isOwner)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _editShop(shop),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Modifier'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                _isDeleting ? null : () => _deleteShop(shop, products),
                                icon: _isDeleting
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Supprimer'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Produits du commerce',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      // "Ajouter" un produit : uniquement pour le
                      // propriétaire de CE commerce (le produit créé
                      // sera de toute façon rattaché à SON commerce,
                      // pas nécessairement celui affiché ici s'il
                      // n'en est pas le propriétaire — d'où la
                      // restriction, pour éviter toute confusion).
                      if (isOwner)
                        TextButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Text(
                      'Aucun produit pour ce commerce.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => _openProduct(product),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}