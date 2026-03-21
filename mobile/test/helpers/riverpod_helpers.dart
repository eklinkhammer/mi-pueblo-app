import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/services/api_client.dart';
import 'mocks.dart';

ProviderContainer createContainer({MockApiClient? apiClient}) {
  final mock = apiClient ?? MockApiClient();
  return ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mock),
    ],
  );
}
