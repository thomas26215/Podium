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
    if (app.authLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (app.currentUser == null) {
      return const LoginScreen();
    }
    if (app.groupsLoading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (app.groups.isEmpty) {
      return const NoGroupScreen();
    }
    return const MainShell();
  }
}
