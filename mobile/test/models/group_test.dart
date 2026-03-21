import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/group.dart';
import '../helpers/test_data.dart';

void main() {
  group('Group.fromJson', () {
    test('parses all fields correctly', () {
      final group = Group.fromJson(Map<String, dynamic>.from(groupJson));

      expect(group.id, '660e8400-e29b-41d4-a716-446655440001');
      expect(group.name, 'Family');
      expect(group.insertedAt, DateTime.utc(2025, 2, 1, 8));
    });
  });

  group('GroupMember.fromJson', () {
    test('parses all fields correctly', () {
      final member =
          GroupMember.fromJson(Map<String, dynamic>.from(groupMemberJson));

      expect(member.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(member.displayName, 'Alice');
      expect(member.email, 'alice@example.com');
      expect(member.role, 'admin');
      expect(member.joinedAt, DateTime.utc(2025, 2, 1, 8));
    });
  });
}
