import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/app_user.dart';
import '../../models/group_invite_code.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

class InviteDialog extends StatefulWidget {
  final String groupId;
  final String groupName;
  const InviteDialog({super.key, required this.groupId, required this.groupName});

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

enum _InviteMode { email, guest, qr }

class _InviteDialogState extends State<InviteDialog> {
  final _emailCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();
  _InviteMode _mode = _InviteMode.email;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _guestNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_emailCtrl.text.trim().isEmpty) return;
    final ok = await app.addMemberByEmail(groupId: widget.groupId, email: _emailCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _submitGuest(AppState app) async {
    if (_guestNameCtrl.text.trim().isEmpty) return;
    final ok = await app.addGuest(groupId: widget.groupId, displayName: _guestNameCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _addExisting(AppState app, AppUser person) async {
    final ok = await app.addMemberByUid(groupId: widget.groupId, uid: person.uid);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final group = app.groupById(widget.groupId);
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inviter un ami', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('Ajoutez-le à « ${widget.groupName} ».', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Expanded(child: _ModeTab(label: 'E-mail', selected: _mode == _InviteMode.email, onTap: () => setState(() => _mode = _InviteMode.email))),
                  Expanded(child: _ModeTab(label: 'Sans compte', selected: _mode == _InviteMode.guest, onTap: () => setState(() => _mode = _InviteMode.guest))),
                  Expanded(child: _ModeTab(label: 'QR code', selected: _mode == _InviteMode.qr, onTap: () => setState(() => _mode = _InviteMode.qr))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_mode == _InviteMode.email) ...[
              Builder(builder: (_) {
                final alreadyIn = app.getGroupMemberIds(widget.groupId).toSet();
                final suggestions = app.friends.where((f) => !alreadyIn.contains(f.uid)).toList();
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VOS AMIS', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in suggestions)
                            GestureDetector(
                              onTap: app.busy ? null : () => _addExisting(app, f),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Avatar(initial: f.initial, color: Color(f.color), size: 26, fontSize: 11),
                                    const SizedBox(width: 7),
                                    Text(f.displayName, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('OU PAR E-MAIL', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'ami@exemple.com',
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Votre ami doit déjà avoir un compte Podium.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
              ),
              if (app.flowError != null) ...[
                const SizedBox(height: 8),
                Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Ajouter', loading: app.busy, onPressed: () => _submit(app)),
            ] else if (_mode == _InviteMode.guest) ...[
              Builder(builder: (_) {
                final alreadyIn = app.getGroupMemberIds(widget.groupId).toSet();
                final suggestions = app.knownGuests.where((g) => !alreadyIn.contains(g.uid)).toList();
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DÉJÀ AJOUTÉS AILLEURS', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in suggestions)
                            GestureDetector(
                              onTap: app.busy ? null : () => _addExisting(app, g),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Avatar(initial: g.initial, color: Color(g.color), size: 26, fontSize: 11),
                                    const SizedBox(width: 7),
                                    Text(g.displayName, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Réutilise le même profil — ses parties précédentes restent liées à cette personne.',
                        style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut),
                      ),
                      const SizedBox(height: 14),
                      Text('OU UNE NOUVELLE PERSONNE', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
              TextField(
                controller: _guestNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Nom du joueur',
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Il pourra jouer sans compte Podium ; vous pourrez le relier à un vrai compte plus tard.",
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ),
              if (app.flowError != null) ...[
                const SizedBox(height: 8),
                Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
              ],
              const SizedBox(height: 20),
              PrimaryButton(label: 'Ajouter', loading: app.busy, onPressed: () => _submitGuest(app)),
            ] else if (group != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: QrImageView(
                    data: GroupInviteCode(
                      groupId: group.id,
                      rootId: group.isRoot ? group.id : (group.parentId ?? group.id),
                      name: group.name,
                      emoji: group.emoji,
                    ).encode(),
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Faites scanner ce code par votre ami depuis Podium pour le faire rejoindre le groupe instantanément.',
                textAlign: TextAlign.center,
                style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
