import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Plays once per app launch, never when switching tabs or returning to Today.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({required this.child, super.key});

  final Widget child;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _finished = true);
    }
  });
  bool _started = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _finished = true;
      _controller.stop();
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Starting Rize',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final entrance = Curves.easeOutCubic.transform(
                (_controller.value / 0.7).clamp(0.0, 1.0),
              );
              final glow = 1 - (2 * _controller.value - 1).abs();
              return Opacity(
                opacity: entrance,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.8 + 0.2 * entrance,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.charcoalGrey,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.burntOrange.withValues(
                                alpha: 0.25 * glow,
                              ),
                              blurRadius: 40 * glow,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 72,
                          height: 72,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rize',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.burntOrange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
