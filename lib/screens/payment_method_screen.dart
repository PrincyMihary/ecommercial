import 'package:flutter/material.dart';

import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'mobile_money_payment_screen.dart';
import 'visa_payment_screen.dart';

/// Écran de choix du moyen de paiement : Mobile Money ou Carte Visa.
///
/// N'effectue lui-même aucun paiement : il délègue à
/// [MobileMoneyPaymentScreen] ou [VisaPaymentScreen], puis relaie leur
/// résultat ([PaymentResult]) à l'appelant (le checkout) en se
/// dépilant à son tour avec le même résultat.
class PaymentMethodScreen extends StatelessWidget {
  final double totalAmount;

  const PaymentMethodScreen({super.key, required this.totalAmount});

  Future<void> _openMobileMoney(BuildContext context) async {
    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => MobileMoneyPaymentScreen(totalAmount: totalAmount),
      ),
    );
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _openVisa(BuildContext context) async {
    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(
        builder: (_) => VisaPaymentScreen(totalAmount: totalAmount),
      ),
    );
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DemoBanner(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant à payer', style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  formatPriceAr(totalAmount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Choisissez un moyen de paiement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _PaymentOptionTile(
              icon: Icons.phone_android,
              title: 'Mobile Money',
              subtitle: 'Orange Money ou Yas',
              onTap: () => _openMobileMoney(context),
            ),
            const SizedBox(height: 12),
            _PaymentOptionTile(
              icon: Icons.credit_card,
              title: 'Carte Visa',
              subtitle: 'Paiement par carte bancaire',
              onTap: () => _openVisa(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.accentDark),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paiement de démonstration : aucune transaction réelle n\'est effectuée.',
              style: TextStyle(fontSize: 12, color: AppColors.accentDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accentDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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