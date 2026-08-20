import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/repositories/cart_repository.dart';
import 'package:marketplace_app/services/api_client.dart';

/// Tests de non-régression pour [CartRepository], ajoutés dans le
/// cadre de la migration Cart (Claude 6C). Le repository lui-même
/// n'a pas été modifié : ces tests couvrent le contrat déjà défini
/// par Claude 5C, sur lequel s'appuie désormais [CartService].
void main() {
  late ApiClient apiClient;
  late CartRepository repository;

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();
    repository = CartRepository(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  Map<String, dynamic> _rawItem({
    int productId = 1,
    String productName = 'Chaise',
    num price = 25000,
    String image = 'chaise.png',
    int quantity = 2,
    int stock = 4,
  }) {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'image': image,
      'quantity': quantity,
      'stock': stock,
    };
  }

  group('getItems', () {
    test('GET /cart mappe chaque ligne (ids numériques)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/cart');
        return http.Response(jsonEncode([_rawItem()]), 200);
      }));

      final items = await repository.getItems();

      expect(items, hasLength(1));
      expect(items.first.productId, 1);
      expect(items.first.quantity, 2);
      expect(items.first.price, 25000.0);
    });

    test('laisse remonter une ApiException sur erreur serveur', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({'code': 'INTERNAL', 'message': 'Erreur serveur.'}),
          500,
        );
      }));

      expect(
            () => repository.getItems(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('getItemCount', () {
    test('GET /cart/count renvoie le compteur', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.url.path, '/cart/count');
        return http.Response(jsonEncode({'count': 5}), 200);
      }));

      final count = await repository.getItemCount();

      expect(count, 5);
    });
  });

  group('addItem', () {
    test('POST /cart/items transmet productId/quantity et mappe le résultat', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/cart/items');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['productId'], 7);
        expect(body['quantity'], 3);
        return http.Response(
          jsonEncode({
            'added': 3,
            'items': [_rawItem(productId: 7, quantity: 3)],
          }),
          200,
        );
      }));

      final result = await repository.addItem(7, 3);

      expect(result.added, 3);
      expect(result.items, hasLength(1));
      expect(result.items.first.productId, 7);
      expect(result.items.first.quantity, 3);
    });

    test('added == 0 (stock épuisé) reste correctement mappé', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        return http.Response(jsonEncode({'added': 0, 'items': <dynamic>[]}), 200);
      }));

      final result = await repository.addItem(7, 3);

      expect(result.added, 0);
      expect(result.items, isEmpty);
    });
  });

  group('updateItemQuantity', () {
    test('PUT /cart/items/:productId transmet la quantité et mappe le panier', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/cart/items/7');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['quantity'], 5);
        return http.Response(
          jsonEncode([_rawItem(productId: 7, quantity: 5)]),
          200,
        );
      }));

      final items = await repository.updateItemQuantity(7, 5);

      expect(items, hasLength(1));
      expect(items.first.quantity, 5);
    });
  });

  group('removeItem', () {
    test('DELETE /cart/items/:productId mappe le panier restant', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/cart/items/7');
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }));

      final items = await repository.removeItem(7);

      expect(items, isEmpty);
    });
  });

  group('clear', () {
    test('DELETE /cart appelle bien la route de vidage', () async {
      var called = false;
      apiClient.setClientForTesting(MockClient((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/cart');
        return http.Response('', 204);
      }));

      await repository.clear();

      expect(called, isTrue);
    });
  });
}