const _projectR2PublicBase =
    'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/';

String resolveProjectMediaUrl(String? rawUrl, String baseUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) return '';
  if (value.startsWith('r2://')) {
    return value.replaceFirst('r2://', _projectR2PublicBase);
  }
  if (value.startsWith('okpr2://')) {
    return value.replaceFirst('okpr2://', _projectR2PublicBase);
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('/')) return '$baseUrl$value';
  return baseUrl.isEmpty ? value : '$baseUrl/$value';
}
