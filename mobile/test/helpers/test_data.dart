const userJson = {
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'email': 'alice@example.com',
  'display_name': 'Alice',
  'inserted_at': '2025-01-15T10:30:00Z',
};

const groupJson = {
  'id': '660e8400-e29b-41d4-a716-446655440001',
  'name': 'Family',
  'inserted_at': '2025-02-01T08:00:00Z',
};

const groupMemberJson = {
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'display_name': 'Alice',
  'email': 'alice@example.com',
  'role': 'admin',
  'joined_at': '2025-02-01T08:00:00Z',
};

const geofenceJson = {
  'id': '770e8400-e29b-41d4-a716-446655440002',
  'name': 'Home',
  'description': 'Our house',
  'latitude': 37.7749,
  'longitude': -122.4194,
  'radius_meters': 100.0,
  'expires_at': '2025-12-31T23:59:59Z',
  'group_id': '660e8400-e29b-41d4-a716-446655440001',
  'inserted_at': '2025-03-01T12:00:00Z',
};

const geofenceJsonNullDescription = {
  'id': '770e8400-e29b-41d4-a716-446655440002',
  'name': 'Work',
  'description': null,
  'latitude': 37,
  'longitude': -122,
  'radius_meters': 50,
  'expires_at': '2025-12-31T23:59:59Z',
  'group_id': '660e8400-e29b-41d4-a716-446655440001',
  'inserted_at': '2025-03-01T12:00:00Z',
};

const subscriptionJson = {
  'id': '880e8400-e29b-41d4-a716-446655440003',
  'geofence_id': '770e8400-e29b-41d4-a716-446655440002',
  'notify_on_entry': true,
  'notify_on_exit': false,
  'blacklisted_user_ids': <String>[],
  'throttle_seconds': 300,
};

const subscriptionWithBlacklistJson = {
  'id': '880e8400-e29b-41d4-a716-446655440003',
  'geofence_id': '770e8400-e29b-41d4-a716-446655440002',
  'notify_on_entry': true,
  'notify_on_exit': true,
  'blacklisted_user_ids': [
    '550e8400-e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655440099',
  ],
  'throttle_seconds': 600,
};

const nonAdminMemberJson = {
  'id': '550e8400-e29b-41d4-a716-446655440000', // same as userJson
  'display_name': 'Alice',
  'email': 'alice@example.com',
  'role': 'member',
  'joined_at': '2025-02-01T08:00:00Z',
};

const adminOtherMemberJson = {
  'id': '550e8400-e29b-41d4-a716-446655440099',
  'display_name': 'Bob',
  'email': 'bob@example.com',
  'role': 'admin',
  'joined_at': '2025-01-15T08:00:00Z',
};

const memberLocationJson = {
  'user_id': '550e8400-e29b-41d4-a716-446655440000',
  'display_name': 'Alice',
  'latitude': 37.7749,
  'longitude': -122.4194,
  'accuracy': 10.5,
  'speed': 1.2,
  'battery_level': 0.85,
  'updated_at': '2025-03-15T14:30:00Z',
};

const memberLocationNullsJson = {
  'user_id': '550e8400-e29b-41d4-a716-446655440000',
  'display_name': 'Bob',
  'latitude': null,
  'longitude': null,
  'accuracy': null,
  'speed': null,
  'battery_level': null,
  'updated_at': '2025-03-15T14:30:00Z',
};

const loginResponseJson = {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'user': userJson,
};

const registerResponseJson = loginResponseJson;

const anonymousCreateResponseJson = {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'user': {
    'id': '550e8400-e29b-41d4-a716-446655440099',
    'email': null,
    'display_name': 'Anon Creator',
    'inserted_at': '2025-03-01T12:00:00Z',
  },
  'group': {
    'id': '660e8400-e29b-41d4-a716-446655440099',
    'name': 'New Group',
  },
};
