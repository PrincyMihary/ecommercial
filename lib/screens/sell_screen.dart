import 'package:flutter/material.dart';
import 'package:marketplace_app/screens/shop_order_list_screen.dart';

import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';
import 'shop_detail_screen.dart';
import 'shop_form_screen.dart';
import 'signup_screen.dart';

/// Écran "Vendre" : point d'entrée vers la gestion du commerce et des
/// produits.
///
/// Étape 2 : le point d'entrée "commerce" respecte désormais la règle
/// métier (1 utilisateur = 0 ou 1 commerce) :
/// - Guest : écran bloqué, invitation à se connecter/s'inscrire ;
/// - User sans commerce : tuile "Créer mon commerce" ;
/// - User avec commerce : tuile "Mon commerce" (accès direct).
///
/// La gestion des produits ("Mes produits" / "Ajouter un produit")
/// n'est pas encore restreinte par propriétaire à cette étape (voir
/// énoncé : la logique commerçant complète sur les produits viendra à
/// l'étape suivante) — ces tuiles restent donc inchangées pour tout
/// utilisateur connecté.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  Future<Map<String, dynamic>?>? _shopFuture;

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
    _shopFuture = user == null
        ? Future.value(null)
        : DatabaseHelper.instance.getShopByOwnerId(user.id);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      // Une visite du formulaire de commerce ou du détail commerce a
      // pu changer le statut commerçant (création, suppression...).
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

  Widget _buildLoggedInBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _shopFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shopRow = snapshot.data;
        final shopId = shopRow != null ? shopRow['id'] as int? : null;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Gérez votre commerce et vos produits.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            if (shopId != null)
              _SellTile(
                icon: Icons.storefront,
                title: 'Mon commerce',
                subtitle: 'Consulter et gérer votre commerce',
                onTap: () => _open(context, ShopDetailScreen(shopId: shopId)),
              )
            else
              _SellTile(
                icon: Icons.add_business_outlined,
                title: 'Créer mon commerce',
                subtitle: 'Ouvrir votre commerce sur la marketplace',
                onTap: () => _open(context, const ShopFormScreen()),
              ),
            const SizedBox(height: 12),
            _SellTile(
              icon: Icons.inventory_2_outlined,
              title: 'Mes produits',
              subtitle: 'Consulter et gérer vos produits',
              onTap: () => _open(context, const ProductListScreen()),
            ),
            if (shopId != null) ...[
              const SizedBox(height: 12),
              _SellTile(
                icon: Icons.receipt_long_outlined,
                title: 'Commandes reçues',
                subtitle: 'Suivre et gérer les commandes de votre commerce',
                onTap: () => _open(context, const ShopOrderListScreen()),
              ),
            ],
            const SizedBox(height: 12),
            _SellTile(
              icon: Icons.add_circle_outline,
              title: 'Ajouter un produit',
              subtitle: 'Créer un nouveau produit',
              onTap: () => _open(context, const ProductFormScreen()),
            ),
          ],
        );
      },
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