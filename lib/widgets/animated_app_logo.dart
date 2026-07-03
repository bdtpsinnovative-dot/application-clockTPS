import 'package:flutter/material.dart';

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

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
    _scale = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _turns = Tween<double>(
      begin: -0.008,
      end: 0.008,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedAppLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat(reverse: true);
      } else {
        _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animatedLogo = ScaleTransition(
      scale: _scale,
      child: RotationTransition(
        turns: _turns,
        child: _LogoImage(size: widget.size),
      ),
    );

    if (!widget.heroEnabled) {
      return animatedLogo;
    }

    return Hero(
      tag: 'clock-in-tps-logo',
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            final flightCurve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return RotationTransition(
              turns: Tween<double>(
                begin: 0,
                end: flightDirection == HeroFlightDirection.push ? 0.08 : -0.08,
              ).animate(flightCurve),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.9,
                  end: 1.05,
                ).animate(flightCurve),
                child: _LogoImage(size: widget.size),
              ),
            );
          },
      child: animatedLogo,
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
          BoxShadow(color: Color(0x5518C7B7), blurRadius: 28, spreadRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/clock_in_tps_logo.png',
        fit: BoxFit.cover,
      ),
    );
  }
}
