/// One board-level pointer router (#75, #77): taps, drags and press-and-hold
/// peeks from raw pointer events, so a single tap is never delayed and the
/// three gestures never fight.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../game/game_controller.dart';
import 'board_layout.dart';
import 'pile_ref.dart';

/// Movement under this many logical pixels is still a tap or a hold.
const double tapSlop = 8;

/// A hold this long with under [tapSlop] of drift peeks a column.
const Duration peekDelay = Duration(milliseconds: 400);

class BoardPointer extends StatefulWidget {
  const BoardPointer({
    super.key,
    required this.controller,
    required this.layout,
    required this.child,
    this.dealing = false,
    this.onFinishDeal,
  });

  final GameController controller;
  final BoardLayout layout;
  final Widget child;

  /// While the deal animation runs (#103), a pointer-down on the board
  /// lands it and is consumed; one on the bars lands it and passes through.
  final bool dealing;
  final VoidCallback? onFinishDeal;

  @override
  State<BoardPointer> createState() => _BoardPointerState();
}

class _BoardPointerState extends State<BoardPointer> {
  int? _pointer;
  Offset? _down;
  (BoardPile, int?)? _downHit;
  bool _moved = false;
  bool _dragging = false;
  bool _peeking = false;
  Timer? _hold;

  GameController get controller => widget.controller;

  bool _inBars(Offset p) =>
      widget.layout.topBar.contains(p) || widget.layout.toolRow.contains(p);

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) {
      // A second finger snaps any drag or peek home.
      _reset();
      controller.cancelDrag();
      return;
    }
    if (widget.dealing) {
      widget.onFinishDeal?.call();
      if (!_inBars(e.localPosition)) _pointer = -1; // consumed: no tap on up
      return;
    }
    if (_inBars(e.localPosition)) return;
    _pointer = e.pointer;
    _down = e.localPosition;
    _downHit = hitTest(widget.layout, e.localPosition);
    _moved = false;
    _dragging = false;
    _peeking = false;
    final hit = _downHit;
    if (hit != null && hit.$1 is TableauPile && controller.springBack == null) {
      final column = (hit.$1 as TableauPile).column;
      _hold = Timer(peekDelay, () {
        if (_pointer != e.pointer || _moved || _dragging) return;
        if (controller.canPeek(column)) {
          _peeking = true;
          controller.startPeek(column);
        }
      });
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (_dragging) {
      controller.updateDrag(e.localPosition);
      return;
    }
    if ((e.localPosition - _down!).distance <= tapSlop) return;
    _moved = true;
    _hold?.cancel();
    if (_peeking) {
      _peeking = false;
      controller.endPeek();
    }
    final hit = _downHit;
    if (hit == null || controller.springBack != null) return;
    final rects = widget.layout.cards[hit.$1];
    if (rects == null) return;
    // The card under the finger at press-down, measured in the compressed
    // layout, is the one that lifts.
    if (controller.beginDrag(hit.$1, hit.$2, rects, _down!)) {
      _dragging = true;
      controller.updateDrag(e.localPosition);
    }
  }

  void _onUp(PointerUpEvent e) {
    if (_pointer == -1) {
      _reset();
      return;
    }
    if (e.pointer != _pointer) return;
    _hold?.cancel();
    final wasDragging = _dragging;
    final wasPeeking = _peeking;
    final moved = _moved;
    _reset();
    if (wasDragging) {
      final hit = hitTest(widget.layout, e.localPosition);
      controller.endDrag(hit?.$1);
      return;
    }
    if (wasPeeking) {
      controller.endPeek();
      return;
    }
    if (moved) return;
    final hit = hitTest(widget.layout, e.localPosition);
    controller.tapPile(hit?.$1, hit?.$2, at: e.timeStamp);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _reset();
    controller.cancelDrag();
  }

  void _reset() {
    _hold?.cancel();
    _hold = null;
    _pointer = null;
    _down = null;
    _downHit = null;
    _moved = false;
    _dragging = false;
    _peeking = false;
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
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
