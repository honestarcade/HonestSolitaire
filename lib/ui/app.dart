/// The app (#81): a Klondike game on launch, scaled to the phone, with the
/// play and display settings held in memory at the design's defaults until
/// M4 adds the Settings screen and persistence.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import 'board/board_layout.dart';
import 'board/board_view.dart';
import 'game/game_controller.dart';
import 'game/tool_row.dart';
import 'game/top_bar.dart';
import 'settings/display_options.dart';
import 'settings/play_settings.dart';
import 'theme/palette.dart';

/// The design's defaults for the launch deal and for NEW: draw 3, standard
/// scoring, timed. Auto-flip follows the setting at deal time.
const KlondikeOptions launchOptions = KlondikeOptions(draw: DrawMode.three);

/// Transparent bars with light icons; the felt paints behind them.
const SystemUiOverlayStyle systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

class HonestSolitaireApp extends StatelessWidget {
  const HonestSolitaireApp({
    super.key,
    this.initialPlaySettings = const PlaySettings(),
    this.initialDisplayOptions = const DisplayOptions(),
    this.dealNumberSource,
  });

  final PlaySettings initialPlaySettings;
  final DisplayOptions initialDisplayOptions;

  /// Where the launch deal, NEW and Switch get their numbers; tests inject
  /// a fixed one. Null means `DealNumber.random`.
  final DealNumber Function()? dealNumberSource;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.dark(
      primary: Palette.teal,
      onPrimary: Palette.ink,
      secondary: Palette.violet,
      surface: Palette.card,
      onSurface: Colors.white,
    );
    final theme = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.navy,
      canvasColor: Palette.navy,
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Honest Solitaire',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: GameRoot(
        initialPlaySettings: initialPlaySettings,
        initialDisplayOptions: initialDisplayOptions,
        dealNumberSource: dealNumberSource ?? DealNumber.random,
      ),
    );
  }
}

/// Owns the settings notifiers and the controller for the app's lifetime.
class GameRoot extends StatefulWidget {
  const GameRoot({
    super.key,
    required this.initialPlaySettings,
    required this.initialDisplayOptions,
    required this.dealNumberSource,
  });

  final PlaySettings initialPlaySettings;
  final DisplayOptions initialDisplayOptions;
  final DealNumber Function() dealNumberSource;

  @override
  State<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<GameRoot> {
  late final ValueNotifier<PlaySettings> playSettings = ValueNotifier(
    widget.initialPlaySettings,
  );
  late final ValueNotifier<DisplayOptions> displayOptions = ValueNotifier(
    widget.initialDisplayOptions,
  );
  late final GameController controller = GameController(
    KlondikeGame.deal(
      widget.dealNumberSource(),
      launchOptions.copyWith(autoFlip: widget.initialPlaySettings.autoFlip),
    ),
    playSettings,
    displayOptions,
    dealNumberSource: widget.dealNumberSource,
  );

  @override
  void dispose() {
    controller.dispose();
    playSettings.dispose();
    displayOptions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameScope(
    controller: controller,
    playSettings: playSettings,
    displayOptions: displayOptions,
    child: const BoardScreen(),
  );
}

/// Exposes the controller and the settings to every screen (M4's Settings
/// screen reuses it).
class GameScope extends InheritedWidget {
  const GameScope({
    super.key,
    required this.controller,
    required this.playSettings,
    required this.displayOptions,
    required super.child,
  });

  final GameController controller;
  final ValueNotifier<PlaySettings> playSettings;
  final ValueNotifier<DisplayOptions> displayOptions;

  static GameScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'GameScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GameScope oldWidget) =>
      oldWidget.controller != controller ||
      oldWidget.playSettings != playSettings ||
      oldWidget.displayOptions != displayOptions;
}

/// The board, edge to edge behind the system bars, laid out inside the
/// safe area, scaled from the 390-point design and capped at 480.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GameScope.of(context).controller;
    final padding = MediaQuery.viewPaddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBars,
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safeWidth = constraints.maxWidth - padding.horizontal;
            final scale = math.min(safeWidth, maxBoardWidth) / designWidth;
            return BoardView(
              controller: controller,
              padding: padding,
              topBar: (_) => TopBar(controller: controller, scale: scale),
              toolRow: (_) => ToolRow(controller: controller, scale: scale),
            );
          },
        ),
      ),
    );
  }
}
