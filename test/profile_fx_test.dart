import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:podium/logic/badges.dart';
import 'package:podium/widgets/ambient_loop.dart';
import 'package:podium/widgets/badge_widgets.dart';
import 'package:podium/widgets/profile_banners.dart';
import 'package:podium/widgets/profile_style.dart';

/// Google Fonts downloads the app's fonts on first use, and the test HTTP
/// client fails that download — failing the test — once real async work
/// runs (see [_capture]). Left unanswered, text just keeps the test font.
class _Offline extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _UnansweredClient();
}

class _UnansweredClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Completer<HttpClientRequest>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The last phase an ambient loop shows before wrapping back to 0.
const _last = 1 - 1e-5;

/// Renders [child] at [size] and returns its RGBA pixels.
Future<Uint8List> _capture(WidgetTester tester, Widget child, Size size) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Center(child: RepaintBoundary(key: key, child: SizedBox(width: size.width, height: size.height, child: child))),
  ));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

/// How much a loop jumps when it wraps: the share of pixels that differ
/// noticeably between its last frame and its first.
Future<double> _seam(WidgetTester tester, Widget Function(double ph) at, Size size) async {
  final start = await _capture(tester, at(0), size);
  final end = await _capture(tester, at(_last), size);
  return _diff(start, end);
}

String _pct(double share) => '${(share * 100).toStringAsFixed(2)} % of pixels';

/// The share of pixels that differ noticeably between two captures.
double _diff(Uint8List a, Uint8List b) {
  expect(a.length, b.length);
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 4; c++) {
      if ((a[i + c] - b[i + c]).abs() > 40) {
        differing++;
        break;
      }
    }
  }
  return differing / (a.length / 4);
}

void main() {
  setUpAll(() => HttpOverrides.global = _Offline());

  final animated = kBannerThemes.where((b) => b.animated).toList();
  const sizes = [Size(340, 210), Size(390, 560), Size(260, 120)];

  group('banners', () {
    test('every scene paints at any moment, on short, tall and narrow cards', () {
      for (final theme in animated) {
        for (final size in sizes) {
          for (final t in const [0.0, 0.4, 1.0]) {
            for (final ph in const [0.0, 0.13, 0.5, 0.77, 0.999]) {
              final recorder = ui.PictureRecorder();
              theme.motif!(Canvas(recorder), size, t, ph);
              recorder.endRecording().dispose();
            }
          }
        }
      }
    });

    testWidgets('every loop is seamless: its last frame matches its first', (tester) async {
      final jumps = <String>[];
      for (final theme in animated) {
        for (final size in const [Size(340, 210), Size(390, 560)]) {
          final seam = await _seam(tester, (ph) => ProfileBannerBackground(themeId: theme.id, phase: ph), size);
          if (seam > 0.002) jumps.add('${theme.id} at $size: ${_pct(seam)}');
        }
      }
      expect(jumps, isEmpty, reason: 'these loops jump when they restart');
    });
  });

  group('avatar frames', () {
    testWidgets('every frame paints at any moment and loops seamlessly', (tester) async {
      final jumps = <String>[];
      for (final frame in kAvatarFrames) {
        Widget at(double ph) => FramedAvatar(frameId: frame.id, size: 72, phase: ph, child: const CircleAvatar(backgroundColor: Colors.deepOrange));
        for (final ph in const [0.2, 0.55, 0.9]) {
          await _capture(tester, at(ph), const Size(140, 140));
          expect(tester.takeException(), isNull, reason: frame.id);
        }
        final seam = await _seam(tester, at, const Size(140, 140));
        if (seam > 0.002) jumps.add('${frame.id}: ${_pct(seam)}');
      }
      expect(jumps, isEmpty, reason: 'these frames jump when their loop restarts');
    });
  });

  group('name effects', () {
    testWidgets('every effect renders and loops seamlessly', (tester) async {
      final jumps = <String>[];
      for (final effect in kNameEffects.where((e) => e.id != null)) {
        Widget at(double ph) => ColoredBox(
              color: const Color(0xFF2B1D4F),
              child: Align(alignment: Alignment.centerLeft, child: StyledName(text: 'Léa la Rouge', effectId: effect.id, accent: Colors.deepOrange, phase: ph)),
            );
        for (final ph in const [0.2, 0.55, 0.9]) {
          await _capture(tester, at(ph), const Size(260, 60));
          expect(tester.takeException(), isNull, reason: effect.id);
        }
        final seam = await _seam(tester, at, const Size(260, 60));
        if (seam > 0.004) jumps.add('${effect.id}: ${_pct(seam)}');
      }
      expect(jumps, isEmpty, reason: 'these name effects jump when their loop restarts');
    });
  });

  group('profile effects', () {
    test('every effect paints through its intro and its ambient loop', () {
      for (final effect in kProfileEffects) {
        for (final size in sizes) {
          for (final intro in const [0.0, 0.1, 0.3, 0.6, 0.95, null]) {
            for (final ph in const [0.0, 0.4, 0.999]) {
              final recorder = ui.PictureRecorder();
              ProfileEffectPainter(effect.id, intro: intro, ph: ph, ambient: intro == null ? 1 : 0.5).paint(Canvas(recorder), size);
              recorder.endRecording().dispose();
            }
          }
        }
      }
    });

    testWidgets('every ambient loop is seamless', (tester) async {
      final jumps = <String>[];
      for (final effect in kProfileEffects) {
        Widget at(double ph) => ColoredBox(color: Colors.black, child: CustomPaint(painter: ProfileEffectPainter(effect.id, intro: null, ph: ph, ambient: 1), size: Size.infinite));
        final seam = await _seam(tester, at, const Size(340, 210));
        if (seam > 0.002) jumps.add('${effect.id}: ${_pct(seam)}');
      }
      expect(jumps, isEmpty, reason: 'these effects jump when their loop restarts');
    });
  });

  group('prestige medals', () {
    testWidgets('every tier above gold paints at any moment, locked or not, and loops seamlessly', (tester) async {
      final jumps = <String>[];
      for (final tier in BadgeTier.values.where((t) => t.index > BadgeTier.gold.index)) {
        final badge = kBadges.firstWhere((b) => b.tier == tier);
        Widget at(double ph) => ColoredBox(color: Colors.white, child: Center(child: BadgeMedal(badge: badge, earned: true, size: 96, phase: ph)));
        for (final ph in const [0.2, 0.55, 0.9]) {
          await _capture(tester, at(ph), const Size(120, 120));
          expect(tester.takeException(), isNull, reason: tier.name);
        }
        await _capture(tester, BadgeMedal(badge: badge, earned: false, size: 56, progress: 0.6), const Size(80, 80));
        await tester.pump(const Duration(seconds: 1)); // the progress traced along the outline
        expect(tester.takeException(), isNull, reason: '${tier.name}, locked');
        final seam = await _seam(tester, at, const Size(120, 120));
        if (seam > 0.002) jumps.add('${tier.name}: ${_pct(seam)}');
      }
      expect(jumps, isEmpty, reason: 'these medals jump when their loop restarts');
    });
  });

  testWidgets('ambient loops hold still when the system asks for less motion', (tester) async {
    var builds = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: AmbientLoop(builder: (context, ph) {
        builds++;
        expect(ph, 0);
        return const SizedBox();
      }),
    ));
    final before = builds;
    await tester.pumpAndSettle(); // would time out if the loop kept ticking
    expect(builds, before);
  });

  testWidgets('a live banner keeps moving, then rests once its route is covered', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProfileBannerBackground(themeId: 'arcade'))));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the scene loops');
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('dessus'))));
    await tester.pumpAndSettle(); // settles: the covered banner's ticker is muted
    expect(find.text('dessus'), findsOneWidget);
  });
}
