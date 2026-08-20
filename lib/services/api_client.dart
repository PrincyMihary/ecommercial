import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Catégorie d'erreur rencontrée par [ApiClient], utile pour que
/// l'UI adapte son message (ex : proposer "Réessayer" sur
/// [network]/[timeout], afficher le message serveur tel quel sur
/// [http]).
enum ApiErrorType {
  /// Pas de connexion / hôte injoignable (ex : mauvaise IP/port de
  /// [ApiClient.configure], serveur backend non démarré).
  network,

  /// Délai dépassé (voir [ApiClient._timeout]).
  timeout,

  /// Réponse HTTP reçue mais avec un code d'erreur (4xx/5xx).
  http,

  /// Réponse reçue mais corps illisible en JSON.
  decode,
}

/// Erreur levée par [ApiClient], avec un message déjà adapté à un
/// affichage utilisateur (SnackBar, dialogue...), même pattern que
/// les autres exceptions du projet (ex : `AuthException`,
/// `ImageStorageException`).
class ApiException implements Exception {
  final String message;
  final ApiErrorType type;

  /// Code HTTP renvoyé par le serveur, si la réponse a été reçue
  /// (absent pour [ApiErrorType.network]/[ApiErrorType.timeout]).
  final int? statusCode;

  const ApiException(this.message, {required this.type, this.statusCode});

  @override
  String toString() => message;
}

/// Client HTTP centralisé pour l'API REST du backend
/// (Node.js/Express, voir plan de migration).
///
/// Rôle strictement transport : construire les requêtes (URL,
/// headers, JSON, timeout), les envoyer, et renvoyer soit le JSON
/// décodé (`Map`/`List`/valeur brute), soit lever une
/// [ApiException]. Aucune logique métier (validation de formulaire,
/// règles de propriété, etc.) ne doit être ajoutée ici : elle revient
/// aux futurs repositories qui utiliseront ce client.
///
/// IMPORTANT (BIGINT/JSON) : ce client ne fait AUCUNE conversion
/// automatique des champs numériques. Il renvoie le JSON décodé tel
/// quel. Voir plan de migration §6/§7 : les identifiants BIGINT sont
/// une responsabilité backend (Claude 2.5), pas une responsabilité
/// de cette couche transport.
///
/// URL de base : jamais d'IP personnelle codée en dur de façon
/// définitive. Par défaut, adresse de l'émulateur Android
/// (`10.0.2.2`), substituable sans recompiler via
/// `--dart-define=API_BASE_URL=http://IP_LOCALE_DU_PC:PORT` — même
/// mécanisme que `PlacesService` avec `GOOGLE_PLACES_API_KEY` — ou à
/// l'exécution via [configure].
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  /// Adresse par défaut : émulateur Android (`10.0.2.2`) pointant sur
  /// le backend local en développement (voir plan de migration §3).
  /// Pour un téléphone physique ou un autre port, surchargez via
  /// `--dart-define=API_BASE_URL=...` ou [configure].
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration _defaultTimeout = Duration(seconds: 15);

  String _baseUrl = _defaultBaseUrl;
  Duration _timeout = _defaultTimeout;
  String? _token;
  http.Client _client = http.Client();

  /// Ajuste l'URL de base et/ou le délai d'expiration à l'exécution
  /// (ex : IP du PC saisie dans un écran de réglages plutôt que
  /// recompilée). Ne touche pas au token — voir [setToken].
  void configure({String? baseUrl, Duration? timeout}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
    }
    if (timeout != null) {
      _timeout = timeout;
    }
  }

  String get baseUrl => _baseUrl;

  /// Interface d'injection du token d'authentification (JWT), prête
  /// pour le futur workflow login/register (Claude 5B/Claude 2).
  /// Volontairement minimal et en mémoire uniquement, comme
  /// `AuthService` à cette étape : aucune persistance disque n'est
  /// mise en place ici.
  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  void clearToken() {
    _token = null;
  }

  /// Permet aux tests d'injecter un `http.Client` simulé (ex :
  /// `package:http/testing.dart`) sans dépendance supplémentaire.
  /// Ne pas utiliser en dehors des tests.
  @visibleForTesting
  void setClientForTesting(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  void resetClientForTesting() {
    _client = http.Client();
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) {
    final uri = _buildUri(path, queryParams);
    return _send(() => _client.get(uri, headers: _headers()));
  }

  Future<dynamic> post(String path, {Object? body}) {
    final uri = _buildUri(path, null);
    return _send(
      () => _client.post(uri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> put(String path, {Object? body}) {
    final uri = _buildUri(path, null);
    return _send(
      () => _client.put(uri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> patch(String path, {Object? body}) {
    final uri = _buildUri(path, null);
    return _send(
      () => _client.patch(uri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> delete(String path, {Object? body}) {
    final uri = _buildUri(path, null);
    return _send(
      () => _client.delete(uri, headers: _headers(), body: _encode(body)),
    );
  }

  // -------------------------------------------------------------------
  // Interne
  // -------------------------------------------------------------------

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final full = '$_baseUrl$normalizedPath';
    final uri = Uri.parse(full);
    if (queryParams == null || queryParams.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParams,
    });
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  String? _encode(Object? body) {
    if (body == null) return null;
    return jsonEncode(body);
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps à répondre. Réessayez.',
        type: ApiErrorType.timeout,
      );
    } on SocketException {
      throw const ApiException(
        'Impossible de joindre le serveur. Vérifiez la connexion et '
        'l\'adresse configurée.',
        type: ApiErrorType.network,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        e.message.isNotEmpty
            ? e.message
            : 'Impossible de joindre le serveur.',
        type: ApiErrorType.network,
      );
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'Réponse du serveur illisible (JSON invalide).',
          type: ApiErrorType.decode,
          statusCode: statusCode,
        );
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    String message = 'Erreur serveur ($statusCode).';
    if (decoded is Map<String, dynamic>) {
      final serverMessage = decoded['message'] ?? decoded['error'];
      if (serverMessage is String && serverMessage.isNotEmpty) {
        message = serverMessage;
      }
    }

    throw ApiException(message, type: ApiErrorType.http, statusCode: statusCode);
  }
}
