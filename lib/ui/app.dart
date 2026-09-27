/// The app (#81): a Klondike game on launch, scaled to the phone, with the
/// play and display settings held in memory at the design's defaults until
/// M4 adds the Settings screen and persistence.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:honest_solitaire/engine/deal_number.dart';
import 'package:honest_solitaire/engine/game.dart';

import '../data/app_store.dart';
import '../data/game_saves.dart';
import '../data/settings_store.dart';
import '../data/stats.dart';
import '../platform/platform_channel.dart';

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
    this.store,
    this.platform,
  });

  final PlaySettings initialPlaySettings;
  final DisplayOptions initialDisplayOptions;

  /// Production defaults when null: the platform channel and a store over
  /// its files directory. Tests pass `AppStore.memory()` and a mock channel.
  final AppStore? store;
  final PlatformChannel? platform;

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
      // The scope sits above the Navigator so every pushed screen (Settings,
      // and the rest of M4) shares the one controller and store.
      builder: (context, child) => GameRoot(
        initialPlaySettings: initialPlaySettings,
        initialDisplayOptions: initialDisplayOptions,
        dealNumberSource: dealNumberSource ?? DealNumber.random,
        store: store,
        platform: platform,
        child: child!,
      ),
      home: const BoardScreen(),
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
    this.store,
    this.platform,
    required this.child,
  });

  final PlaySettings initialPlaySettings;
  final DisplayOptions initialDisplayOptions;
  final DealNumber Function() dealNumberSource;
  final AppStore? store;
  final PlatformChannel? platform;
  final Widget child;

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

  late final PlatformChannel platform = widget.platform ?? PlatformChannel();
  late final AppStore store = widget.store ?? AppStore.platform(platform);
  late final GameSaves saves = GameSaves(store);
  late final GamePersistence persistence = GamePersistence(controller, saves);
  late final StatsRecorder stats = StatsRecorder(store);
  late final StatsListener statsListener = StatsListener(
    controller,
    stats,
    saves,
  );
  late final SettingsStore settingsStore = SettingsStore(
    store,
    playSettings,
    displayOptions,
  );

  @override
  void initState() {
    super.initState();
    // Touch the listeners so they attach from the first frame; #87's splash
    // takes over the loading order.
    persistence;
    statsListener;
    settingsStore.load();
    stats.load();
    saves.load();
  }

  @override
  void dispose() {
    persistence.dispose();
    statsListener.dispose();
    settingsStore.dispose();
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
    store: store,
    saves: saves,
    stats: stats,
    statsListener: statsListener,
    settingsStore: settingsStore,
    platform: platform,
    child: widget.child,
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
    required this.store,
    required this.saves,
    required this.stats,
    required this.statsListener,
    required this.settingsStore,
    required this.platform,
    required super.child,
  });

  final GameController controller;
  final ValueNotifier<PlaySettings> playSettings;
  final ValueNotifier<DisplayOptions> displayOptions;
  final AppStore store;
  final GameSaves saves;
  final StatsRecorder stats;
  final StatsListener statsListener;
  final SettingsStore settingsStore;
  final PlatformChannel platform;

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
