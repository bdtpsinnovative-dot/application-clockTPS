import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/app_user.dart';

void main() {
  AppUser userFrom({
    String firstName = 'สมชาย',
    String lastName = 'ใจดี',
    String? avatarUrl = 'r2://avatar.webp',
    bool hasFaceEmbedding = true,
  }) {
    return AppUser.fromJson({
      'id': 'user-id',
      'auth_id': 'auth-id',
      'email': 'employee@example.com',
      'first_name': firstName,
      'last_name': lastName,
      'department': '',
      'position': '',
      'role': 'employee',
      'status': 'active',
      'avatar_url': avatarUrl,
      'has_face_embedding': hasFaceEmbedding,
    });
  }

  test('profile is complete only when every required field exists', () {
    expect(userFrom().isProfileComplete, isTrue);
    expect(userFrom(firstName: '').isProfileComplete, isFalse);
    expect(userFrom(lastName: '').isProfileComplete, isFalse);
    expect(userFrom(avatarUrl: null).isProfileComplete, isFalse);
    expect(userFrom(hasFaceEmbedding: false).isProfileComplete, isFalse);
  });
}
