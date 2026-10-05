import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../groups/no_group_screen.dart';
import '../shell/main_shell.dart';
import 'login_screen.dart';

/// Root of the widget tree below MaterialApp: shows a spinner while the
/// initial auth check resolves, the login flow when signed out, and the
/// tabbed app shell once signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final Widget child;
    final Key key;
    if (app.authLoading) {
      key = const ValueKey('authLoading');
      child = Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: PodiumLoader(size: 40)),
      );
    } else if (app.currentUser == null) {
      key = const ValueKey('login');
      child = const LoginScreen();
    } else if (app.groupsLoading) {
      key = const ValueKey('groupsLoading');
      child = Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: PodiumLoader(size: 40)),
      );
    } else if (app.groups.isEmpty && !app.isPersonalContext) {
      key = const ValueKey('noGroup');
      child = const NoGroupScreen();
    } else {
      key = const ValueKey('shell');
      child = const MainShell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The incoming screen settles from slightly enlarged while fading in —
      // reads as "arriving" rather than a flat cross-fade.
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween<double>(begin: 1.03, end: 1).animate(a), child: child),
      ),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}
