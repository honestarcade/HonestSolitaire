part of 'game.dart';

// Versioned JSON for both games (#69). Filled in by that story.

Map<String, Object?> _klondikeToJson(KlondikeGame game) =>
    throw UnimplementedError('#69');

KlondikeGame _klondikeFromJson(Map<String, Object?> json) =>
    throw UnimplementedError('#69');

Map<String, Object?> _spiderToJson(SpiderGame game) =>
    throw UnimplementedError('#69');

SpiderGame _spiderFromJson(Map<String, Object?> json) =>
    throw UnimplementedError('#69');

Game _gameFromJson(Map<String, Object?> json) =>
    throw UnimplementedError('#69');

int _intField(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('"$key" must be an int, not $value');
  return value;
}

/// Decodes any move of either game from its `toJson` form.
Move _moveFromJson(Map<String, Object?> json) {
  final kind = json['kind'];
  switch (kind) {
    case 'run':
      return MoveRun(
        _intField(json, 'from'),
        _intField(json, 'start'),
        _intField(json, 'to'),
      );
    case 'wasteToTableau':
      return WasteToTableau(_intField(json, 'to'));
    case 'wasteToFoundation':
      return const WasteToFoundation();
    case 'tableauToFoundation':
      return TableauToFoundation(_intField(json, 'from'));
    case 'foundationToTableau':
      return FoundationToTableau(
        _intField(json, 'foundation'),
        _intField(json, 'to'),
      );
    case 'draw':
      return const Draw();
    case 'recycle':
      return const Recycle();
    case 'flip':
      return Flip(_intField(json, 'column'));
    case 'move':
      return MoveCards(
        _intField(json, 'from'),
        _intField(json, 'start'),
        _intField(json, 'to'),
      );
    case 'dealRow':
      return const DealRow();
    case 'group':
      final moves = json['moves'];
      if (moves is! List) throw const FormatException('a group needs moves');
      return MoveGroup([
        for (final m in moves)
          if (m is Map<String, Object?>)
            _moveFromJson(m)
          else
            throw FormatException('a move must be an object, not $m'),
      ]);
    default:
      throw FormatException('unknown move kind $kind');
  }
}
