import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

/// Écran affiché juste après un paiement réussi et la création
/// définitive de la commande (statut déjà `paid` en base).
class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;
  final double total;
  final String paymentMethodLabel;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.total,
    required this.paymentMethodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.accentDark, size: 56),
              ),
              const SizedBox(height: 20),
              const Text(
                'Commande confirmée',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              _InfoRow(label: 'Numéro de commande', value: '#$orderId'),
              const SizedBox(height: 10),
              _InfoRow(label: 'Montant', value: formatPriceAr(total)),
              const SizedBox(height: 10),
              _InfoRow(label: 'Moyen de paiement', value: paymentMethodLabel),
              const SizedBox(height: 10),
              const _InfoRow(label: 'Statut', value: 'Payée'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: orderId),
                      ),
                    );
                  },
                  child: const Text('Voir ma commande'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Continuer mes achats'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}