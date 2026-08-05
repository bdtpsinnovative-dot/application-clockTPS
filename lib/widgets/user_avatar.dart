import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_config.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name; // nickname, first name, or display name for initials
  final double radius;
  final BoxBorder? border;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.radius = 20,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveAvatarUrl(avatarUrl);
    final hasAvatar = resolvedUrl.isNotEmpty;
    final isSvg = hasAvatar &&
        (resolvedUrl.toLowerCase().contains('.svg') ||
            resolvedUrl.toLowerCase().contains('/svg'));
    final headers = _buildHeaders(resolvedUrl);

    Widget avatarWidget;
    if (hasAvatar) {
      if (isSvg) {
        avatarWidget = SvgPicture.network(
          resolvedUrl,
          fit: BoxFit.cover,
          headers: headers,
          placeholderBuilder: (BuildContext context) =>
              _buildFallbackText(radius, name),
        );
      } else {
        avatarWidget = Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          headers: headers,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackText(radius, name),
        );
      }
    } else {
      avatarWidget = _buildFallbackText(radius, name);
    }

    Widget child = ClipOval(child: avatarWidget);

    if (border != null) {
      child = Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: border),
        child: child,
      );
    }

    return SizedBox(width: radius * 2, height: radius * 2, child: child);
  }

  /// Domain-specific headers to bypass strict hotlinking rules
  /// without interfering with CORS for Cloudflare R2 or standard servers.
  static Map<String, String>? _buildHeaders(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('pngtree.com')) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://pngtree.com/',
      };
    }
    if (lower.contains('gstatic.com')) {
      return const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    return null;
  }

  static Widget _buildFallbackText(double radius, String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFDBEAFE),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          color: const Color(0xFF1E40AF),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _resolveAvatarUrl(String? url) {
    if (url == null) return '';
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    String finalUrl;
    if (trimmed.startsWith('r2://')) {
      finalUrl = trimmed.replaceFirst(
        'r2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    } else if (trimmed.startsWith('okpr2://')) {
      finalUrl = trimmed.replaceFirst(
        'okpr2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      finalUrl = trimmed;
    } else {
      final apiBase = AppConfig.apiBaseUrl;
      if (trimmed.startsWith('/')) {
        finalUrl = '$apiBase$trimmed';
      } else {
        finalUrl = '$apiBase/$trimmed';
      }
    }
    return Uri.encodeFull(finalUrl);
  }
}
