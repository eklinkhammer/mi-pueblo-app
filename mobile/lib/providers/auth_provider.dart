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
      final data = response.data!;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on Exception catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
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
    } on Exception catch (_) {
      state = state.copyWith(error: 'Registration failed');
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
    } on Exception catch (_) {
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
