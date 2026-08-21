import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AnimatedAppLogo extends StatefulWidget {
  const AnimatedAppLogo({
    super.key,
    this.size = 180,
    this.heroEnabled = true,
    this.isAnimating = false,
  });

  final double size;
  final bool heroEnabled;
  final bool isAnimating;

  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo> {
  @override
  Widget build(BuildContext context) {
    final logoWidget = _LogoImage(size: widget.size);

    if (!widget.heroEnabled) {
      return logoWidget;
    }

    return Hero(
      tag: 'clock-in-tps-logo',
      child: logoWidget,
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302E7CFF),
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.asset(
        'assets/images/app_icon_v2.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
