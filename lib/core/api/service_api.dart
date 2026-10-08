import 'api_client.dart';

class ServiceApi {
  ServiceApi(this._client);
  final ApiClient _client;

  Future<List<dynamic>> categories() async {
    final res = await _client.get('/api/v1/service-categories');
    return List<dynamic>.from(res['data'] as List? ?? const []);
  }

  Future<List<dynamic>> nearbyProviders({
    required double lat,
    required double lng,
    int? serviceCategoryId,
  }) async {
    final res = await _client.get('/api/v1/providers/nearby', query: {
      'lat': lat,
      'lng': lng,
      if (serviceCategoryId != null) 'service_category_id': serviceCategoryId,
    });
    return List<dynamic>.from((res['data'] as List?) ?? const []);
  }
}
