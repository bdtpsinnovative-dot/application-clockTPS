import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/screens/project_detail/project_media_url.dart';

void main() {
  test('resolves project R2 avatars to their public HTTPS URL', () {
    expect(
      resolveProjectMediaUrl('r2://avatar.webp', 'https://api.example.com'),
      'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/avatar.webp',
    );
  });

  test('keeps absolute avatar URLs unchanged', () {
    expect(
      resolveProjectMediaUrl(
        'https://cdn.example.com/avatar.webp',
        'https://api.example.com',
      ),
      'https://cdn.example.com/avatar.webp',
    );
  });
}
