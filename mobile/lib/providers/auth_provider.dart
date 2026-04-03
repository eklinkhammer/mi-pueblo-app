import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fence/config.dart';
import 'package:fence/models/user.dart';
import 'package:fence/services/api_client.dart';
import 'package:fence/services/notification_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum AuthErrorKey {
  registrationFailed,
  invalidCredentials,
  googleSignInFailed,
  googleSignInCancelled,
  anonymousJoinFailed,
  invalidInviteCode,
  inviteCodeExpired,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final AuthErrorKey? errorKey;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorKey,
  });

  AuthState copyWith({AuthStatus? status, User? user, AuthErrorKey? errorKey}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorKey: errorKey,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  NotificationService? _notificationService;

  AuthNotifier(this._apiClient) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _apiClient.getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final response = await _apiClient.getMe();
      final data = response.data!;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      unawaited(_initNotifications());
    } on Exception catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _initNotifications() async {
    _notificationService?.dispose();
    _notificationService = NotificationService(_apiClient);
    await _notificationService!.initialize();
  }

  Future<void> register(
      String email, String password, String displayName) async {
    try {
      final response =
          await _apiClient.register(email, password, displayName);
      final data = response.data!;
      await _apiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      unawaited(_initNotifications());
    } on Exception catch (_) {
      state = state.copyWith(errorKey: AuthErrorKey.registrationFailed);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.login(email, password);
      final data = response.data!;
      await _apiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      unawaited(_initNotifications());
    } on Exception catch (_) {
      state = state.copyWith(errorKey: AuthErrorKey.invalidCredentials);
    }
  }

  Future<void> joinAsAnonymous(String inviteCode, String displayName) async {
    try {
      final response = await _apiClient.anonymousJoin(inviteCode, displayName);
      final data = response.data!;
      await _apiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      unawaited(_initNotifications());
    } on DioException catch (e) {
      final errorKey = _parseAnonymousJoinError(e);
      state = state.copyWith(errorKey: errorKey);
    } on Exception catch (_) {
      state = state.copyWith(errorKey: AuthErrorKey.anonymousJoinFailed);
    }
  }

  AuthErrorKey _parseAnonymousJoinError(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return AuthErrorKey.anonymousJoinFailed;
    final code = (data['error'] as Map?)?['code'];
    if (code == 'invalid_invite_code') return AuthErrorKey.invalidInviteCode;
    if (code == 'invite_code_expired') return AuthErrorKey.inviteCodeExpired;
    return AuthErrorKey.anonymousJoinFailed;
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleServerClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        state = state.copyWith(errorKey: AuthErrorKey.googleSignInFailed);
        return;
      }

      final response = await _apiClient.googleSignIn(idToken);
      final data = response.data!;
      await _apiClient.setTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      unawaited(_initNotifications());
    } on Exception catch (_) {
      state = state.copyWith(errorKey: AuthErrorKey.googleSignInFailed);
    }
  }

  Future<void> logout() async {
    _notificationService?.dispose();
    _notificationService = null;
    await _apiClient.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
