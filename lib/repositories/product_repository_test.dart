import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/models/product.dart';
import 'package:marketplace_app/repositories/product_repository.dart';
import 'package:marketplace_app/services/api_client.dart';

/// Tests de non-régression pour [ProductRepository], ajoutés dans le
/// cadre de la migration des consommateurs Shops/Products (Claude
/// 6AB). Le repository lui-même n'a pas été modifié : ces tests
/// couvrent le contrat déjà défini par Claude 5C, sur lequel
/// s'appuient désormais tous les écrans migrés.
void main() {
  late ApiClient apiClient;
  late ProductRepository repository;

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();
    repository = ProductRepository(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  group('getById', () {
    test('GET /products/:id mappe un produit (ids numériques)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/products/3');
        return http.Response(
          jsonEncode({
            'id': 3,
            'shopId': 1,
            'name': 'Chaise',
            'description': 'Chaise en bois',
            'price': 25000,
            'stock': 4,
            'category': 'Mobilier',
            'image': 'chaise.png',
            'model3d': null,
          }),
          200,
        );
      }));

      final product = await repository.getById(3);

      expect(product.id, 3);
      expect(product.shopId, 1);
      expect(product.price, 25000.0);
    });

    test('laisse remonter une ApiException 404 (produit introuvable)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'NOT_FOUND', 'message': 'Produit introuvable.'}),
          404,
        );
      }));

      expect(
            () => repository.getById(999),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('getByShop', () {
    test('GET /shops/:shopId/products mappe la liste', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/shops/1/products');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'shopId': 1,
              'name': 'Table',
              'description': '',
              'price': 90000,
              'stock': 2,
              'category': 'Mobilier',
              'image': '',
            },
          ]),
          200,
        );
      }));

      final products = await repository.getByShop(1);

      expect(products, hasLength(1));
      expect(products.single.shopId, 1);
    });
  });

  group('search', () {
    test("n'envoie 'category' que si différent de vide, transmet 'q'", () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/products/search');
        expect(request.url.queryParameters['q'], 'chaise');
        expect(request.url.queryParameters['category'], 'Mobilier');
        return http.Response(jsonEncode([]), 200);
      }));

      final products = await repository.search(query: 'chaise', category: 'Mobilier');
      expect(products, isEmpty);
    });

    test("transmet 'Tout' tel quel (pas de réinterprétation ici)", () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.queryParameters['category'], 'Tout');
        return http.Response(jsonEncode([]), 200);
      }));

      await repository.search(category: 'Tout');
    });
  });

  group('create', () {
    test('POST /products sérialise sans id ni shopId', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/products');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('id'), isFalse);
        expect(body.containsKey('shopId'), isFalse);
        expect(body['name'], 'Nouveau produit');
        return http.Response(
          jsonEncode({
            'id': 11,
            'shopId': 4,
            'name': 'Nouveau produit',
            'description': '',
            'price': 5000,
            'stock': 10,
            'category': 'Mode',
            'image': '',
          }),
          201,
        );
      }));

      final product = await repository.create(const Product(
        shopId: 0,
        name: 'Nouveau produit',
        description: '',
        price: 5000,
        stock: 10,
        category: 'Mode',
        image: '',
      ));

      expect(product.id, 11);
      expect(product.shopId, 4);
    });

    test('laisse remonter une ApiException 409 (pas de commerce)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'SHOP_ERROR',
            'message':
            "Vous devez d'abord créer votre commerce avant d'ajouter un produit.",
          }),
          409,
        );
      }));

      expect(
            () => repository.create(const Product(
          shopId: 0,
          name: 'X',
          description: '',
          price: 0,
          stock: 0,
          category: 'Mode',
          image: '',
        )),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('delete', () {
    test('laisse remonter une ApiException 409 (commandes bloquantes)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'BLOCKING_ORDERS',
            'message': 'Ce produit apparaît dans 1 commande(s) non finalisée(s).',
          }),
          409,
        );
      }));

      expect(
            () => repository.delete(3),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  group('getBlockingOrders', () {
    test('GET /products/:id/blocking-orders mappe la liste + toMap() '
        'compatible avec BlockingOrdersScreen', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/products/3/blocking-orders');
        return http.Response(
          jsonEncode([
            {
              'id': 21,
              'total': 5000.0,
              'status': 'confirmed',
              'createdAt': '2026-03-01T08:00:00.000Z',
              'userId': 9,
            },
          ]),
          200,
        );
      }));

      final orders = await repository.getBlockingOrders(3);

      expect(orders, hasLength(1));
      final map = orders.single.toMap();
      expect(map['id'], 21);
      expect(map['status'], 'confirmed');
      expect(map['created_at'], '2026-03-01T08:00:00.000Z');
    });
  });
}