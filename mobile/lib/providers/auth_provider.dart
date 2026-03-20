import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/models/user.dart';
import 'package:fence/services/api_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

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
      final user = User.fromJson(response.data['user']);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register(
      String email, String password, String displayName) async {
    try {
      final response =
          await _apiClient.register(email, password, displayName);
      await _apiClient.setTokens(
        response.data['access_token'],
        response.data['refresh_token'],
      );
      final user = User.fromJson(response.data['user']);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(error: 'Registration failed');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.login(email, password);
      await _apiClient.setTokens(
        response.data['access_token'],
        response.data['refresh_token'],
      );
      final user = User.fromJson(response.data['user']);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(error: 'Invalid email or password');
    }
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
