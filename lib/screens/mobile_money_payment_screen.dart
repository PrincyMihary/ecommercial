import 'package:flutter/material.dart';

import '../services/mock_payment_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Écran de paiement Mobile Money : choix Orange / Yas, affichage
/// d'un numéro de service FICTIF, formulaire de démonstration, et
/// bouton "Payer" qui simule toujours un succès.
class MobileMoneyPaymentScreen extends StatefulWidget {
  final double totalAmount;

  const MobileMoneyPaymentScreen({super.key, required this.totalAmount});

  @override
  State<MobileMoneyPaymentScreen> createState() => _MobileMoneyPaymentScreenState();
}

enum _Operator { orange, yas }

class _MobileMoneyPaymentScreenState extends State<MobileMoneyPaymentScreen> {
  _Operator _selectedOperator = _Operator.orange;
  late String _serviceNumber;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _serviceNumber = MockPaymentService.randomOrangeServiceNumber();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _selectOperator(_Operator op) {
    setState(() {
      _selectedOperator = op;
      _serviceNumber = op == _Operator.orange
          ? MockPaymentService.randomOrangeServiceNumber()
          : MockPaymentService.randomYasServiceNumber();
    });
  }

  Future<void> _pay() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);

    final methodId =
    _selectedOperator == _Operator.orange ? PaymentMethodId.orangeMoney : PaymentMethodId.yas;

    final result = await MockPaymentService.pay(
      methodId: methodId,
      detail: _phoneController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final operatorLabel = _selectedOperator == _Operator.orange ? 'Orange Money' : 'Yas';
    final operatorColor = _selectedOperator == _Operator.orange
        ? const Color(0xFFFF7900)
        : const Color(0xFF1BA94C);

    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _OperatorChip(
                    label: 'Orange Money',
                    selected: _selectedOperator == _Operator.orange,
                    color: const Color(0xFFFF7900),
                    onTap: () => _selectOperator(_Operator.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OperatorChip(
                    label: 'Yas',
                    selected: _selectedOperator == _Operator.yas,
                    color: const Color(0xFF1BA94C),
                    onTap: () => _selectOperator(_Operator.yas),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: operatorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: operatorColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Numéro de service $operatorLabel (démonstration)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _serviceNumber,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: operatorColor),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Numéro fictif généré pour cette démo — n\'appelez pas ce numéro.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Montant : ${formatPriceAr(widget.totalAmount)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Votre numéro de téléphone',
                hintText: '034 XX XXX XX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Code / référence de paiement',
                hintText: 'Ex: 1234',
                border: OutlineInputBorder(),
              ),
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

class _OperatorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _OperatorChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? color : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}