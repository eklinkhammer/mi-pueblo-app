import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fence/config.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Send device locale for backend localization
        final locale = PlatformDispatcher.instance.locale;
        options.headers['Accept-Language'] = locale.toLanguageTag();
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch<Map<String, dynamic>>(error.requestOptions);
            handler.resolve(response);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
      )).post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': refreshToken});

      final data = response.data!;
      await _storage.write(
          key: 'access_token', value: data['access_token'] as String);
      await _storage.write(
          key: 'refresh_token', value: data['refresh_token'] as String);
      return true;
    } on Exception catch (_) {
      return false;
    }
  }

  Future<void> setTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  // Auth
  Future<Response<Map<String, dynamic>>> register(
      String email, String password, String displayName) {
    return _dio.post<Map<String, dynamic>>('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
  }

  Future<Response<Map<String, dynamic>>> login(String email, String password) {
    return _dio.post<Map<String, dynamic>>('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response<Map<String, dynamic>>> googleSignIn(String idToken) {
    return _dio.post<Map<String, dynamic>>('/auth/google', data: {
      'id_token': idToken,
    });
  }

  Future<Response<Map<String, dynamic>>> getMe() =>
      _dio.get<Map<String, dynamic>>('/me');

  Future<Response<Map<String, dynamic>>> updateMe(
          Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>('/me', data: data);

  Future<Response<Map<String, dynamic>>> registerDeviceToken(
      String token, String platform) {
    return _dio.post<Map<String, dynamic>>('/me/device-token', data: {
      'token': token,
      'platform': platform,
    });
  }

  // Groups
  Future<Response<Map<String, dynamic>>> getGroups() =>
      _dio.get<Map<String, dynamic>>('/groups');

  Future<Response<Map<String, dynamic>>> createGroup(String name) =>
      _dio.post<Map<String, dynamic>>('/groups', data: {'name': name});

  Future<Response<Map<String, dynamic>>> getGroup(String id) =>
      _dio.get<Map<String, dynamic>>('/groups/$id');

  Future<Response<Map<String, dynamic>>> updateGroup(
          String id, Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>('/groups/$id', data: data);

  Future<Response<Map<String, dynamic>>> deleteGroup(String id) =>
      _dio.delete<Map<String, dynamic>>('/groups/$id');

  Future<Response<Map<String, dynamic>>> joinGroup(String inviteCode) =>
      _dio.post<Map<String, dynamic>>('/groups/join',
          data: {'invite_code': inviteCode});

  Future<Response<Map<String, dynamic>>> getMembers(String groupId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/members');

  Future<Response<Map<String, dynamic>>> removeMember(
          String groupId, String userId) =>
      _dio.delete<Map<String, dynamic>>('/groups/$groupId/members/$userId');

  Future<Response<Map<String, dynamic>>> createInvite(String groupId) =>
      _dio.post<Map<String, dynamic>>('/groups/$groupId/invites');

  // Notification preferences
  Future<Response<Map<String, dynamic>>> getNotificationPreferences(
          String groupId) =>
      _dio.get<Map<String, dynamic>>(
          '/groups/$groupId/notification-preferences');

  Future<Response<Map<String, dynamic>>> updateNotificationPreferences(
          String groupId, Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>(
          '/groups/$groupId/notification-preferences',
          data: data);

  Future<Response<Map<String, dynamic>>> getMemberPreferences(
          String groupId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/member-preferences');

  Future<Response<Map<String, dynamic>>> upsertMemberPreference(
          String groupId, String subjectId, Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>(
          '/groups/$groupId/member-preferences/$subjectId',
          data: data);

  // Geofences
  Future<Response<Map<String, dynamic>>> getGeofences(String groupId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/geofences');

  Future<Response<Map<String, dynamic>>> createGeofence(
          String groupId, Map<String, dynamic> data) =>
      _dio.post<Map<String, dynamic>>('/groups/$groupId/geofences', data: data);

  Future<Response<Map<String, dynamic>>> getGeofence(
          String groupId, String geofenceId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/geofences/$geofenceId');

  Future<Response<Map<String, dynamic>>> updateGeofence(
          String groupId, String geofenceId, Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>(
          '/groups/$groupId/geofences/$geofenceId',
          data: data);

  Future<Response<Map<String, dynamic>>> deleteGeofence(
          String groupId, String geofenceId) =>
      _dio.delete<Map<String, dynamic>>(
          '/groups/$groupId/geofences/$geofenceId');

  // Home geofence (residents)
  Future<Response<Map<String, dynamic>>> claimHome(
          String groupId, String geofenceId) =>
      _dio.post<Map<String, dynamic>>(
          '/groups/$groupId/geofences/$geofenceId/claim-home');

  Future<Response<Map<String, dynamic>>> unclaimHome(
          String groupId, String geofenceId) =>
      _dio.delete<Map<String, dynamic>>(
          '/groups/$groupId/geofences/$geofenceId/claim-home');

  // Visibility
  Future<Response<Map<String, dynamic>>> getVisibilityPairs(String groupId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/visibility');

  Future<Response<Map<String, dynamic>>> updateVisibility(
          String groupId, String userId, {required bool visible}) =>
      _dio.put<Map<String, dynamic>>('/groups/$groupId/visibility/$userId',
          data: {'visible': visible});

  // Subscriptions
  Future<Response<Map<String, dynamic>>> getSubscription(
          String geofenceId) =>
      _dio.get<Map<String, dynamic>>('/geofences/$geofenceId/subscription');

  Future<Response<Map<String, dynamic>>> upsertSubscription(
          String geofenceId, Map<String, dynamic> data) =>
      _dio.put<Map<String, dynamic>>(
          '/geofences/$geofenceId/subscription',
          data: data);

  Future<Response<Map<String, dynamic>>> createOptOut(String geofenceId) =>
      _dio.post<Map<String, dynamic>>('/geofences/$geofenceId/opt-out');

  Future<Response<Map<String, dynamic>>> deleteOptOut(String geofenceId) =>
      _dio.delete<Map<String, dynamic>>('/geofences/$geofenceId/opt-out');

  // Geocoding
  Future<Response<Map<String, dynamic>>> geocode(String query) =>
      _dio.get<Map<String, dynamic>>('/geocode', queryParameters: {'q': query});

  // Location
  Future<Response<Map<String, dynamic>>> reportLocation(
          Map<String, dynamic> data) =>
      _dio.post<Map<String, dynamic>>('/location', data: data);

  // Geofence monitoring
  Future<Response<Map<String, dynamic>>> getMyGeofences() =>
      _dio.get<Map<String, dynamic>>('/my-geofences');

  Future<Response<Map<String, dynamic>>> reportGeofenceEvent(
          Map<String, dynamic> data) =>
      _dio.post<Map<String, dynamic>>('/geofence-events', data: data);

  Future<Response<Map<String, dynamic>>> getGroupLocations(String groupId) =>
      _dio.get<Map<String, dynamic>>('/groups/$groupId/locations');
}
