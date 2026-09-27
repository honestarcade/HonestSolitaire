/// A child that fades in when it first appears, and inside it a part that
/// rises into place — the pause and win cards over their scrim (#105).
/// Under [AppMotion.reduced] it fades without the rise; under
/// [AppMotion.none] the first frame is the final one.
library;

import 'package:flutter/widgets.dart';

import '../motion.dart';

class Appear extends StatefulWidget {
  const Appear({
    super.key,
    required this.motion,
    required this.duration,
    this.rise = 0,
    this.curve = riseCurve,
    required this.child,
  });

  final AppMotion motion;

  /// The design's duration; [motion] scales it.
  final Duration duration;

  /// How far a [Risen] descendant starts below its place, in logical
  /// pixels; only at full motion.
  final double rise;
  final Curve curve;
  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final duration = widget.motion.ui(widget.duration);
    _controller = AnimationController(vsync: this, duration: duration);
    _t = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
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
    final rise = widget.motion == AppMotion.full ? widget.rise : 0.0;
    return _AppearScope(
      animation: _t,
      rise: rise,
      child: FadeTransition(opacity: _t, child: widget.child),
    );
  }
}

class _AppearScope extends InheritedWidget {
  const _AppearScope({
    required this.animation,
    required this.rise,
    required super.child,
  });

  final Animation<double> animation;
  final double rise;

  @override
  bool updateShouldNotify(_AppearScope old) =>
      old.animation != animation || old.rise != rise;
}

/// Translates its child up into place as the enclosing [Appear] fades in.
class Risen extends StatelessWidget {
  const Risen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppearScope>();
    if (scope == null || scope.rise == 0) return child;
    return AnimatedBuilder(
      animation: scope.animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, scope.rise * (1 - scope.animation.value)),
        child: child,
      ),
      child: child,
    );
  }
}
