import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marketplace_app/models/order.dart';
import 'package:marketplace_app/models/order_item.dart';
import 'package:marketplace_app/repositories/order_repository.dart';
import 'package:marketplace_app/services/api_client.dart';

void main() {
  late OrderRepository repo;

  setUp(() {
    repo = OrderRepository();
  });

  tearDown(() => ApiClient.instance.resetClientForTesting());

  http.Response json(Object body, [int code = 200]) =>
      http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

  test('checkout() poste paymentMethod et decode order+items', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/checkout');
      expect(jsonDecode(request.body), {'paymentMethod': 'yas'});
      return json({
        'order': {'id': 1, 'total': 5000, 'status': 'paid', 'createdAt': '2026-08-20T00:00:00Z'},
        'items': [
          {'id': 1, 'orderId': 1, 'productId': 2, 'productName': 'Riz', 'quantity': 2, 'price': 2500}
        ],
      });
    }));

    final result = await repo.checkout('yas');
    expect(result.order.id, 1);
    expect(result.items.single.productName, 'Riz');
  });

  test('checkout() propage ApiException 409 (panier vide/stock)', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      return json({'message': 'Le panier est vide.'}, 409);
    }));

    expect(() => repo.checkout('visa'), throwsA(isA<ApiException>()));
  });

  test('myOrders() GET /orders decode liste', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders');
      return json([
        {'id': 1, 'total': 1000, 'status': 'pending', 'createdAt': '2026-08-20T00:00:00Z', 'itemCount': 3}
      ]);
    }));

    final orders = await repo.myOrders();
    expect(orders.single.itemCount, 3);
  });

  test('ordersForMyShop() GET /orders/shop decode shopItemCount/shopTotal', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/shop');
      return json([
        {
          'id': 1, 'total': 1000, 'status': 'paid', 'createdAt': '2026-08-20T00:00:00Z',
          'shopItemCount': 2, 'shopTotal': 400.0
        }
      ]);
    }));

    final orders = await repo.ordersForMyShop();
    expect(orders.single.shopItemCount, 2);
    expect(orders.single.shopTotal, 400.0);
  });

  test('getDetail() GET /orders/:id decode isBuyer/isMerchant', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/7');
      return json({
        'order': {'id': 7, 'total': 900, 'status': 'preparing', 'createdAt': '2026-08-20T00:00:00Z'},
        'items': [],
        'isBuyer': false,
        'isMerchant': true,
      });
    }));

    final detail = await repo.getDetail(7);
    expect(detail.isBuyer, false);
    expect(detail.isMerchant, true);
  });

  test('getItemsForMyShop() GET /orders/:id/items/shop decode liste', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/7/items/shop');
      return json([
        {'id': 1, 'orderId': 7, 'productId': 3, 'productName': 'Savon', 'quantity': 1, 'price': 1500}
      ]);
    }));

    final items = await repo.getItemsForMyShop(7);
    expect(items.single.productId, 3);
  });

  test('advanceStatus() PATCH /orders/:id/status decode order+transitions', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/7/status');
      expect(jsonDecode(request.body), {'status': 'ready'});
      return json({
        'order': {'id': 7, 'total': 900, 'status': 'ready', 'createdAt': '2026-08-20T00:00:00Z'},
        'availableTransitions': ['completed', 'refunded'],
      });
    }));

    final result = await repo.advanceStatus(7, 'ready');
    expect(result.order.status, 'ready');
    expect(result.availableTransitions, ['completed', 'refunded']);
  });

  test('refund() POST /orders/:id/refund decode order', () async {
    ApiClient.instance.setClientForTesting(MockClient((request) async {
      expect(request.url.path, '/orders/7/refund');
      return json({'id': 7, 'total': 900, 'status': 'refunded', 'createdAt': '2026-08-20T00:00:00Z'});
    }));

    final order = await repo.refund(7);
    expect(order.status, 'refunded');
  });

  test('Order.fromApiJson : champs optionnels absents -> null', () {
    final order = Order.fromApiJson({
      'id': 1, 'total': 100, 'status': 'pending', 'createdAt': '2026-08-20T00:00:00Z',
    });
    expect(order.itemCount, isNull);
    expect(order.shopItemCount, isNull);
    expect(order.shopTotal, isNull);
  });

  test('OrderItem.fromApiJson : productId/shopId nullable', () {
    final item = OrderItem.fromApiJson({
      'id': 1, 'orderId': 1, 'productName': 'Produit', 'quantity': 1, 'price': 100,
    });
    expect(item.productId, isNull);
    expect(item.shopId, isNull);
  });
}