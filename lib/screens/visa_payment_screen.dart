import 'package:flutter/material.dart';

import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Écran de paiement par carte Visa, 100% démonstration.
///
/// Aucune donnée saisie ici n'est envoyée à un serveur ni stockée en
/// base : la fonction [MockPaymentService.pay] ignore les valeurs et
/// renvoie toujours un succès. Seul l'identifiant `visa` (sans le
/// détail de la carte) remonte jusqu'à `orders.payment_method`.
class VisaPaymentScreen extends StatefulWidget {
  final double totalAmount;

  const VisaPaymentScreen({super.key, required this.totalAmount});

  @override
  State<VisaPaymentScreen> createState() => _VisaPaymentScreenState();
}

class _VisaPaymentScreenState extends State<VisaPaymentScreen> {
  final _cardNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isPaying = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);

    // Détail purement informatif pour l'écran de confirmation
    // (4 derniers chiffres uniquement) : jamais le numéro complet ni
    // le CVV, et rien de tout cela n'est persisté en base.
    final raw = _cardNumberController.text.replaceAll(' ', '');
    final last4 = raw.length >= 4 ? raw.substring(raw.length - 4) : raw;

    final result = await MockPaymentService.pay(
      methodId: PaymentMethodId.visa,
      detail: last4.isNotEmpty ? '•••• $last4' : '',
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte Visa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                      'Interface de démonstration : aucune vraie carte n\'est requise ni vérifiée.',
                      style: TextStyle(fontSize: 12, color: AppColors.accentDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Montant : ${formatPriceAr(widget.totalAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numéro de carte',
                hintText: '4242 4242 4242 4242',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom sur la carte',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    decoration: const InputDecoration(
                      labelText: 'Expiration (MM/AA)',
                      hintText: '12/28',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isPaying ? null : _pay,
              child: _isPaying
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Payer'),
            ),
          ],
        ),
      ),
    );
  }
}