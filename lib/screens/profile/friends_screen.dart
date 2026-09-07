import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// Personal address book (see [AppUser.friendIds]): people you play with
/// often, added once by e-mail here so the group-invite picker can suggest
/// them instead of typing an e-mail every time (see `InviteDialog`).
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Mes amis', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ajoutez les personnes avec qui vous jouez souvent — elles seront suggérées en premier quand vous inviterez quelqu'un dans un groupe.",
                style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const _AddFriendDialog())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 2), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.ink2),
                      const SizedBox(width: 8),
                      Text('Ajouter un ami par e-mail', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (app.friends.isEmpty)
                const EmptyState(emoji: '🧑‍🤝‍🧑', message: "Pas encore d'ami ajouté.")
              else
                for (final f in app.friends) _FriendRow(friend: f),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final AppUser friend;
  const _FriendRow({required this.friend});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Avatar(initial: friend.initial, color: Color(friend.color), size: 42, fontSize: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                Text(friend.email, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmRemove(context, app, friend),
            icon: Icon(Icons.close_rounded, size: 20, color: AppColors.mut),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, AppState app, AppUser friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Retirer ${friend.displayName} ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          "Il ne sera plus suggéré en premier quand vous inviterez quelqu'un — vous pourrez toujours l'ajouter par e-mail.",
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Retirer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await app.removeFriend(friend.uid);
  }
}

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_emailCtrl.text.trim().isEmpty) return;
    final ok = await app.addFriendByEmail(_emailCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
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
            Text('Ajouter un ami', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
              decoration: appFieldDecoration(hintText: 'ami@exemple.com'),
              onSubmitted: (_) => _submit(app),
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
          ],
        ),
      ),
    );
  }
}
