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
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the request
            final token = await _storage.read(key: 'access_token');
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
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
      )).post('/auth/refresh', data: {'refresh_token': refreshToken});

      await _storage.write(
          key: 'access_token', value: response.data['access_token']);
      await _storage.write(
          key: 'refresh_token', value: response.data['refresh_token']);
      return true;
    } catch (_) {
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
  Future<Response> register(
      String email, String password, String displayName) {
    return _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
  }

  Future<Response> login(String email, String password) {
    return _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> getMe() => _dio.get('/me');

  Future<Response> updateMe(Map<String, dynamic> data) =>
      _dio.put('/me', data: data);

  Future<Response> registerDeviceToken(String token, String platform) {
    return _dio.post('/me/device-token', data: {
      'token': token,
      'platform': platform,
    });
  }

  // Groups
  Future<Response> getGroups() => _dio.get('/groups');

  Future<Response> createGroup(String name) =>
      _dio.post('/groups', data: {'name': name});

  Future<Response> getGroup(String id) => _dio.get('/groups/$id');

  Future<Response> updateGroup(String id, Map<String, dynamic> data) =>
      _dio.put('/groups/$id', data: data);

  Future<Response> deleteGroup(String id) => _dio.delete('/groups/$id');

  Future<Response> joinGroup(String inviteCode) =>
      _dio.post('/groups/join', data: {'invite_code': inviteCode});

  Future<Response> getMembers(String groupId) =>
      _dio.get('/groups/$groupId/members');

  Future<Response> removeMember(String groupId, String userId) =>
      _dio.delete('/groups/$groupId/members/$userId');

  Future<Response> createInvite(String groupId) =>
      _dio.post('/groups/$groupId/invites');

  // Geofences
  Future<Response> getGeofences(String groupId) =>
      _dio.get('/groups/$groupId/geofences');

  Future<Response> createGeofence(
      String groupId, Map<String, dynamic> data) =>
      _dio.post('/groups/$groupId/geofences', data: data);

  Future<Response> getGeofence(String groupId, String geofenceId) =>
      _dio.get('/groups/$groupId/geofences/$geofenceId');

  Future<Response> updateGeofence(
      String groupId, String geofenceId, Map<String, dynamic> data) =>
      _dio.put('/groups/$groupId/geofences/$geofenceId', data: data);

  Future<Response> deleteGeofence(String groupId, String geofenceId) =>
      _dio.delete('/groups/$groupId/geofences/$geofenceId');

  // Subscriptions
  Future<Response> getSubscription(String geofenceId) =>
      _dio.get('/geofences/$geofenceId/subscription');

  Future<Response> upsertSubscription(
      String geofenceId, Map<String, dynamic> data) =>
      _dio.put('/geofences/$geofenceId/subscription', data: data);

  Future<Response> createOptOut(String geofenceId) =>
      _dio.post('/geofences/$geofenceId/opt-out');

  Future<Response> deleteOptOut(String geofenceId) =>
      _dio.delete('/geofences/$geofenceId/opt-out');

  // Location
  Future<Response> reportLocation(Map<String, dynamic> data) =>
      _dio.post('/location', data: data);

  Future<Response> getGroupLocations(String groupId) =>
      _dio.get('/groups/$groupId/locations');
}
