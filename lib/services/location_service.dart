import 'package:url_launcher/url_launcher.dart';

import '../models/shop.dart';

class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);
  @override
  String toString() => message;
}

/// Service centralisé de construction/ouverture d'URL Google Maps.
/// Aucun écran ne doit construire cette URL lui-même.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// URL Google Maps pour [shop], ou `null` si aucune localisation
  /// structurée n'est disponible. Priorité au Place ID.
  Uri? buildMapsUri(Shop shop) {
    final placeId = shop.googlePlaceId;
    final lat = shop.latitude;
    final lng = shop.longitude;

    if (placeId != null && placeId.isNotEmpty) {
      final query = Uri.encodeComponent(shop.address ?? shop.name);
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query&query_place_id=$placeId',
      );
    }

    if (lat != null && lng != null) {
      return Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    }

    return null;
  }

  /// Ouvre l'emplacement de [shop] (Google Maps si installé, sinon
  /// fallback navigateur géré par `url_launcher`).
  Future<void> openShopLocation(Shop shop) async {
    final uri = buildMapsUri(shop);
    if (uri == null) {
      throw const LocationServiceException('Aucune localisation disponible pour ce commerce.');
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const LocationServiceException('Impossible d\'ouvrir Google Maps.');
    }
  }
}