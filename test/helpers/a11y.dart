/// The project's tap-target guideline (#109): the framework's 48 dp rule
/// with one exception — a board node tagged `a11yExemptCard` (a card as
/// wide as its card, owner) — and a record of every node it flagged, so
/// the guard can prove each exception was needed and each flagged node is
/// tagged.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';
import 'package:honest_solitaire/ui/theme/palette.dart';

/// One node the guideline would have flagged, tagged or not.
class Flagged {
  const Flagged(this.id, this.label, this.size, this.tagged, this.actions);

  final int id;
  final String label;
  final Size size;
  final bool tagged;

  /// The node's custom action labels: a tagged node's other way to act.
  final List<String> actions;

  @override
  String toString() =>
      '$label (${size.width.toStringAsFixed(1)}×${size.height.toStringAsFixed(1)}'
      '${tagged ? ', exempt' : ''})';
}

/// The framework's `MinimumTapTargetGuideline` traversal (its `_traverse`
/// is private), skipping nodes tagged [a11yExemptCard] and recording what it
/// would flag. Untagged undersized nodes fail with the framework's words.
class RecordingTapTargetGuideline extends AccessibilityGuideline {
  const RecordingTapTargetGuideline(
    this.record, {
    this.size = const Size(48, 48),
  });

  final List<Flagged> record;
  final Size size;

  static const double _gap = 0.001;

  @override
  String get description => 'Tappable objects should be at least $size';

  @override
  Evaluation evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final view in tester.binding.renderViews) {
      result += _traverse(
        view.flutterView,
        view.owner!.semanticsOwner!.rootSemanticsNode!,
      );
    }
    return result;
  }

  Evaluation _traverse(ui.FlutterView view, SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((child) {
      result += _traverse(view, child);
      return true;
    });
    if (node.isMergedIntoParent) {
      return result;
    }
    final data = node.getSemanticsData();
    if ((!data.hasAction(SemanticsAction.longPress) &&
            !data.hasAction(SemanticsAction.tap)) ||
        data.flagsCollection.isHidden) {
      return result;
    }
    Rect bounds = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) {
        bounds = MatrixUtils.transformRect(transform, bounds);
      }
      if (current.flagsCollection.hasImplicitScrolling &&
          _atBoundary(bounds, current.rect)) {
        return result;
      }
      current = current.parent;
    }
    if (_atBoundary(bounds, Offset.zero & view.physicalSize)) {
      return result;
    }
    final candidate = bounds.size / view.devicePixelRatio;
    if (candidate.width < size.width - precisionErrorTolerance ||
        candidate.height < size.height - precisionErrorTolerance) {
      final tagged = node.tags?.contains(a11yExemptCard) ?? false;
      record.add(
        Flagged(node.id, data.label, candidate, tagged, [
          for (final id in data.customSemanticsActionIds ?? const <int>[])
            if (CustomSemanticsAction.getAction(id)?.label != null)
              CustomSemanticsAction.getAction(id)!.label!,
        ]),
      );
      if (!tagged) {
        result += Evaluation.fail(
          '$node: expected tap target size of at least $size, but found $candidate\n',
        );
      }
    }
    return result;
  }

  static bool _atBoundary(Rect child, Rect parent) =>
      !(child.left - parent.left > _gap &&
          parent.right - child.right > _gap &&
          child.top - parent.top > _gap &&
          parent.bottom - child.bottom > _gap);
}

/// Contrast by computation, not by sampling (#109): the framework's
/// `textContrastGuideline` renders the screen at logical resolution and
/// takes the most frequent light colour, which differs between a Mac and
/// the Linux runner and blends small text into its background — the same
/// tokens measured 4.36:1 on CI and passed locally (run 36302842503,
/// 2026-09-27). This guideline instead requires every text colour drawn on
/// the screen to be one of `Palette.textPairs`' foregrounds, each of which
/// test/guards/contrast_test.dart proves at its ratio on every surface it
/// sits on, by arithmetic, on every machine alike. Text under an `Opacity`
/// below 1 is the disabled state, whose 40 % is #102's own rule.
class CheckedTextGuideline extends AccessibilityGuideline {
  const CheckedTextGuideline();

  @override
  String get description =>
      'Every text colour is a pair test/guards/contrast_test.dart proves';

  static final Set<int> _allowed = {
    for (final pair in Palette.textPairs) pair.fg.toARGB32(),
  };

  @override
  Evaluation evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    final seen = <String>{};
    for (final element in find.byType(RichText).evaluate()) {
      final render = element.renderObject;
      if (render is! RenderParagraph || !render.attached) continue;
      var dimmed = false;
      element.visitAncestorElements((a) {
        final w = a.widget;
        if (w is Opacity && w.opacity < 1) dimmed = true;
        return !dimmed;
      });
      if (dimmed) continue;
      final colours = <Color>{};
      void collect(InlineSpan span, Color? inherited) {
        final own = span.style?.color ?? inherited;
        if (span is TextSpan) {
          if (span.text != null &&
              span.text!.trim().isNotEmpty &&
              own != null) {
            colours.add(own);
          }
          for (final child in span.children ?? const <InlineSpan>[]) {
            collect(child, own);
          }
        }
      }

      collect(render.text, null);
      for (final c in colours) {
        if (_allowed.contains(c.toARGB32())) continue;
        final text = render.text.toPlainText();
        final key = '${c.toARGB32().toRadixString(16)}:$text';
        if (!seen.add(key)) continue;
        result += Evaluation.fail(
          '"$text" is drawn in #${c.toARGB32().toRadixString(16).toUpperCase()}, '
          'which is no Palette.textPairs foreground: no contrast proof holds it\n',
        );
      }
    }
    return result;
  }
}
