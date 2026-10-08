import 'package:http/http.dart' as http;

import 'api_client.dart';

class VehicleApi {
  VehicleApi(this._client);
  final ApiClient _client;

  Future<List<dynamic>> list() async {
    final res = await _client.get('/api/v1/vehicles');
    final data = res['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List)
      return List<dynamic>.from(data['data']);
    return const [];
  }

  /// Multipart create/update so the vehicle photo can be uploaded the
  /// same way the web vehicle form does.
  Future<Map<String, dynamic>> save(
    Map<String, dynamic> payload, {
    String? photoPath,
    int? id,
  }) async {
    final uri = Uri.parse(id == null
        ? '${_client.baseUrl}/api/v1/vehicles'
        : '${_client.baseUrl}/api/v1/vehicles/$id');
    final req = http.MultipartRequest(id == null ? 'POST' : 'POST', uri)
      ..headers.addAll(_client.authHeaders);

    payload.forEach((k, v) {
      if (v != null) req.fields[k] = '$v';
    });
    if (id != null) req.fields['_method'] = 'PUT';

    if (photoPath != null) {
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    return _client.decode(body, streamed.statusCode);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> payload) =>
      _client.post('/api/v1/vehicles', payload);

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> payload) =>
      _client.put('/api/v1/vehicles/$id', payload);

  Future<Map<String, dynamic>> delete(int id) =>
      _client.delete('/api/v1/vehicles/$id');

  Future<Map<String, dynamic>> setPrimary(int id) =>
      _client.post('/api/v1/vehicles/$id/set-primary');
}
