import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    setUp(() {
      dotenv.testLoad(fileInput: '');
    });

    test('should throw StateError when BASE_URL is missing', () {
      expect(() => AppConfig.validate(), throwsA(isA<StateError>()));
    });

    test('should pass validation when BASE_URL is present', () {
      dotenv.testLoad(fileInput: 'BASE_URL=https://api.tps.co.th');
      expect(() => AppConfig.validate(), returnsNormally);
      expect(AppConfig.apiBaseUrl, equals('https://api.tps.co.th'));
    });
  });
}
