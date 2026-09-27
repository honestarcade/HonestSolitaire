import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honest_solitaire/app_version.dart';
import 'package:honest_solitaire/platform/platform_channel.dart';
import 'package:honest_solitaire/ui/content/about_text.dart';
import 'package:honest_solitaire/ui/content/links.dart';
import 'package:honest_solitaire/ui/screens/about_app_screen.dart';
import 'package:honest_solitaire/ui/screens/about_studio_screen.dart';

import 'setup_helpers.dart';

/// Records openUrl calls on the app's own method channel.
class ChannelSpy {
  ChannelSpy(WidgetTester tester, {this.result = true, this.throws = false}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(PlatformChannel.name),
      (call) async {
        if (call.method == 'openUrl') {
          urls.add((call.arguments as Map)['url'] as String);
          if (throws) throw PlatformException(code: 'boom');
          return result;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(PlatformChannel.name),
        null,
      ),
    );
  }

  final List<String> urls = [];
  bool result;
  bool throws;
}

void main() {
  testWidgets('About the App renders every section', (tester) async {
    await openScreen(tester, const AboutAppScreen());
    expect(find.text('About the App'), findsOneWidget);
    expect(find.text('Honest Solitaire'), findsOneWidget);
    expect(find.text('v$appVersion · OFFLINE'), findsOneWidget);
    expect(find.textContaining('MB'), findsNothing, reason: 'no size claim');
    expect(find.text(aboutIntro), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('about-promises')));
    for (final f in features) {
      expect(find.text(f.title), findsOneWidget, reason: f.title);
      expect(find.text(f.text), findsOneWidget, reason: f.title);
    }
    expect(features[4].text, contains('win rates'));
    for (final chip in promiseChips) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Honest Arcade Promises'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('about-link-source')));
    expect(find.text('HONEST ARCADE ↗'), findsOneWidget);
    expect(find.text('SOURCE ON GITHUB ↗'), findsOneWidget);
    await tapKey(tester, 'aboutapp-studio');
    await settle(tester, transition: true);
    expect(find.byType(AboutStudioScreen), findsOneWidget);
  });

  testWidgets(
    'About Honest Arcade renders every section, with the backup qualifier',
    (tester) async {
      await openScreen(tester, const AboutStudioScreen());
      expect(find.text('About Honest Arcade'), findsOneWidget);
      for (final p in studioParagraphs) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.text('SUPPORT HONEST ARCADE'), findsOneWidget);
      expect(find.text(supportText), findsOneWidget);
      expect(find.text('honestarcade.app/contribute →'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('about-link-source')));
      expect(promises, hasLength(7));
      for (final p in promises) {
        expect(find.text(p.title), findsOneWidget, reason: p.title);
        expect(find.text(p.text), findsOneWidget, reason: p.title);
      }
      expect(promises[2].text, contains('Android backup'));
      for (final chip in ['NO ADS', 'NO TRACKING', 'OPEN SOURCE']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.text('HONESTARCADE.APP ↗'), findsOneWidget);
      expect(find.text('SOURCE ON GITHUB ↗'), findsOneWidget);
    },
  );

  testWidgets('each link calls openUrl with its URL through the channel', (
    tester,
  ) async {
    final spy = ChannelSpy(tester);
    await openScreen(tester, const AboutAppScreen());
    await tapKey(tester, 'about-link-site');
    await tapKey(tester, 'about-link-source');
    expect(spy.urls, [siteLink.url, appSourceLink.url]);
    expect(
      appSourceLink.url,
      'https://github.com/honestarcade/HonestSolitaire',
    );
    expect(find.byKey(const Key('about-snackbar')), findsNothing);
    await openScreen(tester, const AboutStudioScreen());
    spy.urls.clear();
    await tapKey(tester, 'about-support');
    await tapKey(tester, 'about-link-site');
    await tapKey(tester, 'about-link-source');
    expect(spy.urls, [contributeLink.url, siteLink.url, studioSourceLink.url]);
    expect(studioSourceLink.url, 'https://github.com/honestarcade');
    for (final url in spy.urls) {
      expect(url, startsWith('https://'));
    }
  });

  testWidgets(
    'a false result or a channel error shows the message; nothing crashes',
    (tester) async {
      final spy = ChannelSpy(tester, result: false);
      await openScreen(tester, const AboutStudioScreen());
      await tapKey(tester, 'about-support');
      expect(find.byKey(const Key('about-snackbar')), findsOneWidget);
      expect(
        find.text(
          "COULDN'T OPEN HONESTARCADE.APP/CONTRIBUTE — NO BROWSER FOUND",
        ),
        findsOneWidget,
      );
      // Entrance animation, then the 4 s timer, then the exit animation.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 4500));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('about-snackbar')), findsNothing);
      spy.throws = true;
      await tapKey(tester, 'about-link-site');
      expect(find.byKey(const Key('about-snackbar')), findsOneWidget);
      expect(find.textContaining('HONESTARCADE.APP —'), findsOneWidget);
      expect(spy.urls, hasLength(2));
      // Entrance animation, then the 4 s timer, then the exit animation.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 4500));
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
