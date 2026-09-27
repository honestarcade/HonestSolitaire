/// A single-message notice with small actions, sized to replace the top
/// bar's readouts in place so the board never shifts (#79).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
  });

  final String message;
  final List<NoticeAction> actions;
  final double scale;

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
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.message,
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(9 * s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large text (#106): the message scales down to the room the
            // buttons leave rather than clipping.
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
            ],
          ],
        ),
      ),
    );
  }
}
