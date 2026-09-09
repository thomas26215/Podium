import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _emojiChoices = ['🎮', '🃏', '🎲', '🏆', '⏱️', '🎯', '🕹️', '⭐'];

/// Create-salon form — admin/owner only, opened from [ServerDetailScreen].
class SalonFormDialog extends StatefulWidget {
  final String serverId;
  const SalonFormDialog({super.key, required this.serverId});

  @override
  State<SalonFormDialog> createState() => _SalonFormDialogState();
}

class _SalonFormDialogState extends State<SalonFormDialog> {
  final _nameCtrl = TextEditingController();
  String _emoji = _emojiChoices.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final bg = kAvatarPalette[_emojiChoices.indexOf(_emoji) % kAvatarPalette.length];
    final bgColor = Color(bg).withValues(alpha: 0.16).toARGB32();
    await app.createSalon(serverId: widget.serverId, name: _nameCtrl.text, emoji: _emoji, emojiBg: bgColor);
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
            Text('Créer un salon', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              'Ex. « Tournoi TCG du jeudi » — un espace dédié avec sa propre liste de joueurs.',
              style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
            ),
            const SizedBox(height: 18),
            Text('Nom', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 9),
            TextField(
              controller: _nameCtrl,
              style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
              decoration: appFieldDecoration(hintText: 'Ex. Tournoi TCG du jeudi'),
            ),
            const SizedBox(height: 16),
            Text('Emoji', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojiChoices)
                  Pressable(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
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
