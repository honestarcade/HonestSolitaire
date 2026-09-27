/// A single-message notice with small actions, sized to replace the top
/// bar's readouts in place so the board never shifts (#79).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../a11y/announcer.dart';
import '../a11y/tap_target.dart';
import '../app.dart';
import '../theme/palette.dart';

class NoticeAction {
  const NoticeAction(this.label, this.onPressed, {this.enabled = true});

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
}

class NoticeBanner extends StatefulWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    required this.actions,
    required this.scale,
    required this.barHeight,
  });

  final String message;
  final List<NoticeAction> actions;
  final double scale;

  /// The drawn bar's height the band is centred on.
  final double barHeight;

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  bool _announced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_announced) return;
    _announced = true;
    (GameScope.maybeOf(context)?.announcer ?? const FlutterAnnouncer())
        .announce(context, widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    // The banner draws a band centred on the bar; each button's hit box is
    // 48 dp (#109) and overhangs the band, so the whole banner is as tall as
    // the taller of the two.
    final bandHeight = (13 + 12) * s;
    final height = math.max(widget.barHeight, kMinTapTarget);
    final bandTop = math.max(0.0, (widget.barHeight - bandHeight) / 2);
    return Semantics(
      container: true,
      liveRegion: true,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: bandTop,
              height: bandHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.card,
                  borderRadius: BorderRadius.circular(9 * s),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: bandTop + bandHeight / 2 - height / 2,
              height: height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large text (#106): the message scales down to the room
                    // the buttons leave rather than clipping.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.message,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 13 * s,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    for (final a in widget.actions) ...[
                      SizedBox(width: 8 * s),
                      Semantics(
                        button: true,
                        enabled: a.enabled,
                        label: a.label,
                        onTap: a.enabled ? a.onPressed : null,
                        excludeSemantics: true,
                        child: Opacity(
                          opacity: a.enabled ? 1 : 0.4,
                          child: GestureDetector(
                            key: Key(
                              'notice-${a.label.toLowerCase().replaceAll(' ', '-')}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: a.enabled ? a.onPressed : null,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: kMinTapTarget,
                                minHeight: kMinTapTarget,
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 9 * s,
                                  vertical: 6 * s,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AFFFFFF),
                                  borderRadius: BorderRadius.circular(7 * s),
                                ),
                                child: Text(
                                  a.label,
                                  style: TextStyle(
                                    fontSize: 11 * s,
                                    fontWeight: FontWeight.w500,
                                    color: Palette.teal,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
