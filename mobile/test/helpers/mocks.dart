import 'package:mocktail/mocktail.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/local_notification_service.dart';
import 'package:fence/services/websocket_service.dart';
import 'package:fence/services/location_service.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockWebSocketService extends Mock implements WebSocketService {}

class MockLocationService extends Mock implements LocationService {}

class MockLocalNotificationService extends Mock
    implements LocalNotificationService {
  @override
  Future<void> initialize({void Function(String?)? onSelectNotification}) async {}
}
