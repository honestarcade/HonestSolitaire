/// The project's tap-target guideline (#109): the framework's 48 dp rule
/// with one exception — a board node tagged `a11yExemptCard` (a card as
/// wide as its card, owner) — and a record of every node it flagged, so
/// the guard can prove each exception was needed and each flagged node is
/// tagged.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/ui/board/board_view.dart';

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

/// The framework's text-contrast guideline, less the nodes its sampler
/// cannot read: it renders the screen at logical resolution and takes the
/// most frequent light colour, so text under [minReadableHeight] logical
/// pixels tall (a 9 px description or kicker on a small phone) yields a
/// blended "light"
/// colour whatever its real one. Those tokens are held to 4.5:1 by
/// computation in test/guards/contrast_test.dart (#102); everything taller
/// is measured here as rendered.
class ReadableTextContrastGuideline extends MinimumTextContrastGuideline {
  const ReadableTextContrastGuideline({this.minReadableHeight = 16});

  final double minReadableHeight;

  /// Text fields are skipped too: the sampler reads the box's border and
  /// fill, not the few glyphs inside; the field's text colour is one of
  /// #102's computed pairs.
  @override
  bool shouldSkipNode(SemanticsData data) =>
      super.shouldSkipNode(data) ||
      data.rect.height < minReadableHeight ||
      data.flagsCollection.isTextField;

  @override
  String get description =>
      'Text at least $minReadableHeight px tall should follow WCAG contrast';
}
