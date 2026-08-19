import 'dart:convert';
import 'package:http/http.dart' as http;

/// Suggestion retournée par l'autocomplétion Google Places.
class PlaceSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });
}

/// Détails d'un lieu sélectionné, entièrement indépendants du SDK
/// Google : uniquement des types Dart primitifs.
class PlaceSelection {
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String placeId;

  const PlaceSelection({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });
}

class PlacesException implements Exception {
  final String message;
  const PlacesException(this.message);
  @override
  String toString() => message;
}

/// Accès à l'API Google Places (New) en HTTP direct.
///
/// MODE MOCK :
/// Tant qu'aucune clé n'est fournie via
/// `--dart-define=GOOGLE_PLACES_API_KEY=...`, le service retourne des
/// résultats simulés (voir [_mockPlaces]) au lieu d'appeler Google.
/// Cela permet de développer/tester tout le flux de sélection de lieu
/// (recherche -> sélection -> Shop.address/latitude/longitude/
/// googlePlaceId -> bouton "Voir sur Google Maps") sans avoir encore
/// activé la facturation Google Cloud.
///
/// Aucun autre fichier ne doit être conscient de ce mode : il est
/// entièrement interne à ce service.
class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  static const String _apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  static const String _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _detailsBaseUrl = 'https://places.googleapis.com/v1/places';

  /// `true` si aucune clé API n'est configurée : le service utilise
  /// alors des données simulées plutôt que d'appeler Google.
  bool get isMockMode => _apiKey.isEmpty;

  /// Jeu de lieux simulés, cohérent avec les villes déjà présentes
  /// dans `SeedData` (Antananarivo, Toamasina, Antsirabe,
  /// Fianarantsoa) + quelques enseignes reconnaissables pour tester
  /// une recherche réaliste.
  static final List<PlaceSelection> _mockPlaces = [
    const PlaceSelection(
      name: 'Jumbo Score Ankorondrano',
      formattedAddress: 'Ankorondrano, Antananarivo, Madagascar',
      latitude: -18.8792,
      longitude: 47.5079,
      placeId: 'mock_jumbo_ankorondrano',
    ),
    const PlaceSelection(
      name: 'Analakely Market',
      formattedAddress: 'Analakely, Antananarivo, Madagascar',
      latitude: -18.9086,
      longitude: 47.5257,
      placeId: 'mock_analakely_market',
    ),
    const PlaceSelection(
      name: 'Bazary Be',
      formattedAddress: 'Bazary Be, Toamasina, Madagascar',
      latitude: -18.1492,
      longitude: 49.4023,
      placeId: 'mock_bazary_be_toamasina',
    ),
    const PlaceSelection(
      name: 'Port de Toamasina',
      formattedAddress: 'Boulevard Joffre, Toamasina, Madagascar',
      latitude: -18.1447,
      longitude: 49.4056,
      placeId: 'mock_port_toamasina',
    ),
    const PlaceSelection(
      name: 'Marché Antsirabe',
      formattedAddress: 'Centre-ville, Antsirabe, Madagascar',
      latitude: -19.8667,
      longitude: 47.0333,
      placeId: 'mock_marche_antsirabe',
    ),
    const PlaceSelection(
      name: 'Artisanat Fianarantsoa',
      formattedAddress: 'Rue de l\'Artisanat, Fianarantsoa, Madagascar',
      latitude: -21.4536,
      longitude: 47.0857,
      placeId: 'mock_artisanat_fianarantsoa',
    ),
  ];

  void _ensureConfigured() {
    if (_apiKey.isEmpty) {
      throw const PlacesException(
        'Clé API Google Places manquante. Relancez l\'application avec '
            '--dart-define=GOOGLE_PLACES_API_KEY=VOTRE_CLE.',
      );
    }
  }

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return [];

    if (isMockMode) {
      return _mockAutocomplete(trimmed);
    }

    final response = await http.post(
      Uri.parse(_autocompleteUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: jsonEncode({'input': trimmed}),
    );

    if (response.statusCode != 200) {
      throw PlacesException(
        'Erreur Google Places (${response.statusCode}) lors de la recherche.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = data['suggestions'] as List<dynamic>? ?? [];

    return suggestions
        .map((raw) {
      final prediction = raw['placePrediction'] as Map<String, dynamic>?;
      if (prediction == null) return null;
      final placeId = prediction['placeId'] as String? ?? '';
      if (placeId.isEmpty) return null;

      final text = prediction['text'] as Map<String, dynamic>?;
      final fullText = text?['text'] as String? ?? '';
      final structured = prediction['structuredFormat'] as Map<String, dynamic>?;
      final mainText =
          (structured?['mainText'] as Map<String, dynamic>?)?['text'] as String? ??
              fullText;
      final secondaryText =
          (structured?['secondaryText'] as Map<String, dynamic>?)?['text']
          as String? ??
              '';

      return PlaceSuggestion(
        placeId: placeId,
        primaryText: mainText,
        secondaryText: secondaryText,
      );
    })
        .whereType<PlaceSuggestion>()
        .toList();
  }

  Future<PlaceSelection> getPlaceDetails(String placeId) async {
    if (isMockMode) {
      return _mockDetails(placeId);
    }

    _ensureConfigured();

    final response = await http.get(
      Uri.parse('$_detailsBaseUrl/$placeId'),
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
      },
    );

    if (response.statusCode != 200) {
      throw PlacesException(
        'Erreur Google Places (${response.statusCode}) lors de la récupération du lieu.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final displayName =
        (data['displayName'] as Map<String, dynamic>?)?['text'] as String? ?? '';
    final formattedAddress = data['formattedAddress'] as String? ?? '';
    final location = data['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();
    final id = data['id'] as String? ?? placeId;

    if (lat == null || lng == null) {
      throw const PlacesException('Coordonnées introuvables pour ce lieu.');
    }

    return PlaceSelection(
      name: displayName,
      formattedAddress: formattedAddress,
      latitude: lat,
      longitude: lng,
      placeId: id,
    );
  }

  // -------------------------------------------------------------------
  // MOCK
  // -------------------------------------------------------------------

  Future<List<PlaceSuggestion>> _mockAutocomplete(String input) async {
    // Léger délai simulé pour reproduire une vraie latence réseau
    // (utile pour tester les indicateurs de chargement de l'UI).
    await Future.delayed(const Duration(milliseconds: 300));

    final lower = input.toLowerCase();
    return _mockPlaces
        .where((p) =>
    p.name.toLowerCase().contains(lower) ||
        p.formattedAddress.toLowerCase().contains(lower))
        .map((p) => PlaceSuggestion(
      placeId: p.placeId,
      primaryText: p.name,
      secondaryText: p.formattedAddress,
    ))
        .toList();
  }

  Future<PlaceSelection> _mockDetails(String placeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockPlaces.firstWhere(
          (p) => p.placeId == placeId,
      orElse: () => throw const PlacesException('Lieu simulé introuvable.'),
    );
  }
}