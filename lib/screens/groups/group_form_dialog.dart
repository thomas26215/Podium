import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth;

const _emojiChoices = ['🃏', '🎯', '🎲', '🏆', '🌙', '💼', '🔥', '⭐'];

/// The emojis a group can pick from — plus `current` up front when it isn't
/// one of them (an older group's), so editing it doesn't silently swap it.
List<String> groupEmojiChoices([String? current]) => [
      if (current != null && !_emojiChoices.contains(current)) current,
      ..._emojiChoices,
    ];

/// The tinted background behind `emoji`, derived from its position among
/// the standard choices so each emoji keeps a consistent color.
int groupEmojiBg(String emoji) =>
    Color(kAvatarPalette[_emojiChoices.indexOf(emoji).clamp(0, _emojiChoices.length) % kAvatarPalette.length]).withValues(alpha: 0.16).toARGB32();

/// Create-group form.
class GroupFormDialog extends StatefulWidget {
  const GroupFormDialog({super.key});

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _nameCtrl = TextEditingController();
  String _emoji = _emojiChoices.first;

  bool _temporary = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // A group set to "Temporaire" skips the name field entirely — asking for a
  // name is friction that doesn't make sense for a one-off group, so one is
  // auto-generated from today's date instead (see [_autoName]).
  bool get _nameless => _temporary;

  String get _autoName => 'Groupe du ${frenchDayMonth(DateTime.now())}';

  Future<void> _submit(AppState app) async {
    if (!_nameless && _nameCtrl.text.trim().isEmpty) return;
    final bgColor = groupEmojiBg(_emoji);
    final name = _nameless ? _autoName : _nameCtrl.text;
    await app.createGroup(
      name: name,
      emoji: _emoji,
      emojiBg: bgColor,
      temporary: _temporary,
    );
    if (app.flowError == null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créer un groupe',
              style: dispFont(
                size: 20,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Durée de vie',
              style: bodyFont(
                size: 12.5,
                weight: FontWeight.w800,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 9),
            LifespanPicker(temporary: _temporary, onChanged: (v) => setState(() => _temporary = v)),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _temporary
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Vous pourrez le fermer une fois terminé — l'historique et le classement resteront visibles, sans possibilité d'ajouter de nouvelles parties.",
                        style: bodyFont(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.mut,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 16),
            Text(
              'Nom',
              style: bodyFont(
                size: 12.5,
                weight: FontWeight.w800,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 9),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _nameless
                  ? Container(
                      key: const ValueKey('auto'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        'Nommé automatiquement : « $_autoName »',
                        style: bodyFont(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: AppColors.mut,
                        ),
                      ),
                    )
                  : TextField(
                      key: const ValueKey('field'),
                      controller: _nameCtrl,
                      style: bodyFont(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      decoration: appFieldDecoration(),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Emoji',
              style: bodyFont(
                size: 12.5,
                weight: FontWeight.w800,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 9),
            GroupEmojiPicker(choices: _emojiChoices, selected: _emoji, onChanged: (e) => setState(() => _emoji = e)),
            if (app.flowError != null) ...[
              const SizedBox(height: 12),
              Text(
                app.flowError!,
                style: bodyFont(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Créer',
              loading: app.busy,
              onPressed: () => _submit(app),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permanent / Temporaire — see [Group.temporary].
class LifespanPicker extends StatelessWidget {
  final bool temporary;
  final ValueChanged<bool> onChanged;
  const LifespanPicker({super.key, required this.temporary, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LifespanCard(
            label: 'Permanent',
            sub: 'Reste actif indéfiniment',
            selected: !temporary,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LifespanCard(
            label: 'Temporaire',
            sub: 'Ex. un week-end entre amis',
            selected: temporary,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class GroupEmojiPicker extends StatelessWidget {
  final List<String> choices;
  final String selected;
  final ValueChanged<String> onChanged;
  const GroupEmojiPicker({super.key, required this.choices, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in choices)
          Pressable(
            onTap: () => onChanged(e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == e ? AppColors.accentSoft : AppColors.card,
                border: Border.all(color: selected == e ? AppColors.accent : AppColors.line, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}

class _LifespanCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _LifespanCard({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: bodyFont(
                size: 13.5,
                weight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: bodyFont(
                size: 11,
                weight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.mut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
