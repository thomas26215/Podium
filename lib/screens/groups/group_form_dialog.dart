import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth;

const _emojiChoices = ['🃏', '🎯', '🎲', '🏆', '🌙', '💼', '🔥', '⭐'];

/// Create-group / create-subgroup form. When [parentId] is set this creates
/// a subgroup under it instead of a new root community.
class GroupFormDialog extends StatefulWidget {
  final String? parentId;
  const GroupFormDialog({super.key, this.parentId});

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _nameCtrl = TextEditingController();
  String _emoji = _emojiChoices.first;

  // Only meaningful for a root group (see Group.temporary) — a subgroup's
  // lifecycle always follows its root's, same as `closed`.
  bool _temporary = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // A root group set to "Temporaire" skips the name field entirely — asking
  // for a name is friction that doesn't make sense for a one-off group, so
  // one is auto-generated from today's date instead (see [_autoName]).
  bool get _nameless => widget.parentId == null && _temporary;

  String get _autoName => 'Groupe du ${frenchDayMonth(DateTime.now())}';

  Future<void> _submit(AppState app) async {
    if (!_nameless && _nameCtrl.text.trim().isEmpty) return;
    final bg = kAvatarPalette[_emojiChoices.indexOf(_emoji) % kAvatarPalette.length];
    final bgColor = Color(bg).withValues(alpha: 0.16).toARGB32();
    final name = _nameless ? _autoName : _nameCtrl.text;
    if (widget.parentId == null) {
      await app.createGroup(name: name, emoji: _emoji, emojiBg: bgColor, temporary: _temporary);
    } else {
      await app.createSubGroup(parentId: widget.parentId!, name: name, emoji: _emoji, emojiBg: bgColor);
    }
    if (app.flowError == null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.parentId == null ? 'Créer un groupe' : 'Créer un sous-groupe', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 18),
            if (widget.parentId == null) ...[
              Text('Durée de vie', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _LifespanCard(
                      label: 'Permanent',
                      sub: 'Reste actif indéfiniment',
                      selected: !_temporary,
                      onTap: () => setState(() => _temporary = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LifespanCard(
                      label: 'Temporaire',
                      sub: 'Ex. un week-end entre amis',
                      selected: _temporary,
                      onTap: () => setState(() => _temporary = true),
                    ),
                  ),
                ],
              ),
              if (_temporary) ...[
                const SizedBox(height: 8),
                Text(
                  "Vous pourrez le fermer une fois terminé — l'historique et le classement resteront visibles, sans possibilité d'ajouter de nouvelles parties.",
                  style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (_nameless) ...[
              Text('Nom', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text('Nommé automatiquement : « $_autoName »', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.mut)),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text('Nom', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
              const SizedBox(height: 9),
              TextField(
                controller: _nameCtrl,
                style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Emoji', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojiChoices)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _emoji == e ? AppColors.accentSoft : AppColors.card,
                        border: Border.all(color: _emoji == e ? AppColors.accent : AppColors.line, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            if (app.flowError != null) ...[
              const SizedBox(height: 12),
              Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Créer', loading: app.busy, onPressed: () => _submit(app)),
          ],
        ),
      ),
    );
  }
}

class _LifespanCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _LifespanCard({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
            const SizedBox(height: 2),
            Text(sub, style: bodyFont(size: 11, weight: FontWeight.w600, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.mut)),
          ],
        ),
      ),
    );
  }
}
