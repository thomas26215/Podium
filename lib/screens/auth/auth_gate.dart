import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
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
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    } else if (app.currentUser == null) {
      key = const ValueKey('login');
      child = const LoginScreen();
    } else if (app.groupsLoading) {
      key = const ValueKey('groupsLoading');
      child = Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    } else if (app.groups.isEmpty) {
      key = const ValueKey('noGroup');
      child = const NoGroupScreen();
    } else {
      key = const ValueKey('shell');
      child = const MainShell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}
