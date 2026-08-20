import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/services/api_client.dart';

void main() {
  late ApiClient client;

  setUp(() {
    client = ApiClient.instance;
    client.configure(baseUrl: 'http://10.0.2.2:3000');
    client.clearToken();
  });

  tearDown(() {
    client.resetClientForTesting();
    client.clearToken();
  });

  group('GET', () {
    test('décode le JSON et renvoie le corps sur 200', () async {
      client.setClientForTesting(MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/shops');
        return http.Response(jsonEncode({'id': 1, 'name': 'Bazary Be'}), 200);
      }));

      final result = await client.get('/shops');

      expect(result, isA<Map<String, dynamic>>());
      expect(result['name'], 'Bazary Be');
    });

    test('transmet les query params', () async {
      client.setClientForTesting(MockClient((request) async {
        expect(request.url.queryParameters['category'], 'food');
        return http.Response(jsonEncode([]), 200);
      }));

      await client.get('/products', queryParams: {'category': 'food'});
    });

    test('ne convertit jamais globalement les ids numériques (BIGINT)', () async {
      // Le backend peut renvoyer un id BIGINT sous forme de string
      // JSON (voir plan de migration §6/§7). ApiClient ne doit pas le
      // transformer : il doit ressortir tel quel, string inchangée.
      client.setClientForTesting(MockClient((request) async {
        return http.Response(jsonEncode({'id': '9007199254740993'}), 200);
      }));

      final result = await client.get('/orders/9007199254740993');

      expect(result['id'], isA<String>());
      expect(result['id'], '9007199254740993');
    });
  });

  group('POST', () {
    test('envoie le body en JSON avec les bons headers', () async {
      client.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(request.body), {'email': 'a@b.com'});
        return http.Response(jsonEncode({'token': 'abc'}), 201);
      }));

      final result = await client.post('/auth/login', body: {'email': 'a@b.com'});

      expect(result['token'], 'abc');
    });
  });

  group('Headers / token', () {
    test("n'ajoute pas Authorization sans token", () async {
      client.setClientForTesting(MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{}', 200);
      }));

      await client.get('/users/me');
    });

    test('ajoute Authorization Bearer une fois le token défini', () async {
      client.setToken('jwt-123');

      client.setClientForTesting(MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer jwt-123');
        return http.Response('{}', 200);
      }));

      await client.get('/users/me');
    });

    test('clearToken retire le header', () async {
      client.setToken('jwt-123');
      client.clearToken();

      client.setClientForTesting(MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{}', 200);
      }));

      await client.get('/users/me');
    });
  });

  group('Erreurs HTTP', () {
    test('lève ApiException avec le message serveur sur 4xx', () async {
      client.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Email déjà utilisé.'}),
          409,
        );
      }));

      expect(
        () => client.post('/auth/register', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.http)
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', 'Email déjà utilisé.'),
        ),
      );
    });

    test('lève ApiException générique sur 500 sans corps exploitable', () async {
      client.setClientForTesting(MockClient((request) async {
        return http.Response('', 500);
      }));

      expect(
        () => client.get('/shops'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.http)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('lève ApiException de type decode sur JSON invalide', () async {
      client.setClientForTesting(MockClient((request) async {
        return http.Response('<html>pas du json</html>', 200);
      }));

      expect(
        () => client.get('/shops'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.decode),
        ),
      );
    });
  });

  group('Réseau / timeout', () {
    test('lève ApiException de type network sur SocketException', () async {
      client.setClientForTesting(MockClient((request) async {
        throw http.ClientException('Connection refused');
      }));

      expect(
        () => client.get('/shops'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.network),
        ),
      );
    });

    test('lève ApiException de type timeout au-delà du délai configuré', () async {
      client.configure(timeout: const Duration(milliseconds: 50));
      client.setClientForTesting(MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      }));

      expect(
        () => client.get('/shops'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.timeout),
        ),
      );
    });
  });
}
