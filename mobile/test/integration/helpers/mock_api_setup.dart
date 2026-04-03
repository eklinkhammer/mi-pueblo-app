import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fence/main.dart';
import 'package:fence/providers/onboarding_provider.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/models/app_location.dart';
import 'package:fence/services/location_service.dart';
import 'package:fence/services/websocket_service.dart';

import '../../helpers/mocks.dart';
import '../../helpers/fakes.dart';
import '../../helpers/test_data.dart';

/// Register fallback values for mocktail argument matchers.
void registerFallbacks() {
  registerFallbackValue(<String, dynamic>{});
}

/// Stub auth-related methods for an unauthenticated start.
void setupUnauthenticatedStubs(MockApiClient mock) {
  when(() => mock.getAccessToken()).thenAnswer((_) async => null);
  when(() => mock.setTokens(any(), any())).thenAnswer((_) async {});
  when(() => mock.clearTokens()).thenAnswer((_) async {});
}

/// Stub auth-related methods so _checkAuth completes as authenticated.
void setupAuthenticatedStubs(MockApiClient mock) {
  when(() => mock.getAccessToken())
      .thenAnswer((_) async => 'test-access-token');
  when(() => mock.getMe()).thenAnswer(
      (_) async => fakeResponse({'user': userJson}));
  when(() => mock.setTokens(any(), any())).thenAnswer((_) async {});
  when(() => mock.clearTokens()).thenAnswer((_) async {});
}

/// Stub login to return valid tokens + user.
void setupLoginStubs(MockApiClient mock) {
  when(() => mock.login(any(), any()))
      .thenAnswer((_) async => fakeResponse(loginResponseJson));
}

/// Stub login to throw (invalid credentials).
void setupLoginFailureStubs(MockApiClient mock) {
  when(() => mock.login(any(), any()))
      .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          statusCode: 401,
          data: {'error': 'invalid_credentials'},
          requestOptions: RequestOptions(path: '/auth/login'),
        ),
      ));
}

/// Stub register to return valid tokens + user.
void setupRegisterStubs(MockApiClient mock) {
  when(() => mock.register(any(), any(), any()))
      .thenAnswer((_) async => fakeResponse(registerResponseJson));
}

/// Stub group-related methods.
void setupGroupStubs(MockApiClient mock, {List<Map<String, dynamic>>? groups}) {
  final groupList = groups ?? [];
  when(() => mock.getGroups())
      .thenAnswer((_) async => fakeResponse({'groups': groupList}));
  when(() => mock.createGroup(any())).thenAnswer((_) async => fakeResponse({
        'group': groupJson,
      }));
  when(() => mock.joinGroup(any())).thenAnswer((_) async => fakeResponse({
        'group': groupJson,
      }));
  when(() => mock.getMembers(any()))
      .thenAnswer((_) async => fakeResponse({
            'members': [groupMemberJson],
          }));
  when(() => mock.createInvite(any()))
      .thenAnswer((_) async => fakeResponse({
            'invite': {'code': 'ABC123'},
          }));
}

/// Stub geofence-related methods.
void setupGeofenceStubs(MockApiClient mock,
    {List<Map<String, dynamic>>? geofences}) {
  final geofenceList = geofences ?? [];
  when(() => mock.getGeofences(any()))
      .thenAnswer((_) async => fakeResponse({'geofences': geofenceList}));
  when(() => mock.getMyGeofences())
      .thenAnswer((_) async => fakeResponse({'geofences': geofenceList}));
  when(() => mock.createGeofence(any(), any()))
      .thenAnswer((_) async => fakeResponse({'geofence': geofenceJson}));
  when(() => mock.deleteGeofence(any(), any()))
      .thenAnswer((_) async => fakeResponse(null, statusCode: 204));
  when(() => mock.getSubscription(any())).thenAnswer(
      (_) async => fakeResponse({'subscription': subscriptionJson}));
  when(() => mock.upsertSubscription(any(), any()))
      .thenAnswer((_) async => fakeResponse({'subscription': subscriptionJson}));
  when(() => mock.createOptOut(any()))
      .thenAnswer((_) async => fakeResponse(null, statusCode: 201));
}

/// Stub location-related methods.
void setupLocationStubs(MockApiClient mock) {
  when(() => mock.getGroupLocations(any()))
      .thenAnswer((_) async => fakeResponse({'locations': [memberLocationJson]}));
  when(() => mock.reportLocation(any()))
      .thenAnswer((_) async => fakeResponse({'status': 'ok'}));
}

/// Pump the full [FenceApp] wrapped in a [ProviderScope] with the given
/// [MockApiClient] and [MockLocationService] overrides.
Future<void> pumpAppWithMocks(
  WidgetTester tester, {
  required MockApiClient apiClient,
  MockLocationService? locationService,
  List<Override> extraOverrides = const [],
}) async {
  final locService = locationService ?? MockLocationService();
  final mockWs = MockWebSocketService();

  // Stub location service methods to avoid crashes
  when(locService.requestPermissions)
      .thenAnswer((_) async => PermissionStatus.granted);
  when(locService.getCurrentPosition).thenAnswer((_) async => null);
  when(locService.startTracking).thenAnswer((_) async {});
  when(locService.stopTracking).thenAnswer((_) async {});
  when(() => locService.onLocation)
      .thenAnswer((_) => const Stream<AppLocation>.empty());
  when(locService.dispose).thenReturn(null);

  // Stub WebSocket service methods
  when(mockWs.connect).thenAnswer((_) async {});
  when(() => mockWs.joinGroup(any())).thenReturn(null);
  when(mockWs.dispose).thenReturn(null);
  when(() => mockWs.messages)
      .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        locationServiceProvider.overrideWithValue(locService),
        websocketServiceProvider.overrideWithValue(mockWs),
        onboardingProvider.overrideWith(
          (_) => OnboardingNotifier.withValue(true),
        ),
        ...extraOverrides,
      ],
      child: const FenceApp(),
    ),
  );

  // Let the initial async providers (auth check, etc.) settle.
  await tester.pumpAndSettle();
}
