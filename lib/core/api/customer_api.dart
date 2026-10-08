import 'package:http/http.dart' as http;

import 'api_client.dart';

class CustomerApi {
  CustomerApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> dashboard() =>
      _client.get('/api/v1/customer/dashboard');

  Future<Map<String, dynamic>> listRequests(
          {String? status, int page = 1, int perPage = 15}) =>
      _client.get('/api/v1/customer/requests', query: {
        if (status != null) 'status': status,
        'page': page,
        'per_page': perPage,
      });

  Future<Map<String, dynamic>> getRequest(int id) =>
      _client.get('/api/v1/customer/requests/$id');

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) =>
      _client.post('/api/v1/customer/requests', payload);

  Future<List<dynamic>> providersNearby({
    required int serviceCategoryId,
    required double lat,
    required double lng,
  }) async {
    final res =
        await _client.get('/api/v1/customer/requests/providers-nearby', query: {
      'service_category_id': serviceCategoryId,
      'lat': lat,
      'lng': lng,
    });
    final data = res['data'];
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> assignProvider(int requestId, int providerId) =>
      _client.post('/api/v1/customer/requests/$requestId/assign',
          {'provider_id': providerId});

  Future<Map<String, dynamic>> autoMatch(int requestId) =>
      _client.post('/api/v1/customer/requests/$requestId/auto-match');

  Future<Map<String, dynamic>> cancelRequest(int id, {String? reason}) =>
      _client.post('/api/v1/customer/requests/$id/cancel', {
        if (reason != null) 'reason': reason,
      });

  Future<Map<String, dynamic>> listOrders({String? status}) =>
      _client.get('/api/v1/customer/orders',
          query: status != null ? {'status': status} : null);

  Future<Map<String, dynamic>> getOrder(int id) =>
      _client.get('/api/v1/customer/orders/$id');

  Future<Map<String, dynamic>> payments() =>
      _client.get('/api/v1/customer/payments');

  /// Profile update; photo paths trigger a multipart request so the
  /// avatar/cover images upload like everywhere else in the app.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data,
      {String? avatarPath, String? coverPath}) async {
    if (avatarPath == null && coverPath == null) {
      return _client.post('/api/v1/customer/profile', data);
    }
    final uri = Uri.parse('${_client.baseUrl}/api/v1/customer/profile');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_client.authHeaders);
    data.forEach((k, v) {
      if (v != null) req.fields[k] = '$v';
    });
    if (avatarPath != null) {
      req.files.add(await http.MultipartFile.fromPath('avatar', avatarPath));
    }
    if (coverPath != null) {
      req.files
          .add(await http.MultipartFile.fromPath('cover_image', coverPath));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    return _client.decode(body, streamed.statusCode);
  }

  Future<Map<String, dynamic>> dashboardData() => dashboard();

  /// Rate the provider after a completed job. One review per request
  /// (the backend rejects duplicates).
  Future<Map<String, dynamic>> submitReview({
    required int requestId,
    required int revieweeId,
    required int rating,
    String? comment,
  }) =>
      _client.post('/api/v1/reviews', {
        'service_request_id': requestId,
        'reviewee_id': revieweeId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      });
}
