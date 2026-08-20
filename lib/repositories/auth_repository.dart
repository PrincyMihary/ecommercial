import '../models/user.dart';
import '../services/api_client.dart';

/// Accès aux données Auth via l'API REST du backend.
///
/// Couvre uniquement les opérations réellement exposées par le
/// backend (voir `src/modules/auth/auth.routes.ts`) :
///
///   - `POST /auth/register`
///   - `POST /auth/login`
///   - `GET  /users/me`
///
/// Il n'existe PAS d'endpoint `/auth/logout` côté backend (une
/// session ici n'est qu'un JWT sans état côté serveur) : ce
/// repository n'implémente donc aucun appel réseau de déconnexion,
/// conformément au plan de migration §3. [clearLocalSession] existe
/// uniquement pour que [AuthService] n'ait pas à connaître
/// [ApiClient] directement — elle ne fait rien d'autre qu'oublier le
/// token en mémoire.
///
/// Le stockage du token réutilise [ApiClient] (déjà responsable du
/// token en mémoire, voir `ApiClient.setToken`/`token`/`clearToken`) :
/// le projet ne possède pas de dépendance de persistance disque
/// (ex: `shared_preferences`), donc créer une classe `TokenStorage`
/// séparée aurait dupliqué un mécanisme déjà existant sans rien
/// apporter (voir plan de migration §5 — "ne pas créer une deuxième
/// architecture de token si le projet en possède déjà une").
class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  /// Crée un compte via `POST /auth/register` et stocke le token
  /// renvoyé. Lève une [ApiException] (network/timeout/decode/http)
  /// telle quelle en cas de problème — c'est à l'appelant (typiquement
  /// [AuthService]) de la traduire pour l'UI si besoin.
  Future<User> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final response = await _api.post('/auth/register', body: {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    return _handleAuthResponse(response);
  }

  /// Connecte un utilisateur existant via `POST /auth/login` et
  /// stocke le token renvoyé.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _handleAuthResponse(response);
  }

  /// Récupère le profil de l'utilisateur actuellement authentifié via
  /// `GET /users/me` (nécessite qu'un token ait déjà été défini sur
  /// [ApiClient], voir [register]/[login]).
  Future<User> currentUser() async {
    final response = await _api.get('/users/me');
    return User.fromApiJson(response as Map<String, dynamic>);
  }

  /// Oublie le token en mémoire. Purement local : aucun appel réseau
  /// (le backend n'expose pas d'endpoint de déconnexion — voir
  /// docstring de la classe).
  void clearLocalSession() {
    _api.clearToken();
  }

  User _handleAuthResponse(dynamic response) {
    final map = response as Map<String, dynamic>;
    final token = map['token'] as String?;
    final userJson = map['user'] as Map<String, dynamic>?;

    if (token == null || token.isEmpty || userJson == null) {
      throw const ApiException(
        'Réponse du serveur invalide.',
        type: ApiErrorType.decode,
      );
    }

    _api.setToken(token);
    return User.fromApiJson(userJson);
  }
}
