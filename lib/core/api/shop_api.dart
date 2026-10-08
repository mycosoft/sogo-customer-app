import 'dart:async';

import 'api_client.dart';

/// Shop discovery (providers/shops + products) + cart + checkout.
class ShopApi {
  ShopApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> shops({
    String? q,
    String? providerType,
    int? serviceCategoryId,
    String? city,
    String? district,
    double? lat,
    double? lng,
    int page = 1,
  }) =>
      _client.get('/api/v1/shops', query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (providerType != null) 'provider_type': providerType,
        if (serviceCategoryId != null) 'service_category_id': serviceCategoryId,
        if (city != null && city.isNotEmpty) 'city': city,
        if (district != null && district.isNotEmpty) 'district': district,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'page': page,
      });

  Future<Map<String, dynamic>> shopDetail(int id) =>
      _client.get('/api/v1/shops/$id');

  Future<Map<String, dynamic>> products({
    String? q,
    int? categoryId,
    int? providerId,
    String sort = 'popular',
    int page = 1,
  }) =>
      _client.get('/api/v1/products', query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (categoryId != null) 'category_id': categoryId,
        if (providerId != null) 'provider_id': providerId,
        'sort': sort,
        'page': page,
      });

  Future<Map<String, dynamic>> productDetail(int id) =>
      _client.get('/api/v1/products/$id');

  Future<Map<String, dynamic>> productCategories() =>
      _client.get('/api/v1/product-categories');

  Future<Map<String, dynamic>> cart() => _client.get('/api/v1/cart');

  Future<Map<String, dynamic>> cartAdd(
          {required int productId, int quantity = 1}) =>
      _client.post('/api/v1/cart/items',
          {'product_id': productId, 'quantity': quantity});

  Future<Map<String, dynamic>> cartUpdateItem(
      {required int itemId, required int quantity}) async {
    try {
      return await _client.put('/api/v1/cart/items/$itemId',
          {'quantity': quantity}).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw Exception('Network timeout - check your connection and try again');
    }
  }

  Future<Map<String, dynamic>> cartRemoveItem(int itemId) async {
    try {
      return await _client
          .delete('/api/v1/cart/items/$itemId')
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw Exception('Network timeout - check your connection and try again');
    }
  }

  Future<Map<String, dynamic>> cartClear() => _client.delete('/api/v1/cart');

  Future<Map<String, dynamic>> checkout({
    required String deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryPhone,
    String? notes,
    String paymentMethod = 'cash',
  }) =>
      _client.post('/api/v1/customer/orders/checkout', {
        'delivery_address': deliveryAddress,
        if (deliveryLat != null) 'delivery_lat': deliveryLat,
        if (deliveryLng != null) 'delivery_lng': deliveryLng,
        if (deliveryPhone != null && deliveryPhone.isNotEmpty)
          'delivery_phone': deliveryPhone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'payment_method': paymentMethod,
      });

  /// Pay later (wallet) for an unpaid order.
  Future<Map<String, dynamic>> payOrder(int orderId) => _client.post(
      '/api/v1/customer/orders/$orderId/pay', {'payment_method': 'wallet'});
}
