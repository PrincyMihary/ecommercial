import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/repositories/auth_repository.dart';
import 'package:marketplace_app/services/api_client.dart';

void main() {
  late ApiClient apiClient;
  late AuthRepository repository;

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();
    repository = AuthRepository(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  group('register', () {
    test('poste sur /auth/register et stocke le token reçu', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/register');
        expect(jsonDecode(request.body), {
          'fullName': 'Alice Rasoa',
          'email': 'alice@example.com',
          'phone': '0341234567',
          'password': 'secret123',
        });
        return http.Response(
          jsonEncode({
            'token': 'jwt-token-1',
            'user': {
              'id': 1,
              'fullName': 'Alice Rasoa',
              'email': 'alice@example.com',
              'phone': '0341234567',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          }),
          201,
        );
      }));

      final user = await repository.register(
        fullName: 'Alice Rasoa',
        email: 'alice@example.com',
        phone: '0341234567',
        password: 'secret123',
      );

      expect(user.id, 1);
      expect(user.fullName, 'Alice Rasoa');
      expect(user.email, 'alice@example.com');
      expect(apiClient.token, 'jwt-token-1');
    });

    test('laisse remonter une ApiException 409 (email déjà utilisé)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'AUTH_ERROR', 'message': 'Cet email est déjà utilisé.'}),
          409,
        );
      }));

      expect(
        () => repository.register(
          fullName: 'Alice',
          email: 'dup@example.com',
          password: 'secret123',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', 'Cet email est déjà utilisé.'),
        ),
      );
      expect(apiClient.token, isNull);
    });
  });

  group('login', () {
    test('poste sur /auth/login et stocke le token reçu', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body), {
          'email': 'carol@example.com',
          'password': 'secret123',
        });
        return http.Response(
          jsonEncode({
            'token': 'jwt-token-2',
            'user': {
              'id': 2,
              'fullName': 'Carol',
              'email': 'carol@example.com',
              'phone': null,
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          }),
          200,
        );
      }));

      final user = await repository.login(email: 'carol@example.com', password: 'secret123');

      expect(user.id, 2);
      expect(user.email, 'carol@example.com');
      expect(apiClient.token, 'jwt-token-2');
    });

    test('laisse remonter une ApiException sur identifiants invalides', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'AUTH_ERROR', 'message': 'Email ou mot de passe incorrect.'}),
          400,
        );
      }));

      expect(
        () => repository.login(email: 'carol@example.com', password: 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Email ou mot de passe incorrect.'),
        ),
      );
      expect(apiClient.token, isNull);
    });

    test('lève une ApiException de type network si le serveur est injoignable', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        throw http.ClientException('Connection refused');
      }));

      expect(
        () => repository.login(email: 'carol@example.com', password: 'secret123'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.network)),
      );
    });
  });

  group('currentUser', () {
    test('lit /users/me avec le token courant', () async {
      apiClient.setToken('jwt-token-3');
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/users/me');
        expect(request.headers['Authorization'], 'Bearer jwt-token-3');
        return http.Response(
          jsonEncode({
            'id': 3,
            'fullName': 'Dina',
            'email': 'dina@example.com',
            'phone': null,
            'createdAt': '2026-01-01T00:00:00.000Z',
          }),
          200,
        );
      }));

      final user = await repository.currentUser();

      expect(user.id, 3);
      expect(user.email, 'dina@example.com');
    });

    test('lève une ApiException 401 si le token est invalide/expiré', () async {
      apiClient.setToken('invalid-token');
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'UNAUTHORIZED', 'message': 'Session invalide ou expirée.'}),
          401,
        );
      }));

      expect(
        () => repository.currentUser(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('clearLocalSession', () {
    test('oublie le token sans appel réseau', () async {
      apiClient.setToken('jwt-token-4');
      apiClient.setClientForTesting(MockClient((request) async {
        fail('clearLocalSession ne doit déclencher aucune requête HTTP.');
      }));

      repository.clearLocalSession();

      expect(apiClient.token, isNull);
    });
  });
}
