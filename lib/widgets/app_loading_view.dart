import 'package:flutter/material.dart';

import 'animated_app_logo.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    this.message = 'กำลังโหลด...',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedAppLogo(
          size: compact ? 82 : 130, 
          heroEnabled: false,
          isAnimating: true,
        ),
        SizedBox(height: compact ? 16 : 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF637083),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(
          width: 150,
          child: LinearProgressIndicator(
            minHeight: 4,
            borderRadius: BorderRadius.all(Radius.circular(99)),
          ),
        ),
      ],
    );

    if (compact) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 8,
        child: Padding(padding: const EdgeInsets.all(24), child: content),
      );
    }

    return Scaffold(body: Center(child: content));
  }
}

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: Center(child: AppLoadingView(message: message, compact: true)),
      ),
    );
  }
}
