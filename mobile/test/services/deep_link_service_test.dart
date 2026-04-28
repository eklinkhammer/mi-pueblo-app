import 'package:flutter_test/flutter_test.dart';
import 'package:fence/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.extractInviteCode', () {
    test('custom scheme fence://join/CODE returns code', () {
      final uri = Uri.parse('fence://join/ABC123');
      expect(DeepLinkService.extractInviteCode(uri), 'ABC123');
    });

    test('https://fence.app/join/CODE returns code', () {
      final uri = Uri.parse('https://fence.app/join/ABC123');
      expect(DeepLinkService.extractInviteCode(uri), 'ABC123');
    });

    test('fence://join with no code returns null', () {
      final uri = Uri.parse('fence://join');
      expect(DeepLinkService.extractInviteCode(uri), isNull);
    });

    test('wrong host for https returns null', () {
      final uri = Uri.parse('https://other.com/join/CODE');
      expect(DeepLinkService.extractInviteCode(uri), isNull);
    });

    test('unrelated URL returns null', () {
      final uri = Uri.parse('https://google.com/search?q=test');
      expect(DeepLinkService.extractInviteCode(uri), isNull);
    });

    test('wrong custom-scheme host returns null', () {
      final uri = Uri.parse('fence://other/ABC123');
      expect(DeepLinkService.extractInviteCode(uri), isNull);
    });

    test('wrong path on fence.app returns null', () {
      final uri = Uri.parse('https://fence.app/other/ABC123');
      expect(DeepLinkService.extractInviteCode(uri), isNull);
    });
  });
}
