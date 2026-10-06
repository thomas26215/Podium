// The motion of each surface style: how taps press, how things come in,
// how pages, dialogs and sheets open — and that every surface reacts at
// paint time, under any tap target or entrance, in every style.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podium/theme/app_theme.dart';
import 'package:podium/widgets/common.dart';
import 'package:podium/widgets/motion_paint.dart';

void main() {
  tearDown(() => AppColors.configure(dark: false, appearance: const Appearance()));

  group('AppMotion', () {
    test('every entrance starts away and lands exactly in place', () {
      for (final s in SurfaceStyle.values) {
        final m = AppMotion.of(s);
        for (final amplitude in [1.0, 0.35]) {
          final start = m.reveal(0, amplitude: amplitude);
          expect(start.opacity == 0 || start.transforms || start.rise < 1 || start.blur > 0, isTrue, reason: '${s.name} starts as it ends');
          final end = m.reveal(1, amplitude: amplitude);
          expect(end.opacity, 1, reason: s.name);
          expect(end.transforms, isFalse, reason: s.name);
          expect(end.blur, 0, reason: s.name);
          expect(end.rise, closeTo(1, 1e-9), reason: s.name);
        }
      }
    });

    test('every exit leaves from in place and ends gone', () {
      for (final s in SurfaceStyle.values) {
        final m = AppMotion.of(s);
        final still = m.leave(1);
        expect(still.opacity, 1, reason: s.name);
        expect(still.transforms, isFalse, reason: s.name);
        expect(m.leave(0).opacity, 0, reason: s.name);
      }
    });

    test('the original style keeps its fade-and-slide', () {
      final m = AppMotion.of(SurfaceStyle.flat);
      final mid = m.reveal(0.5);
      expect(mid.offset.dx, 0);
      expect(mid.offset.dy, lessThan(0), reason: 'slides down from just above');
      expect(mid.scaleX, 1);
      expect(mid.rise, 1, reason: 'its cards have no shadows to grow');
      expect(m.reveal(0.5, sideways: true).offset.dy, 0, reason: 'a next step slides in from the side');
    });

    test('each style has an entrance of its own', () {
      AppMotion m(SurfaceStyle s) => AppMotion.of(s);
      expect(m(SurfaceStyle.neumorphic).reveal(0.3).rise, lessThan(0.3), reason: 'extruded out of the surface');
      expect(m(SurfaceStyle.glass).reveal(0.2).blur, greaterThan(2), reason: 'comes into focus');
      expect(m(SurfaceStyle.brutalist).reveal(0.05).opacity, 1, reason: 'no fade at all');
      expect(m(SurfaceStyle.brutalist).reveal(0.3).rise, 0, reason: 'its hard shadow snaps out after it lands');
      expect(m(SurfaceStyle.clay).reveal(0.15).scaleX, isNot(m(SurfaceStyle.clay).reveal(0.15).scaleY), reason: 'squashes like jelly');
      expect(m(SurfaceStyle.gradient).reveal(0.3).offset.dx, greaterThan(0), reason: 'sweeps in from the side');
      final neon = [for (var t = 0.0; t <= 0.5; t += 0.01) m(SurfaceStyle.neon).reveal(t).opacity];
      var dips = 0;
      for (var i = 1; i < neon.length; i++) {
        if (neon[i] < neon[i - 1] - 0.05) dips++;
      }
      expect(dips, greaterThanOrEqualTo(2), reason: 'a neon tube stutters on');
    });

    test('presses are still at rest, and neo-brutalism lands on its shadow', () {
      for (final s in SurfaceStyle.values) {
        final t = AppMotion.of(s).press(0, 1, const Offset(5, 5));
        expect(t.offset, Offset.zero, reason: s.name);
        expect(t.scaleX, 1, reason: s.name);
        expect(t.scaleY, 1, reason: s.name);
      }
      final brutal = AppMotion.of(SurfaceStyle.brutalist).press(1, 1, const Offset(5, 5));
      expect(brutal.offset, const Offset(5, 5));
      expect(brutal.scaleX, 1);
      final clay = AppMotion.of(SurfaceStyle.clay).press(1, 1, Offset.zero);
      expect(clay.scaleX, greaterThan(1));
      expect(clay.scaleY, lessThan(1), reason: 'flattened onto what it rests on');
      expect(AppMotion.of(SurfaceStyle.clay).releaseSpring, isNotNull);
    });

    test('the custom curves start at 0 and end at 1, the jelly overshooting', () {
      for (final curve in [jelly, flicker, flickerSoft]) {
        expect(curve.transform(0), 0);
        expect(curve.transform(1), 1);
      }
      final peak = [for (var t = 0.0; t < 1; t += 0.01) jelly.transform(t)].reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.1));
      expect(jelly.transform(0.99), closeTo(1, 0.01), reason: 'settled by the end');
    });

    test('sheets never overshoot their height', () {
      for (final s in SurfaceStyle.values) {
        final curve = AppMotion.of(s).sheet?.curve;
        if (curve == null) continue;
        for (var t = 0.0; t <= 1; t += 0.02) {
          expect(curve.transform(t), lessThanOrEqualTo(1), reason: s.name);
        }
      }
    });
  });

  group('SurfaceMotion', () {
    test('a press goes to the first surface that fills the tap target', () {
      final slot = PressSlot()
        ..value = 1
        ..size = const Size(200, 80);
      PressSlot? card, chip, second;
      SurfaceMotion.withPress(slot, () {
        chip = SurfaceMotion.claim(const Size(40, 24));
        card = SurfaceMotion.claim(const Size(190, 70));
        second = SurfaceMotion.claim(const Size(200, 80));
      });
      expect(chip, isNull, reason: 'a chip on the card stays put');
      expect(card, same(slot));
      expect(second, isNull, reason: 'claimed once');
      expect(slot.claimed, isTrue);
      expect(SurfaceMotion.claim(const Size(200, 80)), isNull, reason: 'nothing outside the tap target');
    });

    test('a press inside another one is its own, and the outer one comes back', () {
      final outer = PressSlot()..size = const Size(300, 100);
      final inner = PressSlot()..size = const Size(60, 30);
      PressSlot? got, after;
      SurfaceMotion.withPress(outer, () {
        SurfaceMotion.withPress(inner, () => got = SurfaceMotion.claim(const Size(60, 30)));
        after = SurfaceMotion.claim(const Size(300, 100));
      });
      expect(got, same(inner));
      expect(after, same(outer));
    });

    test('entrances inside entrances rise together', () {
      expect(SurfaceMotion.rise, 1);
      double? inside;
      SurfaceMotion.withRise(0.5, () => SurfaceMotion.withRise(0.5, () => inside = SurfaceMotion.rise));
      expect(inside, 0.25);
      expect(SurfaceMotion.rise, 1);
    });
  });

  testWidgets('every surface presses and rises in every style, light and dark', (tester) async {
    for (final s in SurfaceStyle.values) {
      for (final dark in [false, true]) {
        final t = AppTokens.resolve(Appearance(surface: s), dark: dark);
        final m = t.motion;
        Widget card() => Container(
              width: 160,
              height: 60,
              padding: const EdgeInsets.all(8),
              decoration: t.surface(radius: 16),
              child: Row(children: [Container(width: 30, decoration: t.well(radius: 9)), const Spacer(), Container(width: 30, decoration: t.accentButton(radius: 8))]),
            );
        await tester.pumpWidget(MaterialApp(
          home: ColoredBox(
            color: t.bg,
            child: Wrap(children: [
              for (final p in [0.25, 0.5, 1.0]) PressPaint(press: AlwaysStoppedAnimation(p), motion: m, touch: const Offset(0.2, 0.8), tint: t.accent, child: card()),
              for (final r in [0.0, 0.2, 0.5, 0.9]) Reveal(animation: AlwaysStoppedAnimation(r), motion: m, child: card()),
              PressPaint(press: const AlwaysStoppedAnimation(1), motion: m, highlight: t.pressHighlight(radius: 14), child: const SizedBox(width: 160, height: 40)),
              Container(width: 40, height: 36, decoration: t.navIndicator(radius: 11)),
            ]),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '${s.name} ${dark ? 'dark' : 'light'}');
      }
    }
  });

  testWidgets('a quick tap still plays the whole press, then springs back', (tester) async {
    AppColors.configure(dark: false, appearance: const Appearance(surface: SurfaceStyle.neumorphic));
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: Pressable(onTap: () => taps++, child: Container(width: 120, height: 60, decoration: cardDecoration(radius: 16))),
      ),
    ));
    double press() => tester.widget<PressPaint>(find.byType(PressPaint)).press.value;
    await tester.tap(find.byType(Pressable));
    expect(taps, 1, reason: 'the tap goes through at once');
    await tester.pump();
    await tester.pump(AppColors.motion.pressIn);
    expect(press(), closeTo(1, 0.01), reason: 'all the way in before coming back');
    await tester.pumpAndSettle();
    expect(press(), 0);
  });

  testWidgets('clay wobbles back past its rest', (tester) async {
    AppColors.configure(dark: false, appearance: const Appearance(surface: SurfaceStyle.clay));
    await tester.pumpWidget(MaterialApp(
      home: Center(child: Pressable(onTap: () {}, child: Container(width: 120, height: 60, decoration: cardDecoration(radius: 16)))),
    ));
    double press() => tester.widget<PressPaint>(find.byType(PressPaint)).press.value;
    await tester.tap(find.byType(Pressable));
    await tester.pump();
    await tester.pump(AppColors.motion.pressIn);
    var lowest = 1.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (press() < lowest) lowest = press();
    }
    expect(lowest, lessThan(-0.05), reason: 'stretched past its rest on the way back');
    await tester.pumpAndSettle();
    expect(press(), closeTo(0, 1e-3));
  });

  testWidgets('with reduced motion a press shows at once, without animating', (tester) async {
    AppColors.configure(dark: false, appearance: const Appearance(surface: SurfaceStyle.neumorphic));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(child: Pressable(onTap: () {}, child: Container(width: 120, height: 60, decoration: cardDecoration(radius: 16)))),
      ),
    ));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<PressPaint>(find.byType(PressPaint)).press.value, 1);
    await gesture.up();
    await tester.pump();
    expect(tester.widget<PressPaint>(find.byType(PressPaint)).press.value, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('entrances play in every style and settle', (tester) async {
    for (final s in SurfaceStyle.values) {
      AppColors.configure(dark: false, appearance: Appearance(surface: s));
      await tester.pumpWidget(MaterialApp(
        key: ValueKey(s),
        home: Column(children: staggered([for (var i = 0; i < 4; i++) Container(height: 40, decoration: cardDecoration(radius: 12))])),
      ));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: s.name);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('pages and dialogs open and close in every style', (tester) async {
    for (final s in SurfaceStyle.values) {
      AppColors.configure(dark: false, appearance: Appearance(surface: s));
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(key: ValueKey(s), navigatorKey: nav, theme: buildAppTheme(), home: const Scaffold(body: Text('Accueil'))));
      final builder = Theme.of(nav.currentContext!).pageTransitionsTheme.builders[TargetPlatform.android]!;
      expect(builder, AppPageTransitionsBuilder(s));
      expect(builder.transitionDuration, AppMotion.of(s).page);

      nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Détail'))));
      await tester.pump();
      await tester.pump(AppMotion.of(s).page * 0.5);
      expect(tester.takeException(), isNull, reason: '${s.name}: page');
      await tester.pumpAndSettle();
      expect(find.text('Détail'), findsOneWidget);

      showAppDialog(context: nav.currentContext!, builder: (_) => const AlertDialog(content: Text('Dialogue')));
      await tester.pump();
      await tester.pump(AppMotion.of(s).dialog * 0.5);
      expect(tester.takeException(), isNull, reason: '${s.name}: dialog');
      await tester.pumpAndSettle();
      expect(find.text('Dialogue'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Dialogue'), findsNothing);

      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(AppMotion.of(s).pageReverse * 0.5);
      expect(tester.takeException(), isNull, reason: '${s.name}: back');
      await tester.pumpAndSettle();
      expect(find.text('Accueil'), findsOneWidget);
    }
  });

  testWidgets('pages come and go along the vertical, never sideways', (tester) async {
    // A full-width band: its centre only moves sideways if the page does
    // (zooming from the centre leaves it put).
    Widget page(String key) => Scaffold(body: Center(child: SizedBox(key: ValueKey(key), width: double.infinity, height: 40)));
    for (final s in SurfaceStyle.values) {
      AppColors.configure(dark: false, appearance: Appearance(surface: s));
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(key: ValueKey(s), navigatorKey: nav, theme: buildAppTheme(), home: page('accueil')));
      final mid = tester.getCenter(find.byKey(const ValueKey('accueil'))).dx;
      nav.currentState!.push(MaterialPageRoute(builder: (_) => page('profil')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(AppMotion.of(s).page * 0.25);
        expect(tester.getCenter(find.byKey(const ValueKey('profil'))).dx, closeTo(mid, 0.01), reason: '${s.name}: the page coming in');
        expect(tester.getCenter(find.byKey(const ValueKey('accueil'), skipOffstage: false)).dx, closeTo(mid, 0.01), reason: '${s.name}: the page behind');
      }
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(AppMotion.of(s).pageReverse * 0.5);
      expect(tester.getCenter(find.byKey(const ValueKey('profil'))).dx, closeTo(mid, 0.01), reason: '${s.name}: going back');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('with reduced motion, screens only fade', (tester) async {
    AppColors.configure(dark: false, appearance: const Appearance(surface: SurfaceStyle.brutalist));
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const Scaffold(body: Text('Accueil')),
    ));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Détail'))));
    await tester.pump();
    await tester.pump(AppMotion.of(SurfaceStyle.brutalist).page * 0.5);
    final midway = tester.getTopLeft(find.text('Détail'));
    await tester.pumpAndSettle();
    expect(midway, tester.getTopLeft(find.text('Détail')), reason: 'not dropped in: already in place');
  });
}
