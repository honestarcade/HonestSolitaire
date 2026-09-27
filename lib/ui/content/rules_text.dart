/// The How to play text (#90): the design's words, corrected to the rules
/// the app actually plays. Numbers are written in words as the design does;
/// [RuleCard.numbers] names the engine constants a card states so
/// `test/guards/rules_text_test.dart` can hold the text to the engine.
library;

import '../game/game_event.dart';

class RuleCard {
  const RuleCard(this.tag, this.body, {this.numbers = const []});

  final String tag;
  final String body;

  /// `(engine constant name, value)`, signed as the engine stores it.
  final List<(String, int)> numbers;

  /// kebab-case of the tag, for keys.
  String get slug => tag.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
}

class Gesture {
  const Gesture(this.name, this.text);

  final String name;
  final String text;

  String get slug => name.toLowerCase().replaceAll(' ', '-');
}

const klondikeRules = [
  RuleCard(
    'THE GOAL',
    'Build all four foundations from ace to king, one per suit. Win the '
        'moment the fifty-second card lands.',
  ),
  RuleCard(
    'THE TABLEAU',
    'Seven columns. Stack downward in alternating colours — a red six goes '
        'on a black seven. Only a king starts an empty column. Move a whole '
        'descending run in one go: tap a run to pick it up, then tap where '
        'it goes (One-tap moves it at once). A card can be taken back off a '
        'foundation, at a cost. With Auto-flip off, tap a face-down card to '
        'turn it.',
  ),
  RuleCard(
    'THE STOCK',
    'Tap the stock to turn one or three cards, whichever you chose at the '
        'deal. When it empties, tap again to run through the waste once '
        'more — unlimited passes.',
  ),
  RuleCard(
    'SCORING',
    'Standard: ten points per card to a foundation, five for a card from '
        'the waste to the tableau, five for turning a tableau card '
        '(automatic flips count too), minus fifteen for taking a card back '
        'off a foundation, minus two for each pass through the stock; the '
        'score never drops below zero. Vegas: minus fifty-two at the deal, '
        'plus five per foundation card, minus five for a card taken back, '
        'and in Vegas the score can go below zero. Or play with no score at '
        'all. In a timed standard game you lose two points every ten '
        'seconds, and a win adds a bonus that is bigger the faster you '
        'finish.',
    numbers: [
      ('KlondikeScoring.standard.toFoundation', 10),
      ('KlondikeScoring.standard.wasteToTableau', 5),
      ('KlondikeScoring.standard.flip', 5),
      ('KlondikeScoring.standard.foundationToTableau', -15),
      ('KlondikeScoring.standard.recycle', -2),
      ('KlondikeScoring.standard.floor', 0),
      ('KlondikeScoring.vegas.deal', -52),
      ('KlondikeScoring.vegas.toFoundation', 5),
      ('KlondikeScoring.vegas.foundationToTableau', -5),
      ('KlondikeScoring.timePenaltyPoints', 2),
      ('KlondikeScoring.timePenaltyPeriod.inSeconds', 10),
    ],
  ),
  RuleCard(
    'RECORDS',
    'Every finished game counts. Best time (timed wins), fewest moves, high '
        'score and your streak are kept per game, not per draw mode; wins '
        'and losses are also split by draw mode. Vegas games keep a '
        'lifetime dollar total and never set a high score.',
  ),
];

const spiderRules = [
  RuleCard(
    'THE GOAL',
    'Two decks, ten columns. Build eight complete same-suit runs from king '
        'down to ace. Each finished run leaves the board.',
  ),
  RuleCard(
    'MOVING CARDS',
    'Any card goes on a card one rank higher, regardless of suit — but only '
        'a same-suit descending run moves as a group. An empty column takes '
        'anything. With Auto-flip off, tap a face-down card to turn it.',
  ),
  RuleCard(
    'THE DEALS',
    'Five deals of ten cards wait in the corner. A deal drops one card on '
        'every column. Strict: every column must hold a card before you '
        'deal. Relaxed, chosen on the New Spider screen, lets you deal a '
        'row with a column empty. Plan before you spend one.',
  ),
  RuleCard(
    'DIFFICULTY',
    'One suit is a gentle puzzle, two suits is the standard game, four '
        'suits is the real thing. The board and deal count never change — '
        'only the suits.',
  ),
  RuleCard(
    'SCORING',
    'Five hundred points at the deal, minus one per move, plus one hundred '
        'per completed run; the score never drops below zero, and a fast '
        'timed win earns a bonus.',
    numbers: [
      ('SpiderScoring.atDeal', 500),
      ('SpiderScoring.perMove', -1),
      ('SpiderScoring.perRun', 100),
      ('SpiderScoring.floor', 0),
    ],
  ),
  RuleCard(
    'RECORDS',
    'Best time (timed wins), fewest moves, high score and your streak are '
        'kept per game, not per suit count; wins and losses are also split '
        'by suit count.',
  ),
];

List<RuleCard> rulesFor(GameType type) =>
    type == GameType.klondike ? klondikeRules : spiderRules;

const gestures = [
  Gesture(
    'TAP',
    'Select a card or a run, then tap a column, foundation or free space to '
        'place it. With One-tap move on, a tap sends the card to its best '
        'legal spot at once.',
  ),
  Gesture(
    'DOUBLE TAP',
    'Send a card straight to a foundation (Klondike) or the whole same-suit '
        'run to its best column (Spider).',
  ),
  Gesture('DRAG', 'Drag a card or run and drop it. Illegal drops spring back.'),
  Gesture(
    'TAP STOCK',
    'Turn the next cards; when the stock is empty, tap again to recycle the '
        'waste. In Spider, deal a row.',
  ),
  Gesture(
    'LONG PRESS',
    'Spreads out a crowded column so every face-up card is readable.',
  ),
];
