import 'dart:math';

/// Identifiants de moyen de paiement, tels que stockés en base dans
/// `orders.payment_method`.
class PaymentMethodId {
  static const String orangeMoney = 'orange_money';
  static const String yas = 'yas';
  static const String visa = 'visa';

  static String label(String id) {
    switch (id) {
      case orangeMoney:
        return 'Orange Money';
      case yas:
        return 'Yas';
      case visa:
        return 'Carte Visa';
      default:
        return id;
    }
  }
}

/// Résultat d'un paiement mocké, transporté entre les écrans de
/// paiement et l'écran de checkout qui finalise la commande.
class PaymentResult {
  final String methodId;
  final String methodLabel;

  /// Détail additionnel purement informatif (ex: numéro de téléphone
  /// saisi, 4 derniers chiffres de carte). N'est PAS persisté en
  /// base : seul `methodId` l'est.
  final String detail;

  const PaymentResult({
    required this.methodId,
    required this.methodLabel,
    this.detail = '',
  });
}


/// Service 100% mocké : aucune requête réseau, aucune API bancaire,
/// aucune vraie passerelle. Toutes les données (numéros de service,
/// succès du paiement) sont fictives et générées localement.
///
/// Quoi que l'utilisateur saisisse dans les formulaires de paiement,
/// [pay] retourne toujours un succès : c'est le comportement attendu
/// du prototype.
class MockPaymentService {
  MockPaymentService._();

  static final Random _random = Random();

  /// 10 numéros de service FICTIFS pour Orange Money, au format
  /// "32 XX XXX XX". Purement inventés pour la démo, ne correspondent
  /// à aucun vrai numéro.
  static const List<String> orangeServiceNumbers = [
    '32 10 123 45',
    '32 11 234 56',
    '32 12 345 67',
    '32 13 456 78',
    '32 14 567 89',
    '32 15 678 90',
    '32 16 789 01',
    '32 17 890 12',
    '32 18 901 23',
    '32 19 012 34',
  ];

  /// 10 numéros de service FICTIFS pour Yas, au format "34 XX XXX XX".
  static const List<String> yasServiceNumbers = [
    '34 10 123 45',
    '34 11 234 56',
    '34 12 345 67',
    '34 13 456 78',
    '34 14 567 89',
    '34 15 678 90',
    '34 16 789 01',
    '34 17 890 12',
    '34 18 901 23',
    '34 19 012 34',
  ];

  static String randomOrangeServiceNumber() =>
      orangeServiceNumbers[_random.nextInt(orangeServiceNumbers.length)];

  static String randomYasServiceNumber() =>
      yasServiceNumbers[_random.nextInt(yasServiceNumbers.length)];

  /// Simule un paiement (Mobile Money ou Visa). Toujours un succès,
  /// avec un léger délai pour simuler une interaction réseau.
  static Future<PaymentResult> pay({
    required String methodId,
    String detail = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return PaymentResult(
      methodId: methodId,
      methodLabel: PaymentMethodId.label(methodId),
      detail: detail,
    );
  }
  /// Simule un REMBOURSEMENT (toujours un succès, même mécanique que
  /// [pay]). Aucune vraie passerelle : c'est le même service mocké,
  /// pas un second système de paiement.
  static Future<PaymentResult> refund({
    required String methodId,
    String detail = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return PaymentResult(
      methodId: methodId,
      methodLabel: PaymentMethodId.label(methodId),
      detail: detail,
    );
  }
}