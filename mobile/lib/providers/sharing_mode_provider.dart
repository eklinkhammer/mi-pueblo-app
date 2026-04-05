import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/services/api_client.dart';

final sharingModeProvider = AsyncNotifierProvider.family<SharingModeNotifier,
    String, String>(SharingModeNotifier.new);

class SharingModeNotifier extends FamilyAsyncNotifier<String, String> {
  @override
  Future<String> build(String arg) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.getSharingMode(arg);
    return response.data!['sharing_mode'] as String;
  }

  Future<void> setMode(String mode) async {
    final apiClient = ref.read(apiClientProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await apiClient.updateSharingMode(arg, mode);
      return response.data!['sharing_mode'] as String;
    });
  }
}
