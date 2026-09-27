// A test host that disposes its controller when the tree is torn down.
//
// flutter_test checks for pending timers right after unmounting the widget
// tree and before any tearDown callback runs, so a controller whose clock is
// running must be disposed by the tree itself.
import 'package:flutter/widgets.dart';
import 'package:honest_solitaire/ui/game/game_controller.dart';

class DisposingHost extends StatefulWidget {
  const DisposingHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final GameController controller;
  final Widget child;

  @override
  State<DisposingHost> createState() => _DisposingHostState();
}

class _DisposingHostState extends State<DisposingHost> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
