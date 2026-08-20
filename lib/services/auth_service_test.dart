import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/database/database_helper.dart' show AuthException;
import 'package:marketplace_app/services/api_client.dart';
import 'package:marketplace_app/services/auth_service.dart';

void main() {
  late ApiClient apiClient;
  late AuthService auth;

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();

    // AuthService est un singleton (comme avant la migration) : on
    // repart d'un état déconnecté avant chaque test.
    auth = AuthService.instance;
    if (auth.isLoggedIn) {
      auth.logout();
    }
  });

  tearDown(() {
    if (auth.isLoggedIn) {
      auth.logout();
    }
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  test('isLoggedIn est faux et currentUser est null avant toute connexion', () {
    expect(auth.isLoggedIn, isFalse);
    expect(auth.currentUser, isNull);
  });

  group('login', () {
    test('met à jour currentUser/isLoggedIn et notifie les listeners sur succès', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/auth/login');
        return http.Response(
          jsonEncode({
            'token': 'jwt-abc',
            'user': {
              'id': 1,
              'fullName': 'Carol',
              'email': 'carol@example.com',
              'phone': null,
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          }),
          200,
        );
      }));

      var notified = false;
      auth.addListener(() => notified = true);

      final user = await auth.login(email: 'carol@example.com', password: 'secret123');

      expect(user.email, 'carol@example.com');
      expect(auth.currentUser?.email, 'carol@example.com');
      expect(auth.isLoggedIn, isTrue);
      expect(notified, isTrue);
      expect(apiClient.token, 'jwt-abc');
    });

    test('lève une AuthException avec le message serveur et laisse currentUser null sur échec', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'AUTH_ERROR', 'message': 'Email ou mot de passe incorrect.'}),
          400,
        );
      }));

      Object? caught;
      try {
        await auth.login(email: 'carol@example.com', password: 'wrong');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<AuthException>());
      expect((caught as AuthException).message, 'Email ou mot de passe incorrect.');
      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('traduit une erreur réseau (serveur injoignable) en AuthException', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        throw http.ClientException('Connection refused');
      }));

      Object? caught;
      try {
        await auth.login(email: 'carol@example.com', password: 'secret123');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<AuthException>());
      expect(auth.isLoggedIn, isFalse);
    });
  });

  group('signUp', () {
    test('crée un compte, connecte l\'utilisateur et stocke le token', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/auth/register');
        expect(jsonDecode(request.body), {
          'fullName': 'Alice Rasoa',
          'email': 'alice@example.com',
          'phone': '0341234567',
          'password': 'secret123',
        });
        return http.Response(
          jsonEncode({
            'token': 'jwt-signup',
            'user': {
              'id': 2,
              'fullName': 'Alice Rasoa',
              'email': 'alice@example.com',
              'phone': '0341234567',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          }),
          201,
        );
      }));

      final user = await auth.signUp(
        fullName: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
        password: 'secret123',
      );

      expect(user.id, 2);
      expect(auth.isLoggedIn, isTrue);
      expect(apiClient.token, 'jwt-signup');
    });

    test('lève une AuthException 409 "email déjà utilisé" sans connecter', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'AUTH_ERROR', 'message': 'Cet email est déjà utilisé.'}),
          409,
        );
      }));

      Object? caught;
      try {
        await auth.signUp(fullName: 'Alice', email: 'dup@example.com', password: 'secret123');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<AuthException>());
      expect((caught as AuthException).message, 'Cet email est déjà utilisé.');
      expect(auth.isLoggedIn, isFalse);
    });
  });

  group('logout', () {
    test('vide currentUser, oublie le token et notifie les listeners', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'token': 'jwt-abc',
            'user': {
              'id': 1,
              'fullName': 'Carol',
              'email': 'carol@example.com',
              'phone': null,
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          }),
          200,
        );
      }));
      await auth.login(email: 'carol@example.com', password: 'secret123');
      expect(auth.isLoggedIn, isTrue);

      var notified = false;
      auth.addListener(() => notified = true);

      auth.logout();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
      expect(apiClient.token, isNull);
      expect(notified, isTrue);
    });

    test("n'a aucun effet si déjà déconnecté (pas de notification)", () {
      var notified = false;
      auth.addListener(() => notified = true);

      auth.logout();

      expect(notified, isFalse);
    });
  });
}
