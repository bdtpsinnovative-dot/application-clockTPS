import '../../config/app_config.dart';

class SalesConfig {
  const SalesConfig._();

  static String get apiBaseUrl =>
      AppConfig.apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static Uri endpoint(String path) {
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    // If the path already has a prefix like api/, use it directly,
    // otherwise route under /api/pos/
    if (cleanPath.startsWith('api/')) {
      return Uri.parse('$apiBaseUrl/$cleanPath');
    }
    return Uri.parse('$apiBaseUrl/api/pos/$cleanPath');
  }
}
