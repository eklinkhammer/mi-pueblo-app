import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/user.dart';
import '../helpers/test_data.dart';

void main() {
  group('User.fromJson', () {
    test('parses all fields correctly', () {
      final user = User.fromJson(Map<String, dynamic>.from(userJson));

      expect(user.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(user.email, 'alice@example.com');
      expect(user.displayName, 'Alice');
      expect(user.insertedAt, DateTime.utc(2025, 1, 15, 10, 30));
    });

    test('parses ISO8601 DateTime', () {
      final json = Map<String, dynamic>.from(userJson);
      json['inserted_at'] = '2025-06-15T20:45:30.123Z';

      final user = User.fromJson(json);
      expect(user.insertedAt, DateTime.utc(2025, 6, 15, 20, 45, 30, 123));
    });
  });
}
