import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/shop.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'shop_detail_screen.dart';
import 'shop_form_screen.dart';
import 'signup_screen.dart';

/// Écran "Profil" : affiche l'état visiteur (Guest) ou l'état
/// connecté, selon [AuthService.isLoggedIn].
///
/// S'abonne à [AuthService] (même pattern que `CartScreen` avec
/// `CartService`) pour se reconstruire automatiquement après
/// connexion/inscription/déconnexion.
///
/// Étape 2 : pour un utilisateur connecté, affiche également son
/// statut commerçant (aucun commerce / commerce existant), déduit en
/// interrogeant [DatabaseHelper.getShopByOwnerId] — `AuthService` ne
/// fait volontairement aucune requête SQLite lui-même.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  /// Recalcule la future du commerce de l'utilisateur courant.
  /// `null` (future résolue à `null`) si personne n'est connecté ou
  /// si l'utilisateur connecté n'a pas de commerce.
  void _refreshShop() {
    final user = AuthService.instance.currentUser;
    _shopFuture = user == null
        ? Future.value(null)
        : DatabaseHelper.instance.getShopByOwnerId(user.id);
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

  void _logout() {
    AuthService.instance.logout();
  }

  Future<void> _goToCreateShop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ShopFormScreen()),
    );
    if (created == true && mounted) {
      setState(_refreshShop);
    }
  }

  Future<void> _goToMyShop(int shopId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShopDetailScreen(shopId: shopId)),
    );
    // Le commerce a pu être modifié/supprimé : on rafraîchit dans
    // tous les cas au retour.
    if (mounted) {
      setState(_refreshShop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: auth.isLoggedIn ? _buildLoggedInBody(auth) : _buildGuestBody(),
    );
  }

  Widget _buildGuestBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Vous naviguez en tant que visiteur.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connectez-vous pour passer commande et suivre votre historique.',
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

  Widget _buildLoggedInBody(AuthService auth) {
    final user = auth.currentUser!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.accent,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (user.phone != null && user.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(user.phone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>?>(
          future: _shopFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final shopRow = snapshot.data;
            if (shopRow == null) {
              return _buildNoShopCard();
            }
            return _buildShopCard(Shop.fromMap(shopRow));
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: AppColors.danger),
          label: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  Widget _buildNoShopCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Vous n'avez pas encore de commerce.",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Créez votre commerce pour commencer à vendre.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToCreateShop,
              child: const Text('Créer mon commerce'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(Shop shop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vous êtes commerçant.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(shop.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: shop.id == null ? null : () => _goToMyShop(shop.id!),
              child: const Text('Voir mon commerce'),
            ),
          ),
        ],
      ),
    );
  }
}