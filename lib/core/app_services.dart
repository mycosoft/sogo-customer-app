import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/customer_api.dart';
import 'api/messages_api.dart';
import 'api/notification_api.dart';
import 'api/service_api.dart';
import 'api/shop_api.dart';
import 'api/vehicle_api.dart';
import 'services/realtime_service.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'SOGO_API_BASE_URL',
  defaultValue: 'https://sogo.co.ug',
);

final ApiClient apiClient = ApiClient(baseUrl: kApiBaseUrl);
final AuthApi authApi = AuthApi(apiClient);
final CustomerApi customerApi = CustomerApi(apiClient);
final ServiceApi serviceApi = ServiceApi(apiClient);
final VehicleApi vehicleApi = VehicleApi(apiClient);
final NotificationApi notificationApi = NotificationApi(apiClient);
final MessagesApi messagesApi = MessagesApi(apiClient);
final ShopApi shopApi = ShopApi(apiClient);

/// Realtime socket (Reverb). Optional upgrade over polling — screens keep
/// their timers, so a dead socket changes nothing.
final RealtimeService realtime = RealtimeService(
  apiBaseUrl: kApiBaseUrl,
  tokenProvider: () async => apiClient.token ?? await apiClient.loadToken(),
);
