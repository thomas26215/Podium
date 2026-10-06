import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'group_form_dialog.dart';
import 'group_members_dialog.dart';
import 'groups_screen.dart' show confirmCloseGroup, confirmDeleteGroup;
import 'invite_dialog.dart';
import 'reassign_member_dialog.dart';

/// A group's settings, Discord-style: its identity up top, then sections of
/// rows — an editable overview (owner only, with a "unsaved changes" bar
/// sliding up while it differs from the saved group), members & invites,
/// and a danger zone (close / delete / leave). Pops itself once the group
/// is gone (deleted or left).
class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _nameCtrl = TextEditingController();
  late String _emoji;
  late bool _temporary;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    final group = context.read<AppState>().groupById(widget.groupId);
    if (group != null) _reset(group);
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _reset(Group group) {
    _nameCtrl.text = group.name;
    _emoji = group.emoji;
    _temporary = group.temporary;
  }

  bool _dirty(Group group) => _nameCtrl.text.trim() != group.name || _emoji != group.emoji || _temporary != group.temporary;

  Future<void> _save(AppState app, Group group) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    await app.updateGroupSettings(
      group,
      name: _nameCtrl.text,
      emoji: _emoji,
      emojiBg: _emoji == group.emoji ? group.emojiBg : groupEmojiBg(_emoji),
      temporary: _temporary,
    );
  }

  void _openDialog(AppState app, Widget dialog) {
    app.flowError = null;
    showAppDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: dialog));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final group = app.groupById(widget.groupId);
    if (group == null) {
      if (!_popped) {
        _popped = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      }
      return Scaffold(backgroundColor: AppColors.canvas);
    }
    final isOwner = app.canCloseGroup(group);
    final closed = group.closed;
    final dirty = isOwner && _dirty(group);
    final members = app.getGroupMemberIds(group.id).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text('Paramètres du groupe', style: dispFont(size: 17, weight: FontWeight.w700, color: AppColors.ink)),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: dirty
            ? _UnsavedBar(
                busy: app.busy,
                canSave: _nameCtrl.text.trim().isNotEmpty,
                onReset: () => setState(() => _reset(group)),
                onSave: () => _save(app, group),
              )
            : const SizedBox(width: double.infinity),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          // The page cascades in, section by section.
          children: staggered(stepMs: 45, [
            _Hero(emoji: _emoji, emojiBg: _emoji == group.emoji ? group.emojiBg : groupEmojiBg(_emoji), name: group.name, subtitle: '$members joueurs', closed: closed, temporary: group.temporary),
            if (isOwner) ...[
              const _Label("VUE D'ENSEMBLE"),
              _Panel(
                padding: const EdgeInsets.all(16),
                children: [
                  _FieldLabel('Nom du groupe'),
                  TextField(
                    controller: _nameCtrl,
                    enabled: !closed,
                    style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: appFieldDecoration(),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Emoji'),
                  IgnorePointer(
                    ignoring: closed,
                    child: GroupEmojiPicker(choices: groupEmojiChoices(group.emoji), selected: _emoji, onChanged: (e) => setState(() => _emoji = e)),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Durée de vie'),
                  IgnorePointer(
                    ignoring: closed,
                    child: LifespanPicker(temporary: _temporary, onChanged: (v) => setState(() => _temporary = v)),
                  ),
                  if (closed) ...[
                    const SizedBox(height: 12),
                    Text('Rouvrez le groupe pour modifier ses paramètres.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                  if (app.flowError != null && dirty) ...[
                    const SizedBox(height: 12),
                    Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                  ],
                ],
              ),
            ],
            const _Label('MEMBRES'),
            _Panel(
              children: [
                _Row(
                  icon: Icons.people_alt_rounded,
                  title: 'Membres',
                  trailing: '$members',
                  onTap: () => _openDialog(app, GroupMembersDialog(groupId: group.id)),
                ),
                if (!closed)
                  _Row(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Inviter un ami',
                    onTap: () => _openDialog(app, InviteDialog(groupId: group.id, groupName: group.name)),
                  ),
                if (isOwner && !closed)
                  _Row(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Réassigner un membre',
                    onTap: () => _openDialog(app, ReassignMemberDialog(rootGroupId: group.id, rootGroupName: group.name)),
                  ),
              ],
            ),
            const _Label('ZONE DANGEREUSE'),
            _Panel(
              children: [
                if (isOwner)
                  _Row(
                    icon: closed ? Icons.lock_open_rounded : Icons.lock_rounded,
                    title: closed ? 'Rouvrir le groupe' : 'Fermer le groupe',
                    subtitle: closed ? null : "L'historique reste visible, plus rien ne peut être ajouté.",
                    onTap: () => closed ? app.setGroupClosed(group.id, false) : confirmCloseGroup(context, app, group, closed: true),
                  ),
                if (isOwner)
                  _Row(
                    icon: Icons.delete_outline_rounded,
                    title: 'Supprimer le groupe',
                    danger: true,
                    onTap: () => confirmDeleteGroup(context, app, group),
                  )
                else
                  _Row(
                    icon: Icons.logout_rounded,
                    title: 'Quitter le groupe',
                    danger: true,
                    onTap: () => confirmLeaveGroup(context, app, group),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String emoji;
  final int emojiBg;
  final String name;
  final String subtitle;
  final bool closed;
  final bool temporary;
  const _Hero({required this.emoji, required this.emojiBg, required this.name, required this.subtitle, required this.closed, required this.temporary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Color(emojiBg), borderRadius: BorderRadius.circular(24)),
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: dispFont(size: 22, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(
            [subtitle, if (closed) 'clos' else if (temporary) 'temporaire'].join(' · '),
            style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 20, bottom: 8),
      child: Text(label, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
    );
  }
}

/// A card grouping a section's rows, separated by thin dividers.
class _Panel extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const _Panel({required this.children, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final rows = children.every((c) => c is _Row);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(radius: AppRadius.lg, borderWidth: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (rows && i > 0) Divider(height: 1, thickness: 1, color: AppColors.line),
            c,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool danger;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, this.subtitle, this.trailing, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : AppColors.ink;
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: danger ? Colors.red : AppColors.ink2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 15, weight: FontWeight.w700, color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              Text(trailing!, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.mut)),
              const SizedBox(width: 4),
            ],
            if (!danger) Icon(Icons.chevron_right_rounded, color: AppColors.mut),
          ],
        ),
      ),
    );
  }
}

/// Discord's "Attention, il reste des modifications non enregistrées !"
/// bar — slid in by [GroupSettingsScreen] while the overview is dirty.
class _UnsavedBar extends StatelessWidget {
  final bool busy;
  final bool canSave;
  final VoidCallback onReset;
  final VoidCallback onSave;
  const _UnsavedBar({required this.busy, required this.canSave, required this.onReset, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: heroDecoration(radius: AppRadius.lg, depth: 0.6),
        child: Row(
          children: [
            Expanded(
              child: Text('Modifications non enregistrées', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
            ),
            TextButton(
              onPressed: busy ? null : onReset,
              child: Text('Annuler', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: busy || !canSave ? null : onSave,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
