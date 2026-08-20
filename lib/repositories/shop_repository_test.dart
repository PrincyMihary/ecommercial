import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/models/shop.dart';
import 'package:marketplace_app/repositories/shop_repository.dart';
import 'package:marketplace_app/services/api_client.dart';

/// Tests de non-régression pour [ShopRepository], ajoutés dans le
/// cadre de la migration des consommateurs Shops/Products (Claude
/// 6AB). Le repository lui-même n'a pas été modifié : ces tests
/// couvrent le contrat déjà défini par Claude 5C, sur lequel
/// s'appuient désormais tous les écrans migrés.
void main() {
  late ApiClient apiClient;
  late ShopRepository repository;

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();
    repository = ShopRepository(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  group('getAll', () {
    test('GET /shops et mappe chaque commerce (ids numériques)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/shops');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Bazary Be',
              'description': 'Marché central',
              'address': 'Toamasina',
              'latitude': -18.15,
              'longitude': 49.4,
              'googlePlaceId': 'place-1',
              'category': 'Mode',
              'image': 'shop1.png',
              'ownerId': 7,
            },
          ]),
          200,
        );
      }));

      final shops = await repository.getAll();

      expect(shops, hasLength(1));
      expect(shops.single.id, 1);
      expect(shops.single.ownerId, 7);
      expect(shops.single.name, 'Bazary Be');
      expect(shops.single.hasStructuredLocation, isTrue);
    });
  });

  group('getById', () {
    test('GET /shops/:id mappe un commerce unique', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/shops/5');
        return http.Response(
          jsonEncode({
            'id': 5,
            'name': 'Commerce en ligne',
            'description': '',
            'address': null,
            'category': 'Électronique',
            'image': '',
            'ownerId': 2,
          }),
          200,
        );
      }));

      final shop = await repository.getById(5);

      expect(shop.id, 5);
      expect(shop.hasAddress, isFalse);
      expect(shop.hasStructuredLocation, isFalse);
    });

    test('laisse remonter une ApiException 404 (commerce introuvable)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'NOT_FOUND', 'message': 'Commerce introuvable.'}),
          404,
        );
      }));

      expect(
            () => repository.getById(999),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('getMine', () {
    test('GET /shops/me renvoie 404 si aucun commerce', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/shops/me');
        return http.Response(
          jsonEncode({'code': 'NOT_FOUND', 'message': "Vous n'avez pas de commerce."}),
          404,
        );
      }));

      expect(
            () => repository.getMine(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('create', () {
    test('POST /shops sérialise sans id ni ownerId', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/shops');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('id'), isFalse);
        expect(body.containsKey('ownerId'), isFalse);
        expect(body['name'], 'Nouveau commerce');
        return http.Response(
          jsonEncode({
            'id': 10,
            'name': 'Nouveau commerce',
            'description': 'desc',
            'category': 'Mobilier',
            'image': '',
            'ownerId': 3,
          }),
          201,
        );
      }));

      final shop = await repository.create(const Shop(
        name: 'Nouveau commerce',
        description: 'desc',
        category: 'Mobilier',
        image: '',
      ));

      expect(shop.id, 10);
      expect(shop.ownerId, 3);
    });

    test('laisse remonter une ApiException 409 (commerce déjà possédé)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'SHOP_ERROR',
            'message': 'Vous possédez déjà un commerce.',
          }),
          409,
        );
      }));

      expect(
            () => repository.create(const Shop(
          name: 'X',
          description: '',
          category: 'Mode',
          image: '',
        )),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('delete', () {
    test('DELETE /shops/:id réussi (204/200)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/shops/8');
        return http.Response('', 200);
      }));

      await repository.delete(8);
    });

    test('laisse remonter une ApiException 409 (commandes bloquantes)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'BLOCKING_ORDERS',
            'message': 'Ce commerce est concerné par 2 commande(s) non finalisée(s).',
          }),
          409,
        );
      }));

      expect(
            () => repository.delete(8),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('getBlockingOrders', () {
    test('GET /shops/:id/blocking-orders mappe la liste + toMap() '
        'compatible avec BlockingOrdersScreen', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/shops/8/blocking-orders');
        return http.Response(
          jsonEncode([
            {
              'id': 42,
              'total': 15000.0,
              'status': 'paid',
              'createdAt': '2026-02-01T10:00:00.000Z',
              'userId': 3,
            },
          ]),
          200,
        );
      }));

      final orders = await repository.getBlockingOrders(8);

      expect(orders, hasLength(1));
      expect(orders.single.id, 42);

      // BlockingOrdersScreen lit order['id'], order['status'] et
      // order['created_at'] (colonnes snake_case) : toMap() doit
      // fournir exactement ces clés.
      final map = orders.single.toMap();
      expect(map['id'], 42);
      expect(map['status'], 'paid');
      expect(map['created_at'], '2026-02-01T10:00:00.000Z');
    });
  });
}