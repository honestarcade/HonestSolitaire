/// One board-level pointer router: taps (#75), and later drags and
/// long-presses (#77), all from raw pointer events so single taps are never
/// delayed.
library;

import 'package:flutter/widgets.dart';

import '../game/game_controller.dart';
import 'board_layout.dart';

/// Movement under this many logical pixels is still a tap.
const double tapSlop = 8;

class BoardPointer extends StatefulWidget {
  const BoardPointer({
    super.key,
    required this.controller,
    required this.layout,
    required this.child,
  });

  final GameController controller;
  final BoardLayout layout;
  final Widget child;

  @override
  State<BoardPointer> createState() => _BoardPointerState();
}

class _BoardPointerState extends State<BoardPointer> {
  int? _pointer;
  Offset? _down;
  bool _moved = false;

  bool _inBars(Offset p) =>
      widget.layout.topBar.contains(p) || widget.layout.toolRow.contains(p);

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || _inBars(e.localPosition)) return;
    _pointer = e.pointer;
    _down = e.localPosition;
    _moved = false;
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if ((e.localPosition - _down!).distance > tapSlop) _moved = true;
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_moved) return;
    final hit = hitTest(widget.layout, e.localPosition);
    widget.controller.tapPile(hit?.$1, hit?.$2, at: e.timeStamp);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _pointer = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onDown,
    onPointerMove: _onMove,
    onPointerUp: _onUp,
    onPointerCancel: _onCancel,
    child: widget.child,
  );
}
