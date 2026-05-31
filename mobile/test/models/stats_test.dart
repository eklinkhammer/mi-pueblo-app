import 'package:flutter_test/flutter_test.dart';
import 'package:fence/models/stats.dart';

void main() {
  group('GeofenceVisitStat.fromJson', () {
    test('parses all fields correctly', () {
      final stat = GeofenceVisitStat.fromJson({
        'geofence_id': 'gf1',
        'geofence_name': 'Work',
        'visit_count': 15,
      });

      expect(stat.geofenceName, 'Work');
      expect(stat.visitCount, 15);
    });
  });

  group('HousemateStat.fromJson', () {
    test('parses with top geofences', () {
      final stat = HousemateStat.fromJson({
        'display_name': 'Alice',
        'top_geofences': [
          {'geofence_id': 'gf1', 'geofence_name': 'Office', 'visit_count': 10},
          {'geofence_id': 'gf2', 'geofence_name': 'Gym', 'visit_count': 5},
        ],
      });

      expect(stat.displayName, 'Alice');
      expect(stat.topGeofences, hasLength(2));
      expect(stat.topGeofences.first.geofenceName, 'Office');
      expect(stat.topGeofences.first.visitCount, 10);
    });

    test('parses with empty top geofences', () {
      final stat = HousemateStat.fromJson({
        'display_name': 'Bob',
        'top_geofences': <Map<String, dynamic>>[],
      });

      expect(stat.displayName, 'Bob');
      expect(stat.topGeofences, isEmpty);
    });
  });

  group('GroupStats.fromJson', () {
    test('parses full response', () {
      final stat = GroupStats.fromJson({
        'group_id': 'g1',
        'group_name': 'Family',
        'home_geofence_name': 'Home',
        'home_visit_count': 47,
        'housemates': [
          {
            'display_name': 'Alice',
            'top_geofences': [
              {'geofence_id': 'gf1', 'geofence_name': 'Work', 'visit_count': 15},
            ],
          },
        ],
        'your_top_geofences': [
          {'geofence_id': 'gf2', 'geofence_name': 'Office', 'visit_count': 22},
        ],
      });

      expect(stat.groupId, 'g1');
      expect(stat.groupName, 'Family');
      expect(stat.homeGeofenceName, 'Home');
      expect(stat.homeVisitCount, 47);
      expect(stat.housemates, hasLength(1));
      expect(stat.housemates.first.displayName, 'Alice');
      expect(stat.yourTopGeofences, hasLength(1));
      expect(stat.yourTopGeofences.first.geofenceName, 'Office');
    });

    test('parses with empty lists', () {
      final stat = GroupStats.fromJson({
        'group_id': 'g1',
        'group_name': 'Family',
        'home_geofence_name': 'Home',
        'home_visit_count': 0,
        'housemates': <Map<String, dynamic>>[],
        'your_top_geofences': <Map<String, dynamic>>[],
      });

      expect(stat.homeVisitCount, 0);
      expect(stat.housemates, isEmpty);
      expect(stat.yourTopGeofences, isEmpty);
    });
  });
}
