import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/user.dart';

/// Service singleton de session utilisateur, entièrement en mémoire
/// (Étape 1 : pas de persistance de session entre redémarrages —
/// voir note en bas de fichier).
///
/// Basé sur [ChangeNotifier], même pattern que `CartService` : les
/// écrans s'abonnent via `addListener` / `removeListener` pour se
/// reconstruire automatiquement à chaque connexion/déconnexion.
///
/// IMPORTANT : aucune connexion n'est requise pour utiliser
/// l'application. Ce service ne bloque rien par lui-même — c'est aux
/// écrans concernés de consulter `isLoggedIn` / `currentUser` s'ils
/// veulent restreindre une action (aucune restriction de ce type
/// n'est encore mise en place à cette étape).
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  static const int _minPasswordLength = 6;

  /// Crée un compte et connecte immédiatement l'utilisateur.
  ///
  /// Validations minimales côté service (en plus de toute validation
  /// de formulaire côté UI) : champs obligatoires non vides, email de
  /// forme plausible, mot de passe suffisamment long. Lève une
  /// [AuthException] avec un message déjà adapté à l'affichage en cas
  /// de problème (y compris email déjà utilisé, remonté depuis
  /// [DatabaseHelper.createUser]).
  Future<User> signUp({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final trimmedName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedPhone = phone?.trim();

    if (trimmedName.isEmpty) {
      throw const AuthException('Le nom est obligatoire.');
    }
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const AuthException('Adresse email invalide.');
    }
    if (password.length < _minPasswordLength) {
      throw const AuthException(
        'Le mot de passe doit contenir au moins $_minPasswordLength caractères.',
      );
    }

    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);

    final id = await DatabaseHelper.instance.createUser({
      'full_name': trimmedName,
      'email': normalizedEmail,
      'phone': (trimmedPhone == null || trimmedPhone.isEmpty) ? null : trimmedPhone,
      'password_hash': hash,
      'password_salt': salt,
      'created_at': DateTime.now().toIso8601String(),
    });

    final user = User(
      id: id,
      fullName: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone,
      createdAt: DateTime.now().toIso8601String(),
    );

    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Connecte un utilisateur existant. Lève une [AuthException] si
  /// l'email est inconnu ou si le mot de passe ne correspond pas — le
  /// message reste volontairement générique sur ce point précis pour
  /// ne pas indiquer si c'est l'email ou le mot de passe qui est en
  /// cause (bonne pratique minimale, sans complexifier le prototype).
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final row = await DatabaseHelper.instance.getUserByEmail(normalizedEmail);
    if (row == null) {
      throw const AuthException('Email ou mot de passe incorrect.');
    }

    final salt = row['password_salt'] as String? ?? '';
    final expectedHash = row['password_hash'] as String? ?? '';
    final actualHash = _hashPassword(password, salt);

    if (actualHash != expectedHash) {
      throw const AuthException('Email ou mot de passe incorrect.');
    }

    final user = User.fromMap(row);
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Déconnecte l'utilisateur courant (aucun effet si déjà déconnecté).
  void logout() {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
  }

  bool _looksLikeEmail(String value) {
    // Validation volontairement simple (prototype) : présence d'un
    // '@' et d'un '.' après, sans regex exhaustive RFC 5322.
    final at = value.indexOf('@');
    if (at <= 0) return false;
    final dot = value.indexOf('.', at);
    return dot > at + 1 && dot < value.length - 1;
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}

// Note de conception (Étape 1) :
//
// La session vit uniquement en mémoire (comme CartService). Fermer et
// rouvrir l'application ramène donc l'utilisateur en état "visiteur",
// même s'il avait un compte. C'est un choix volontaire pour rester
// minimal à cette étape : persister la session (ex: rester connecté
// après redémarrage) demanderait soit d'ajouter une dépendance de
// stockage clé-valeur (ex: shared_preferences, absente du projet),
// soit de la simuler autrement. À valider avec vous si une
// persistance de session est souhaitée dès maintenant ou plus tard.