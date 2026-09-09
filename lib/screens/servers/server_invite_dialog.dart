import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/server_invite_code.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _InviteMode { email, qr }

/// Invite dialog for a [Server] — narrower than a Group's [InviteDialog]:
/// the e-mail tab only shows for owner/admins (see
/// AppState.addServerMemberByEmail), since a Server's roster isn't a
/// free-for-all. Anyone can still show/scan the QR tab to self-join.
class ServerInviteDialog extends StatefulWidget {
  final String serverId;
  final String serverName;
  const ServerInviteDialog({super.key, required this.serverId, required this.serverName});

  @override
  State<ServerInviteDialog> createState() => _ServerInviteDialogState();
}

class _ServerInviteDialogState extends State<ServerInviteDialog> {
  final _emailCtrl = TextEditingController();
  _InviteMode _mode = _InviteMode.qr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AppState>().refreshServerInviteWindow(widget.serverId));
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_emailCtrl.text.trim().isEmpty) return;
    final ok = await app.addServerMemberByEmail(serverId: widget.serverId, email: _emailCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _selectMode(_InviteMode mode, AppState app) {
    setState(() => _mode = mode);
    if (mode == _InviteMode.qr) unawaited(app.refreshServerInviteWindow(widget.serverId));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final server = app.serverById(widget.serverId);
    final isAdmin = server != null && app.isServerAdmin(server);
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inviter au serveur', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('Ajoutez-le à « ${widget.serverName} ».', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut)),
            const SizedBox(height: 16),
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Row(
                  children: [
                    Expanded(child: _ModeTab(label: 'E-mail', selected: _mode == _InviteMode.email, onTap: () => _selectMode(_InviteMode.email, app))),
                    Expanded(child: _ModeTab(label: 'QR code', selected: _mode == _InviteMode.qr, onTap: () => _selectMode(_InviteMode.qr, app))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: (isAdmin && _mode == _InviteMode.email)
                  ? Column(
                      key: const ValueKey(_InviteMode.email),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                          decoration: appFieldDecoration(hintText: 'membre@exemple.com'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Il doit déjà avoir un compte Podium.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                        ),
                        if (app.flowError != null) ...[
                          const SizedBox(height: 8),
                          Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(label: 'Ajouter', loading: app.busy, onPressed: () => _submit(app)),
                      ],
                    )
                  : server == null
                      ? const SizedBox.shrink(key: ValueKey(_InviteMode.qr))
                      : Column(
                          key: const ValueKey(_InviteMode.qr),
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                                child: QrImageView(
                                  data: ServerInviteCode(serverId: server.id, name: server.name, emoji: server.emoji).encode(),
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Faites scanner ce code pour rejoindre le serveur instantanément.',
                              textAlign: TextAlign.center,
                              style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Valable 30 minutes — rouvrez cet écran pour en générer un nouveau.',
                              textAlign: TextAlign.center,
                              style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: bodyFont(size: 13, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.mut),
        ),
      ),
    );
  }
}
