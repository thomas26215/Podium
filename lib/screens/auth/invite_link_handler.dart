import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_invite_code.dart';
import '../../models/server_invite_code.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Catches invite links opening the app (a shared link — see
/// [inviteLinkFor] — lands here as its `podium://` code) and, once someone
/// is signed in, asks whether to join before doing it, exactly like a
/// scanned QR code would. A link arriving before sign-in waits for it.
class InviteLinkHandler extends StatefulWidget {
  final Widget child;

  /// Incoming links; defaults to the platform's (including the link that
  /// launched the app). Overridable for tests.
  final Stream<Uri>? links;

  const InviteLinkHandler({super.key, required this.child, this.links});

  @override
  State<InviteLinkHandler> createState() => _InviteLinkHandlerState();
}

class _InviteLinkHandlerState extends State<InviteLinkHandler> {
  StreamSubscription<Uri>? _sub;
  String? _pending;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    try {
      _sub = (widget.links ?? AppLinks().uriLinkStream).listen(_onLink, onError: (_) {});
    } catch (_) {
      // No link plugin on this platform (desktop preview, tests) — nothing to catch.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onLink(Uri uri) {
    final code = unwrapInviteCode(uri.toString());
    if (code == null) return;
    setState(() => _pending = code);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ready = app.currentUser != null && !app.authLoading && !app.groupsLoading && !app.serversLoading;
    if (_pending != null && ready && !_prompting) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
    return widget.child;
  }

  Future<void> _prompt() async {
    final code = _pending;
    if (code == null || _prompting || !mounted) return;
    _prompting = true;
    _pending = null;
    try {
      final invite = _describe(code);
      if (invite == null) return;
      final app = context.read<AppState>();
      final join = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: Text('${invite.emoji} Rejoindre « ${invite.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          content: Text('Vous avez reçu une invitation à rejoindre ${invite.kind} sur Podium.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Rejoindre')),
          ],
        ),
      );
      if (join != true || !mounted) return;
      final ok = await invite.join(app);
      if (ok || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.bg,
          title: Text('Impossible de rejoindre', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          content: Text(app.flowError ?? "Cette invitation n'est plus valable.", style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
    } finally {
      _prompting = false;
      // Another link may have arrived while this one was being handled.
      if (mounted && _pending != null) setState(() {});
    }
  }

  static _Invite? _describe(String code) {
    final group = GroupInviteCode.tryParse(code);
    if (group != null) return _Invite(group.name, group.emoji, 'ce groupe', (app) => app.joinGroupByCode(code));
    final server = ServerInviteCode.tryParse(code);
    if (server != null) return _Invite(server.name, server.emoji, 'ce serveur', (app) => app.joinServerByCode(code));
    final salon = SalonInviteCode.tryParse(code);
    if (salon != null) return _Invite(salon.name, salon.emoji, 'ce salon', (app) => app.joinSalonByCode(code));
    return null;
  }
}

class _Invite {
  final String name;
  final String emoji;
  final String kind;
  final Future<bool> Function(AppState app) join;
  const _Invite(this.name, this.emoji, this.kind, this.join);
}
