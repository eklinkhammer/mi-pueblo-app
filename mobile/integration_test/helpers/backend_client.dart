import 'package:dio/dio.dart';
import 'package:fence/config.dart';

/// Lightweight Dio client for test setup — creates users, groups, invites
/// directly via API without navigating UI.
class BackendTestClient {
  late final Dio _dio;

  BackendTestClient({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// Register a user and return the full response data
  /// (contains user, access_token, refresh_token).
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Create a group. Returns the group data.
  Future<Map<String, dynamic>> createGroup({
    required String token,
    required String name,
  }) async {
    final response = await _dio.post(
      '/groups',
      data: {'name': name},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['group'] as Map<String, dynamic>;
  }

  /// Create an invite for a group. Returns the invite data (code, expires_at).
  Future<Map<String, dynamic>> createInvite({
    required String token,
    required String groupId,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/invites',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['invite'] as Map<String, dynamic>;
  }

  /// Join a group by invite code. Returns the group data.
  Future<Map<String, dynamic>> joinGroup({
    required String token,
    required String inviteCode,
  }) async {
    final response = await _dio.post(
      '/groups/join',
      data: {'invite_code': inviteCode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['group'] as Map<String, dynamic>;
  }

  /// Create a geofence. Returns the geofence data.
  Future<Map<String, dynamic>> createGeofence({
    required String token,
    required String groupId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/geofences',
      data: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['geofence'] as Map<String, dynamic>;
  }
}
