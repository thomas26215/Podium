import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/guests_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// Hands a group member's slot over to a different existing account — pick
/// who to replace, then the e-mail of the account that should take over.
/// Rewrites the whole match history too (see `AppState.reassignMember`), so
/// this is scoped to root communities and gated to the owner in the caller.
class ReassignMemberDialog extends StatefulWidget {
  final String rootGroupId;
  final String rootGroupName;
  const ReassignMemberDialog({super.key, required this.rootGroupId, required this.rootGroupName});

  @override
  State<ReassignMemberDialog> createState() => _ReassignMemberDialogState();
}

class _ReassignMemberDialogState extends State<ReassignMemberDialog> {
  String? _oldUid;
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    final oldUid = _oldUid;
    if (oldUid == null || _emailCtrl.text.trim().isEmpty) return;
    final ok = await app.reassignMember(rootGroupId: widget.rootGroupId, oldUid: oldUid, newEmail: _emailCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final memberIds = app.getGroupMemberIds(widget.rootGroupId);
    final oldUid = _oldUid;

    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réassigner un membre', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('« ${widget.rootGroupName} »', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut)),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: oldUid == null
                  ? Column(
                      key: const ValueKey('pick'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quel membre remplacer ?', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
                        const SizedBox(height: 9),
                        if (memberIds.isEmpty)
                          Text('Aucun membre avec un compte dans ce groupe.', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut))
                        else
                          for (final (i, uid) in memberIds.indexed)
                            Builder(builder: (_) {
                              final p = app.playerById(uid);
                              return FadeSlideIn(
                                delay: Duration(milliseconds: i * 40),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Pressable(
                                    onTap: () => setState(() => _oldUid = uid),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
                                      child: Row(
                                        children: [
                                          Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 32, fontSize: 13),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(p?.displayName ?? uid, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                                          Icon(Icons.chevron_right_rounded, color: AppColors.mut),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                      ],
                    )
                  : Column(
                      key: const ValueKey('confirm'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Builder(builder: (_) {
                                final p = app.playerById(oldUid);
                                return Text('Remplacer ${p?.displayName ?? oldUid} par :', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink));
                              }),
                            ),
                            GestureDetector(onTap: () => setState(() => _oldUid = null), child: Text('Changer', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.accent))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                          decoration: appFieldDecoration(hintText: 'nouveau-compte@exemple.com'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isGuestId(oldUid)
                                ? "Cette personne n'a pas de compte : ce nouveau compte la remplacera partout où elle apparaît (tous les groupes concernés, pas seulement « ${widget.rootGroupName} »), avec toutes ses parties déjà enregistrées. Action irréversible."
                                : "Toutes les parties déjà enregistrées seront réattribuées à ce compte, qui remplacera l'ancien dans tout le groupe. Action irréversible.",
                            style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                          ),
                        ),
                        if (app.flowError != null) ...[
                          const SizedBox(height: 8),
                          Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(label: 'Réassigner', loading: app.busy, onPressed: () => _submit(app)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
