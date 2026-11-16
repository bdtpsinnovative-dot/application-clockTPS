import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl {
    final raw = dotenv.env['BASE_URL']?.trim() ?? '';
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8080';
      }
      if (host.isNotEmpty && !raw.startsWith('https://')) {
        return 'http://$host:8080';
      }
    }
    return raw;
  }

  static void validate() {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'Missing BASE_URL in .env. Copy .env.example to .env and set the API IP.',
      );
    }
  }
}
