import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Sits right under MaterialApp (its `builder`) and applies the appearance
/// settings that reach above every screen — text size, reduced motion — and
/// restyles the whole tree whenever the appearance or light/dark mode
/// changes. Widgets read the theme from the static `AppColors`, so without
/// this a const widget (a `SectionHeader`, an `EmptyState`…) would keep its
/// old colours until something happened to rebuild it.
class AppearanceScope extends StatefulWidget {
  final Widget child;
  const AppearanceScope({super.key, required this.child});

  @override
  State<AppearanceScope> createState() => _AppearanceScopeState();
}

class _AppearanceScopeState extends State<AppearanceScope> {
  static const _throttle = Duration(milliseconds: 250);

  AppTokens? _styled;
  DateTime? _lastRestyle;
  Timer? _trailing;

  /// Marks every element below dirty — they rebuild in the same frame,
  /// keeping their state (scroll positions, open routes, typed text).
  void _restyleAll() {
    _lastRestyle = DateTime.now();
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  /// Restyles at once for a one-off change (a tap), but at most every
  /// [_throttle] while a hue slider streams changes — the screens that
  /// watch the state, the settings among them, follow every step anyway.
  void _requestRestyle() {
    final last = _lastRestyle;
    if (last == null || DateTime.now().difference(last) > _throttle) {
      _trailing?.cancel();
      _restyleAll();
      return;
    }
    _trailing?.cancel();
    _trailing = Timer(_throttle, () {
      if (mounted) _restyleAll();
    });
  }

  @override
  void dispose() {
    _trailing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.select<AppState, Appearance>((app) => app.appearance);
    context.select<AppState, bool>((app) => app.isDark);
    final tokens = AppColors.tokens;
    if (_styled != null && tokens != _styled) _requestRestyle();
    _styled = tokens;

    final mq = MediaQuery.of(context);
    final scale = appearance.textSize.scale;
    return MediaQuery(
      data: mq.copyWith(
        textScaler: scale == 1 ? mq.textScaler : TextScaler.linear(mq.textScaler.scale(14) / 14 * scale),
        disableAnimations: mq.disableAnimations || appearance.reduceMotion,
      ),
      child: widget.child,
    );
  }
}
