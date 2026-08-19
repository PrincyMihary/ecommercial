/// Formatte un montant en Ariary avec séparateur de milliers,
/// ex: 245000.0 -> "245 000 Ar".
///
/// Reprend la même logique que `CartScreen._formatPrice` (dupliquée
/// volontairement à l'origine dans cet écran) pour être réutilisable
/// par les nouveaux écrans checkout / paiement / commandes sans
/// toucher à `cart_screen.dart`.
String formatPriceAr(double price) {
  final rounded = price.round();
  final asString = rounded.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < asString.length; i++) {
    final positionFromEnd = asString.length - i;
    buffer.write(asString[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${buffer.toString()} Ar';
}

const List<String> _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Formatte une date ISO 8601 (telle que stockée dans `orders.created_at`)
/// en date lisible française, ex: "16 août 2026".
///
/// Volontairement sans dépendance à `intl` (non présente dans le
/// pubspec actuel) pour ne pas ajouter de dépendance inutile.
String formatOrderDate(String isoDate) {
  try {
    final date = DateTime.parse(isoDate);
    final month = _frenchMonths[date.month - 1];
    return '${date.day} $month ${date.year}';
  } catch (_) {
    return isoDate;
  }
}

/// Formatte une date + heure ISO 8601, ex: "16 août 2026 à 14:32".
String formatOrderDateTime(String isoDate) {
  try {
    final date = DateTime.parse(isoDate);
    final month = _frenchMonths[date.month - 1];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month ${date.year} à $hh:$mm';
  } catch (_) {
    return isoDate;
  }
}