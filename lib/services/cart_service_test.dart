import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/models/product.dart';
import 'package:marketplace_app/services/api_client.dart';
import 'package:marketplace_app/services/auth_service.dart';
import 'package:marketplace_app/services/cart_service.dart';

/// Tests de non-régression pour [CartService], migré (Claude 6C) de
/// `DatabaseHelper`/SQLite vers `CartRepository`/REST.
///
/// [CartService] et [AuthService] sont des singletons qui utilisent
/// par défaut `ApiClient.instance` : comme pour `auth_service_test`,
/// on simule le backend en injectant un `http.Client` de test dans
/// `ApiClient.instance` plutôt qu'en construisant de nouvelles
/// instances de service.
void main() {
  late ApiClient apiClient;
  late AuthService auth;
  late CartService cart;

  Map<String, dynamic> _rawItem({
    int productId = 1,
    String productName = 'Chaise',
    num price = 25000,
    String image = 'chaise.png',
    int quantity = 1,
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

  http.Response _loginResponse(int userId) => http.Response(
    jsonEncode({
      'token': 'jwt-abc',
      'user': {
        'id': userId,
        'fullName': 'Carol',
        'email': 'carol@example.com',
        'phone': null,
        'createdAt': '2026-01-01T00:00:00.000Z',
      },
    }),
    200,
  );

  /// Attend que [cart] ait terminé un cycle de chargement asynchrone
  /// (déclenché ici par la réaction automatique de [CartService] aux
  /// changements de [AuthService]).
  Future<void> _waitForCartToSettle() async {
    if (!cart.isLoading) return;
    final completer = Completer<void>();
    void listener() {
      if (!cart.isLoading) completer.complete();
    }

    cart.addListener(listener);
    await completer.future;
    cart.removeListener(listener);
  }

  setUp(() {
    apiClient = ApiClient.instance;
    apiClient.configure(baseUrl: 'http://10.0.2.2:3000');
    apiClient.clearToken();

    auth = AuthService.instance;
    if (auth.isLoggedIn) auth.logout();

    cart = CartService.instance;
    cart.clearSession();
  });

  tearDown(() async {
    apiClient.setClientForTesting(MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/cart') {
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }
      return http.Response('', 204);
    }));
    if (auth.isLoggedIn) auth.logout();
    cart.clearSession();
    apiClient.resetClientForTesting();
    apiClient.clearToken();
  });

  group('panier visiteur (non connecté)', () {
    test('addProduct/removeProduct/setQuantity restent en mémoire, sans appel réseau', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        fail('Aucun appel réseau attendu pour un panier visiteur : ${request.method} ${request.url.path}');
      }));

      final product = Product(
        id: 1,
        shopId: 1,
        name: 'Chaise',
        description: 'Chaise en bois',
        price: 25000,
        stock: 4,
        category: 'Mobilier',
        image: 'chaise.png',
      );

      final added = await cart.addProduct(product, quantity: 2);
      expect(added, 2);
      expect(cart.isPersisted, isFalse);
      expect(cart.items, hasLength(1));
      expect(cart.items.first.quantity, 2);

      await cart.setQuantity(1, 3);
      expect(cart.items.first.quantity, 3);

      await cart.removeProduct(1);
      expect(cart.isEmpty, isTrue);
    });

    test("le stock plafonne l'ajout et renvoie la quantité réellement ajoutée", () async {
      apiClient.setClientForTesting(MockClient((request) async {
        fail('Aucun appel réseau attendu pour un panier visiteur.');
      }));

      final product = Product(
        id: 2,
        shopId: 1,
        name: 'Table',
        description: 'Table basse',
        price: 50000,
        stock: 2,
        category: 'Mobilier',
        image: 'table.png',
      );

      final added = await cart.addProduct(product, quantity: 5);
      expect(added, 2);
      expect(cart.items.first.quantity, 2);
    });
  });

  group('connexion : fusion du panier visiteur puis bascule REST', () {
    test('les articles visiteurs sont envoyés via POST /cart/items puis le panier est rechargé via GET /cart',
            () async {
          final product = Product(
            id: 1,
            shopId: 1,
            name: 'Chaise',
            description: 'Chaise en bois',
            price: 25000,
            stock: 4,
            category: 'Mobilier',
            image: 'chaise.png',
          );

          apiClient.setClientForTesting(MockClient((request) async {
            fail('Aucun appel réseau attendu avant connexion.');
          }));
          await cart.addProduct(product, quantity: 2);
          expect(cart.isPersisted, isFalse);

          final addCalls = <Map<String, dynamic>>[];
          apiClient.setClientForTesting(MockClient((request) async {
            if (request.url.path == '/auth/login') {
              return _loginResponse(9);
            }
            if (request.method == 'POST' && request.url.path == '/cart/items') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              addCalls.add(body);
              return http.Response(jsonEncode({'added': body['quantity'], 'items': <dynamic>[]}), 200);
            }
            if (request.method == 'GET' && request.url.path == '/cart') {
              return http.Response(
                jsonEncode([_rawItem(productId: 1, quantity: 2)]),
                200,
              );
            }
            fail('Appel inattendu : ${request.method} ${request.url.path}');
          }));

          await auth.login(email: 'carol@example.com', password: 'secret123');
          await _waitForCartToSettle();

          expect(addCalls, hasLength(1));
          expect(addCalls.first['productId'], 1);
          expect(addCalls.first['quantity'], 2);

          expect(cart.isPersisted, isTrue);
          expect(cart.items, hasLength(1));
          expect(cart.items.first.productId, 1);
          expect(cart.items.first.quantity, 2);
        });

    test('logout vide uniquement la mémoire locale (aucun appel réseau)', () async {
      apiClient.setClientForTesting(MockClient((request) async {
        if (request.url.path == '/auth/login') return _loginResponse(9);
        if (request.method == 'GET' && request.url.path == '/cart') {
          return http.Response(jsonEncode(<dynamic>[]), 200);
        }
        fail('Appel inattendu : ${request.method} ${request.url.path}');
      }));

      await auth.login(email: 'carol@example.com', password: 'secret123');
      await _waitForCartToSettle();
      expect(cart.isPersisted, isTrue);

      apiClient.setClientForTesting(MockClient((request) async {
        fail('logout ne doit déclencher aucun appel réseau côté panier.');
      }));
      auth.logout();

      expect(cart.isPersisted, isFalse);
      expect(cart.isEmpty, isTrue);
    });
  });

  group('utilisateur connecté : opérations via CartRepository (REST)', () {
    Future<void> _loginAsUser9() async {
      apiClient.setClientForTesting(MockClient((request) async {
        if (request.url.path == '/auth/login') return _loginResponse(9);
        if (request.method == 'GET' && request.url.path == '/cart') {
          return http.Response(jsonEncode(<dynamic>[]), 200);
        }
        fail('Appel inattendu pendant la connexion : ${request.method} ${request.url.path}');
      }));
      await auth.login(email: 'carol@example.com', password: 'secret123');
      await _waitForCartToSettle();
    }

    test('addProduct appelle POST /cart/items et applique directement le panier renvoyé', () async {
      await _loginAsUser9();

      final product = Product(
        id: 4,
        shopId: 1,
        name: 'Lampe',
        description: 'Lampe de bureau',
        price: 15000,
        stock: 10,
        category: 'Déco',
        image: 'lampe.png',
      );

      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/cart/items');
        return http.Response(
          jsonEncode({
            'added': 1,
            'items': [_rawItem(productId: 4, productName: 'Lampe', price: 15000, quantity: 1, stock: 10)],
          }),
          200,
        );
      }));

      final added = await cart.addProduct(product, quantity: 1);

      expect(added, 1);
      expect(cart.items, hasLength(1));
      expect(cart.items.first.productId, 4);
    });

    test('setQuantity appelle PUT /cart/items/:productId et applique le panier renvoyé', () async {
      await _loginAsUser9();

      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/cart/items/4');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['quantity'], 3);
        return http.Response(
          jsonEncode([_rawItem(productId: 4, quantity: 3)]),
          200,
        );
      }));

      await cart.setQuantity(4, 3);

      expect(cart.items, hasLength(1));
      expect(cart.items.first.quantity, 3);
    });

    test('removeProduct appelle DELETE /cart/items/:productId et applique le panier renvoyé', () async {
      await _loginAsUser9();

      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/cart/items/4');
        return http.Response(jsonEncode(<dynamic>[]), 200);
      }));

      await cart.removeProduct(4);

      expect(cart.isEmpty, isTrue);
    });

    test('clear appelle DELETE /cart puis vide le panier local', () async {
      await _loginAsUser9();

      var deleteCalled = false;
      apiClient.setClientForTesting(MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/cart');
        deleteCalled = true;
        return http.Response('', 204);
      }));

      await cart.clear();

      expect(deleteCalled, isTrue);
      expect(cart.isEmpty, isTrue);
    });
  });
}