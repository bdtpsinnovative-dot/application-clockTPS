import 'package:flutter/material.dart';

// ---------------------------------------------------------
// 1. Shimmer Controller & Wrapper
// ---------------------------------------------------------

class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return non-animated version if reduce motion is preferred.
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: const [
                  Color(0xFFE8EEF6), // Base
                  Color(0xFFF8FBFF), // Highlight
                  Color(0xFFE8EEF6), // Base
                ],
                stops: const [0.1, 0.3, 0.4],
                begin: const Alignment(-1.0, -0.3),
                end: const Alignment(1.0, 0.3),
                transform: _SlidingGradientTransform(slidePercent: _controller.value),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

// ---------------------------------------------------------
// 2. Primitives
// ---------------------------------------------------------

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF6), // Will be overridden by ShaderMask
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF6),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({
    super.key,
    required this.width,
    this.height = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: height, borderRadius: 6.0);
  }
}

class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double height;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final Widget child;

  const SkeletonList({
    super.key,
    this.count = 5,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => child,
    );
  }
}

// ---------------------------------------------------------
// 3. Page-Specific Skeletons
// ---------------------------------------------------------

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const SkeletonCircle(size: 50),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLine(width: 120),
                    SizedBox(height: 8),
                    SkeletonLine(width: 80, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Main Card
            const SkeletonBox(width: double.infinity, height: 160, borderRadius: 20),
            const SizedBox(height: 24),
            // Quick Actions Title
            const SkeletonLine(width: 100, height: 16),
            const SizedBox(height: 16),
            // Quick Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                4,
                (index) => Column(
                  children: const [
                    SkeletonCircle(size: 48),
                    SizedBox(height: 8),
                    SkeletonLine(width: 40, height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Summary Cards
            Row(
              children: const [
                Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 16)),
                SizedBox(width: 16),
                Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class TaskListSkeleton extends StatelessWidget {
  const TaskListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SkeletonList(
        count: 5,
        child: SkeletonCard(
          height: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonLine(width: 150),
                  SkeletonBox(width: 60, height: 24, borderRadius: 12),
                ],
              ),
              const SizedBox(height: 12),
              const SkeletonLine(width: double.infinity, height: 10),
              const SizedBox(height: 8),
              const SkeletonLine(width: 200, height: 10),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonCircle(size: 24),
                  SkeletonLine(width: 80, height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignmentListSkeleton extends StatelessWidget {
  const AssignmentListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 36,
                      borderRadius: 9,
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 36,
                      borderRadius: 9,
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 36,
                      borderRadius: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 46,
                    borderRadius: 12,
                  ),
                ),
                SizedBox(width: 12),
                SkeletonBox(width: 46, height: 46, borderRadius: 12),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                SkeletonBox(width: 70, height: 30, borderRadius: 15),
                SizedBox(width: 8),
                SkeletonBox(width: 96, height: 30, borderRadius: 15),
                SizedBox(width: 8),
                SkeletonBox(width: 82, height: 30, borderRadius: 15),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _AssignmentCardSkeleton(
                compactDetails: index.isOdd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCardSkeleton extends StatelessWidget {
  const _AssignmentCardSkeleton({required this.compactDetails});

  final bool compactDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compactDetails ? 116 : 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonLine(width: 184, height: 15)),
              const SizedBox(width: 12),
              SkeletonBox(
                width: compactDetails ? 58 : 72,
                height: 24,
                borderRadius: 12,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonLine(
            width: compactDetails ? 180 : double.infinity,
            height: 10,
          ),
          if (!compactDetails) ...[
            const SizedBox(height: 7),
            const SkeletonLine(width: 230, height: 10),
          ],
          const Spacer(),
          const Row(
            children: [
              SkeletonCircle(size: 24),
              SizedBox(width: 7),
              SkeletonLine(width: 76, height: 10),
              Spacer(),
              SkeletonLine(width: 92, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class TaskBoardSkeleton extends StatelessWidget {
  const TaskBoardSkeleton({
    super.key,
    this.viewportFraction = 0.90,
  });

  final double viewportFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth * viewportFraction;
        return SkeletonShimmer(
          child: ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  2,
                  (columnIndex) => SizedBox(
                    width: columnWidth,
                    child: _BoardColumnSkeleton(
                      alternate: columnIndex.isOdd,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardColumnSkeleton extends StatelessWidget {
  const _BoardColumnSkeleton({required this.alternate});

  final bool alternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(5, 8, 5, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SkeletonLine(
                  width: alternate ? 92 : 128,
                  height: 15,
                ),
                const Spacer(),
                const SkeletonCircle(size: 26),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(9),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (_, index) => Container(
                height: index == 1 ? 106 : 88,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(
                      width: index.isEven ? 152 : 118,
                      height: 13,
                    ),
                    const SizedBox(height: 9),
                    const SkeletonLine(width: double.infinity, height: 9),
                    if (index == 1) ...[
                      const SizedBox(height: 6),
                      const SkeletonLine(width: 142, height: 9),
                    ],
                    const Spacer(),
                    const Row(
                      children: [
                        SkeletonCircle(size: 20),
                        SizedBox(width: 6),
                        SkeletonLine(width: 54, height: 9),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationListSkeleton extends StatelessWidget {
  const NotificationListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SkeletonList(
        count: 7,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonCircle(size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLine(width: double.infinity, height: 14),
                    SizedBox(height: 6),
                    SkeletonLine(width: 180, height: 12),
                    SizedBox(height: 8),
                    SkeletonLine(width: 60, height: 10),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class RequestListSkeleton extends StatelessWidget {
  const RequestListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SkeletonList(
        count: 5,
        child: SkeletonCard(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SkeletonBox(width: 4, height: 60, borderRadius: 2),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonLine(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonLine(width: 100, height: 12),
                    SizedBox(height: 8),
                    SkeletonLine(width: 80, height: 12),
                  ],
                ),
              ),
              const SkeletonBox(width: 80, height: 28, borderRadius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeListSkeleton extends StatelessWidget {
  const EmployeeListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SkeletonList(
        count: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const SkeletonCircle(size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLine(width: 150, height: 16),
                    SizedBox(height: 6),
                    SkeletonLine(width: 100, height: 12),
                  ],
                ),
              ),
              const SkeletonBox(width: 60, height: 24, borderRadius: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceHistorySkeleton extends StatelessWidget {
  const AttendanceHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          // Filter Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Expanded(child: SkeletonBox(width: double.infinity, height: 48, borderRadius: 12)),
                SizedBox(width: 12),
                SkeletonBox(width: 48, height: 48, borderRadius: 12),
              ],
            ),
          ),
          // Summary Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (index) => Column(
                  children: const [
                    SkeletonLine(width: 40, height: 20),
                    SizedBox(height: 4),
                    SkeletonLine(width: 60, height: 12),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // List Area
          Expanded(
            child: SkeletonList(
              count: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const SkeletonBox(width: 40, height: 40, borderRadius: 8),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonLine(width: 120, height: 14),
                          SizedBox(height: 6),
                          SkeletonLine(width: 80, height: 12),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        SkeletonLine(width: 60, height: 14),
                        SizedBox(height: 6),
                        SkeletonLine(width: 60, height: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleManagementListSkeleton extends StatelessWidget {
  const SimpleManagementListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SkeletonList(
        count: 6,
        child: SkeletonCard(
          height: 80,
          child: Row(
            children: [
              const SkeletonBox(width: 48, height: 48, borderRadius: 8),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonLine(width: 160, height: 16),
                    SizedBox(height: 8),
                    SkeletonLine(width: 100, height: 12),
                  ],
                ),
              ),
              const SkeletonBox(width: 32, height: 32, borderRadius: 16),
            ],
          ),
        ),
      ),
    );
  }
}
