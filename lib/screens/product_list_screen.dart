import 'package:flutter/material.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import 'shop_form_screen.dart';
import 'signup_screen.dart';

/// État "Mes produits" selon la situation de l'utilisateur.
enum _MyProductsState { guest, noShop, hasShop }

/// "Mes produits" : affiche UNIQUEMENT les produits du commerce de
/// l'utilisateur connecté (products.shop_id = son commerce).
///
/// - Visiteur non connecté : accès bloqué.
/// - Connecté sans commerce : liste vide + invitation à créer son
///   commerce (jamais les produits seedés ou d'un autre commerce).
/// - Connecté avec commerce : uniquement ses propres produits.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final ShopRepository _shopRepository = ShopRepository();

  late Future<List<Product>> _productsFuture;
  _MyProductsState _state = _MyProductsState.guest;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    _productsFuture = _load();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {
      _productsFuture = _load();
    });
  }

  Future<List<Product>> _load() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _state = _MyProductsState.guest;
      return [];
    }

    // "A un commerce ou non" et "produits du commerce" sont deux
    // informations distinctes (un commerce peut avoir 0 produit) :
    // comme avec `DatabaseHelper.getShopByOwnerId` auparavant, on
    // vérifie explicitement l'existence du commerce plutôt que de
    // déduire l'état à partir d'une liste de produits vide.
    // `GET /shops/me` répond 404 (`ApiException`) si l'utilisateur n'a
    // pas encore de commerce.
    try {
      await _shopRepository.getMine();
      _state = _MyProductsState.hasShop;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _state = _MyProductsState.noShop;
        return [];
      }
      rethrow;
    }

    // Requête "mes données" : toujours filtrée par propriétaire,
    // jamais un simple getAll().
    return _productRepository.getMine();
  }

  Future<void> _refresh() async {
    setState(() {
      _productsFuture = _load();
    });
    await _productsFuture;
  }

  Future<void> _openProduct(Product product) async {
    if (product.id == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id!)),
    );
    if (changed == true) _refresh();
  }

  Future<void> _addProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (created == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit ajouté')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes produits')),
      floatingActionButton: _state == _MyProductsState.hasShop
          ? FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }

            switch (_state) {
              case _MyProductsState.guest:
                return _buildGuestState();
              case _MyProductsState.noShop:
                return _buildNoShopState();
              case _MyProductsState.hasShop:
                return _buildProductsGrid(snapshot.data ?? []);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'Connectez-vous pour voir vos produits.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Se connecter'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('Créer un compte'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoShopState() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'Vous devez d\'abord créer votre commerce pour avoir des produits.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const ShopFormScreen()),
                  );
                  if (created == true) _refresh();
                },
                child: const Text('Créer mon commerce'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsGrid(List<Product> products) {
    if (products.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            child: Center(
              child: Text(
                'Aucun produit pour le moment.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
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
    );
  }
}