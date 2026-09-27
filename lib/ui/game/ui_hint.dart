/// A hint translated to the board's piles (#79 fills the translation).
library;

import '../board/pile_ref.dart';

class UiHint {
  const UiHint.move({
    required this.source,
    required this.start,
    this.destination,
  }) : stock = false,
       noMoves = false;

  /// Draw, recycle or deal: ring the stock.
  const UiHint.stock()
    : source = null,
      start = null,
      destination = null,
      stock = true,
      noMoves = false;

  const UiHint.noMoves()
    : source = null,
      start = null,
      destination = null,
      stock = false,
      noMoves = true;

  final BoardPile? source;
  final int? start;
  final BoardPile? destination;
  final bool stock;
  final bool noMoves;

  @override
  bool operator ==(Object other) =>
      other is UiHint &&
      other.source == source &&
      other.start == start &&
      other.destination == destination &&
      other.stock == stock &&
      other.noMoves == noMoves;

  @override
  int get hashCode => Object.hash(source, start, destination, stock, noMoves);

  @override
  String toString() => noMoves
      ? 'UiHint.noMoves'
      : stock
      ? 'UiHint.stock'
      : 'UiHint($source[$start] → $destination)';
}
