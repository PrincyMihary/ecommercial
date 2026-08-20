import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/shop.dart';
import '../repositories/product_repository.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/cart_service.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import 'ar_view_screen.dart';
import 'blocking_order_screen.dart';
import 'product_form_screen.dart';
import 'shop_detail_screen.dart';
import '../services/auth_service.dart';
class _ProductDetailData {
  final Product product;
  final Shop? shop;

  const _ProductDetailData({required this.product, this.shop});
}

/// Page détail d'un produit : infos complètes, accès au commerce vendeur,
/// point d'entrée AR (placeholder), ajout au panier, modification et
/// suppression.
class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final ShopRepository _shopRepository = ShopRepository();

  late Future<_ProductDetailData?> _future;
  bool _isDeleting = false;

  /// Quantité sélectionnée pour l'ajout au panier. Réinitialisée à 1
  /// après chaque ajout réussi.
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// `GET /products/:id` répond 404 (`ApiException`) si le produit
  /// n'existe pas ; on traduit ce cas en `null`, comme avec
  /// `DatabaseHelper.getProductById` auparavant. Le commerce vendeur
  /// est chargé de la même façon (404 -> `shop` reste `null`, le
  /// produit reste affichable sans lien vers son commerce).
  Future<_ProductDetailData?> _load() async {
    Product product;
    try {
      product = await _productRepository.getById(widget.productId);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }

    Shop? shop;
    try {
      shop = await _shopRepository.getById(product.shopId);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }

    return _ProductDetailData(product: product, shop: shop);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editProduct(Product product) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit modifié')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final user = AuthService.instance.currentUser;
    if (user == null || product.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${product.name} » sera définitivement supprimé.'),
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
      // L'ownership est vérifiée côté backend
      // (`assertProductOwnership`, réponse 403 sinon).
      await _productRepository.delete(product.id!);

      await ImageStorageService.instance.deleteImage(product.image);

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Étape 4 : au lieu d'un message d'erreur opaque, on ouvre un
        // écran listant précisément les commandes qui bloquent la
        // suppression, avec un chemin direct vers leur détail.
        //
        // Le backend refuse (409) mais l'exception REST ne transporte
        // pas la liste des commandes concernées (contrairement à
        // l'ancienne `BlockingOrdersException`) : on la récupère
        // explicitement via `GET /products/:id/blocking-orders` (même
        // DTO `Order` que la table locale `orders`, voir
        // `Order.toMap`), pour réutiliser [BlockingOrdersScreen] sans
        // le modifier.
        setState(() => _isDeleting = false);
        try {
          final blockingOrders =
          await _productRepository.getBlockingOrders(product.id!);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlockingOrdersScreen(
                title: 'Suppression impossible',
                explanation:
                'Impossible de supprimer « ${product.name} ». ${e.message}',
                orders: blockingOrders.map((o) => o.toMap()).toList(),
                productId: product.id,
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
  void _openShop(Shop shop) {
    if (shop.id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopDetailScreen(shopId: shop.id!)),
    );
  }

  void _openArView(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArViewScreen(product: product)),
    );
  }

  /// Ajoute le produit au panier via [CartService], en respectant le
  /// stock disponible. Affiche un message adapté selon que la quantité
  /// demandée a pu être entièrement ajoutée, partiellement ajoutée
  /// (stock limité), ou pas du tout (rupture).
  void _addToCart(Product product) async {
    final requested = _quantity;
    final added = await CartService.instance.addProduct(product, quantity: requested);

    if (!mounted) return;

    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter ce produit : stock insuffisant.')),
      );
      return;
    }

    final message = added < requested
        ? '$added exemplaire(s) ajouté(s) au panier (stock limité).'
        : '${product.name} ajouté au panier ($added).';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _quantity = 1);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text('Détail produit'),
      ),
      body: FutureBuilder<_ProductDetailData?>(
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
            return const Center(child: Text('Produit introuvable.'));
          }

          final product = data.product;
          final shop = data.shop;
          final inStock = product.stock > 0;

          final currentUserId = AuthService.instance.currentUser?.id;
          final isOwner = currentUserId != null &&
              shop?.ownerId != null &&
              shop!.ownerId == currentUserId;

          // Le sélecteur de quantité ne doit jamais dépasser le stock
          // actuel (en particulier si le stock a diminué depuis la
          // dernière fois que l'écran a été affiché).
          if (_quantity > product.stock && product.stock > 0) {
            _quantity = product.stock;
          }

          return AbsorbPointer(
            absorbing: _isDeleting,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: AppImage(
                    path: product.image,
                    fallbackIcon: Icons.shopping_bag_outlined,
                    fallbackIconSize: 64,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${product.price.toStringAsFixed(0)} Ar',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InfoChip(icon: Icons.category_outlined, label: product.category),
                          _InfoChip(
                            icon: Icons.inventory_2_outlined,
                            label: '${product.stock} en stock',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildCartSection(product, inStock),
                      const SizedBox(height: 20),
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.description.isEmpty
                            ? 'Aucune description.'
                            : product.description,
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      if (shop != null) ...[
                        const Text(
                          'Commerce vendeur',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openShop(shop),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AppImage(
                                    path: shop.image,
                                    width: 44,
                                    height: 44,
                                    fallbackIcon: Icons.storefront_outlined,
                                    fallbackIconSize: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        shop.category,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (product.model3d != null && product.model3d!.trim().isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => _openArView(product),                          icon: const Icon(Icons.view_in_ar_outlined),
                          label: const Text('Voir en AR'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentDark,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (isOwner)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _editProduct(product),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Modifier'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isDeleting ? null : () => _deleteProduct(product),
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
              ],
            ),
          );
        },
      ),
    );
  }

  /// Sélecteur de quantité + bouton d'ajout au panier. Désactivé
  /// proprement si le produit est en rupture de stock.
  Widget _buildCartSection(Product product, bool inStock) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Quantité',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (inStock) ...[
                _QtyIconButton(
                  icon: Icons.remove,
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                _QtyIconButton(
                  icon: Icons.add,
                  onPressed:
                  _quantity < product.stock ? () => setState(() => _quantity++) : null,
                ),
              ] else
                const Text(
                  'Indisponible',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: inStock ? () => _addToCart(product) : null,
            icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
            label: Text(inStock ? 'Ajouter au panier' : 'Rupture de stock'),
          ),
        ],
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyIconButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onPressed == null ? AppColors.border : AppColors.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
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