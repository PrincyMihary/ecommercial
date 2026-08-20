import 'package:flutter/material.dart';
import 'package:marketplace_app/screens/shop_order_list_screen.dart';

import '../models/shop.dart';
import '../repositories/shop_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';
import 'shop_detail_screen.dart';
import 'shop_form_screen.dart';
import 'signup_screen.dart';

/// État résolu du commerce de l'utilisateur, consommé par
/// [SellScreenVisibility.compute].
///
/// Distinct d'un simple `Shop?` : permet de représenter explicitement
/// l'état [error] (ni "a un commerce", ni "n'en a pas"), pour que
/// `_shopFuture` échouant avec une erreur autre que 404 ne soit
/// JAMAIS interprété comme "aucun commerce" — voir
/// [_SellScreenState._loadMyShop].
enum SellScreenShopState { loading, none, present, error }

/// Calcule quelles tuiles afficher sur [SellScreen], à partir de :
/// - si l'utilisateur est connecté ;
/// - l'état résolu de son commerce (voir [SellScreenShopState]).
///
/// Fonction pure (aucun accès réseau, aucun `BuildContext`, aucun
/// effet de bord) : c'est ce qui permet de tester exhaustivement la
/// logique de visibilité des tuiles (voir
/// `test/screens/sell_screen_test.dart`) sans avoir à simuler
/// AuthService/ApiClient dans un test de widget.
class SellScreenVisibility {
  final bool showGuestBlock;
  final bool showLoading;
  final bool showError;
  final bool showMyShop;
  final bool showCreateShop;
  final bool showMyProducts;
  final bool showReceivedOrders;
  final bool showAddProduct;

  const SellScreenVisibility._({
    required this.showGuestBlock,
    required this.showLoading,
    required this.showError,
    required this.showMyShop,
    required this.showCreateShop,
    required this.showMyProducts,
    required this.showReceivedOrders,
    required this.showAddProduct,
  });

  factory SellScreenVisibility.compute({
    required bool isLoggedIn,
    required SellScreenShopState shopState,
  }) {
    if (!isLoggedIn) {
      return const SellScreenVisibility._(
        showGuestBlock: true,
        showLoading: false,
        showError: false,
        showMyShop: false,
        showCreateShop: false,
        showMyProducts: false,
        showReceivedOrders: false,
        showAddProduct: false,
      );
    }

    switch (shopState) {
      case SellScreenShopState.loading:
        return const SellScreenVisibility._(
          showGuestBlock: false,
          showLoading: true,
          showError: false,
          showMyShop: false,
          showCreateShop: false,
          showMyProducts: false,
          showReceivedOrders: false,
          showAddProduct: false,
        );
      case SellScreenShopState.error:
        return const SellScreenVisibility._(
          showGuestBlock: false,
          showLoading: false,
          showError: true,
          showMyShop: false,
          showCreateShop: false,
          showMyProducts: false,
          showReceivedOrders: false,
          showAddProduct: false,
        );
      case SellScreenShopState.none:
        return const SellScreenVisibility._(
          showGuestBlock: false,
          showLoading: false,
          showError: false,
          showMyShop: false,
          showCreateShop: true,
          showMyProducts: true,
          showReceivedOrders: false,
          showAddProduct: true,
        );
      case SellScreenShopState.present:
        return const SellScreenVisibility._(
          showGuestBlock: false,
          showLoading: false,
          showError: false,
          showMyShop: true,
          showCreateShop: false,
          showMyProducts: true,
          showReceivedOrders: true,
          showAddProduct: true,
        );
    }
  }
}

/// Écran "Vendre" : point d'entrée vers la gestion du commerce et des
/// produits.
///
/// Règle métier (1 utilisateur = 0 ou 1 commerce), déterminée via
/// `GET /shops/me` ([ShopRepository.getMine]) :
/// - Guest : écran bloqué, invitation à se connecter/s'inscrire ;
/// - User sans commerce (404) : tuile "Créer mon commerce" ;
/// - User avec commerce (200) : tuile "Mon commerce" + "Commandes
///   reçues" ;
/// - Erreur réseau/API (ni 200 ni 404) : état d'erreur explicite avec
///   "Réessayer" — jamais confondu avec "aucun commerce" (voir
///   [_loadMyShop]).
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final ShopRepository _shopRepository = ShopRepository();

  Future<Shop?>? _shopFuture;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    _refreshShop();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(_refreshShop);
  }

  void _refreshShop() {
    final user = AuthService.instance.currentUser;
    _shopFuture = user == null ? Future.value(null) : _loadMyShop();
  }

  /// `GET /shops/me` renvoie 404 (`ApiException`) si l'utilisateur n'a
  /// pas encore de commerce ; on traduit UNIQUEMENT ce cas précis en
  /// `null`. Toute autre `ApiException` (réseau, timeout, 500...) est
  /// relancée telle quelle, pour que le `FutureBuilder` la distingue
  /// explicitement d'un "aucun commerce" (voir [_buildLoggedInBody]).
  Future<Shop?> _loadMyShop() async {
    try {
      return await _shopRepository.getMine();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      // Une visite du formulaire de commerce, du détail commerce, de
      // la liste produits ou des commandes reçues a pu changer le
      // statut commerçant (création/suppression du commerce...) :
      // l'état est toujours recalculé au retour.
      if (mounted) setState(_refreshShop);
    });
  }

  Future<void> _goToLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _goToSignup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Vendre')),
      body: auth.isLoggedIn ? _buildLoggedInBody() : _buildGuestBody(),
    );
  }

  Widget _buildGuestBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vendre est réservé aux utilisateurs connectés.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connectez-vous ou créez un compte pour ouvrir votre commerce.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToLogin,
                child: const Text('Se connecter'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _goToSignup,
                child: const Text('Créer un compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SellScreenShopState _shopStateFrom(AsyncSnapshot<Shop?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return SellScreenShopState.loading;
    }
    if (snapshot.hasError) {
      return SellScreenShopState.error;
    }
    return snapshot.data != null ? SellScreenShopState.present : SellScreenShopState.none;
  }

  Widget _buildLoggedInBody() {
    return FutureBuilder<Shop?>(
      future: _shopFuture,
      builder: (context, snapshot) {
        final visibility = SellScreenVisibility.compute(
          isLoggedIn: true,
          shopState: _shopStateFrom(snapshot),
        );

        if (visibility.showLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (visibility.showError) {
          return _buildErrorState(snapshot.error);
        }

        final shop = snapshot.data;
        final shopId = shop?.id;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Gérez votre commerce et vos produits.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (visibility.showMyShop)
              _SellTile(
                icon: Icons.storefront,
                title: 'Mon commerce',
                subtitle: 'Consulter et gérer votre commerce',
                onTap: () => _open(context, ShopDetailScreen(shopId: shopId!)),
              )
            else if (visibility.showCreateShop)
              _SellTile(
                icon: Icons.add_business_outlined,
                title: 'Créer mon commerce',
                subtitle: 'Ouvrir votre commerce sur la marketplace',
                onTap: () => _open(context, const ShopFormScreen()),
              ),
            if (visibility.showMyProducts) ...[
              const SizedBox(height: 12),
              _SellTile(
                icon: Icons.inventory_2_outlined,
                title: 'Mes produits',
                subtitle: 'Consulter et gérer vos produits',
                onTap: () => _open(context, const ProductListScreen()),
              ),
            ],
            if (visibility.showReceivedOrders) ...[
              const SizedBox(height: 12),
              _SellTile(
                icon: Icons.receipt_long_outlined,
                title: 'Commandes reçues',
                subtitle: 'Suivre et gérer les commandes de votre commerce',
                onTap: () => _open(context, const ShopOrderListScreen()),
              ),
            ],
            if (visibility.showAddProduct) ...[
              const SizedBox(height: 12),
              _SellTile(
                icon: Icons.add_circle_outline,
                title: 'Ajouter un produit',
                subtitle: 'Créer un nouveau produit',
                onTap: () => _open(context, const ProductFormScreen()),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildErrorState(Object? error) {
    final message = error is ApiException
        ? error.message
        : 'Impossible de charger les informations de votre commerce.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(_refreshShop),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SellTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}