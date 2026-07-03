import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl => dotenv.env['BASE_URL']?.trim() ?? '';

  static void validate() {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'Missing BASE_URL in .env. Copy .env.example to .env and set the API IP.',
      );
    }
  }
}
