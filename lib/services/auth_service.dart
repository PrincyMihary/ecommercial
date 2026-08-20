import 'package:flutter/foundation.dart';

import '../database/database_helper.dart' show AuthException;
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import 'api_client.dart';

/// Service singleton de session utilisateur.
///
/// Depuis la migration REST (voir plan de migration, Claude 5B),
/// [AuthService] ne fait plus lui-même d'accès aux données : il
/// délègue entièrement à [AuthRepository] et se contente de porter
/// l'état/session réactif de l'application, comme avant.
///
/// Basé sur [ChangeNotifier], même pattern que `CartService` : les
/// écrans s'abonnent via `addListener` / `removeListener` pour se
/// reconstruire automatiquement à chaque connexion/déconnexion.
///
/// [AuthException] reste la même classe qu'avant la migration
/// (définie dans `database/database_helper.dart` et déjà attrapée par
/// `LoginScreen`/`SignupScreen`/`ShopFormScreen`) : ce service se
/// contente de traduire les [ApiException] renvoyées par
/// [AuthRepository] vers cette même [AuthException], pour que les
/// écrans existants n'aient rien à changer.
///
/// IMPORTANT : comme avant la migration, la session vit uniquement en
/// mémoire (via le token conservé par [ApiClient]) — fermer et
/// rouvrir l'application ramène l'utilisateur en état "visiteur".
/// C'est un choix volontaire non revu par cette tâche (voir note en
/// bas de fichier) : le projet ne dépend pas encore d'un mécanisme de
/// persistance disque (ex: `shared_preferences`).
class AuthService extends ChangeNotifier {
  AuthService._({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  static final AuthService instance = AuthService._();

  final AuthRepository _repository;

  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  /// Crée un compte et connecte immédiatement l'utilisateur.
  ///
  /// La validation (nom obligatoire, email de forme plausible, mot de
  /// passe suffisamment long) et le hash du mot de passe sont
  /// désormais entièrement de la responsabilité du backend (voir
  /// `auth.controller.ts`, qui reproduit à l'identique les messages
  /// utilisés ici auparavant) : ce service ne les duplique plus.
  /// Lève une [AuthException] avec un message déjà adapté à
  /// l'affichage en cas de problème (y compris email déjà utilisé).
  Future<User> signUp({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    try {
      final user = await _repository.register(
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        password: password,
      );
      _currentUser = user;
      notifyListeners();
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Connecte un utilisateur existant. Lève une [AuthException] si
  /// l'email est inconnu ou si le mot de passe ne correspond pas — le
  /// backend renvoie volontairement un message générique sur ce point
  /// précis (voir `auth.controller.ts`), repris tel quel ici.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.login(
        email: email.trim().toLowerCase(),
        password: password,
      );
      _currentUser = user;
      notifyListeners();
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Déconnecte l'utilisateur courant (aucun effet si déjà
  /// déconnecté). Purement local : le backend n'expose pas
  /// d'endpoint de déconnexion (JWT sans état), voir
  /// [AuthRepository.clearLocalSession].
  void logout() {
    if (_currentUser == null) return;
    _currentUser = null;
    _repository.clearLocalSession();
    notifyListeners();
  }
}

// Note de conception :
//
// La session vit uniquement en mémoire (comme CartService, et comme
// avant la migration REST). Fermer et rouvrir l'application ramène
// donc l'utilisateur en état "visiteur", même s'il avait un compte.
// Persister la session (ex: rester connecté après redémarrage)
// demanderait soit d'ajouter une dépendance de stockage clé-valeur
// (ex: shared_preferences, absente du projet), soit de la simuler
// autrement. Hors périmètre de cette migration : à valider séparément
// si une persistance de session est souhaitée.
