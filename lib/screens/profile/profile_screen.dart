import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../state/app_state.dart';
import '../../state/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../settings/settings_screen.dart';
import 'friends_screen.dart';

/// Reached by tapping the avatar button in the group/salon header (see
/// `HomeScreen`) or another player's name in the ranking/history —
/// always pushed as its own route, never a bottom tab.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final players = app.viewPlayers;
    final profileId = app.profileId ?? (players.isNotEmpty ? players.first.uid : null);
    final profile = profileId == null ? null : app.playerById(profileId);

    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.ink,
          title: Text('Profil', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 116),
            child: EmptyState(emoji: '👤', message: 'Aucun joueur à afficher.'),
          ),
        ),
      );
    }

    final winRows = app.standings('wins');
    final rank = winRows.indexWhere((r) => r.player.uid == profileId) + 1;
    final rows = app.computeRows(null);
    final mine = rows.where((r) => r.player.uid == profileId).toList();
    final played = mine.isNotEmpty ? mine.first.played : 0;
    final wins = mine.isNotEmpty ? mine.first.wins : 0;
    final ratio = mine.isNotEmpty ? mine.first.ratio : 0.0;
    final points = mine.isNotEmpty ? mine.first.points : 0;
    final breakdown = app.profileGameBreakdown(profileId!);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Profil', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 116),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final p in players)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Pressable(
                            onTap: () => app.openProfile(p.uid),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                              decoration: BoxDecoration(
                                color: p.uid == profileId ? AppColors.ink : AppColors.card,
                                border: Border.all(color: p.uid == profileId ? AppColors.ink : AppColors.line),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Avatar(initial: p.initial, color: Color(p.color), size: 26, fontSize: 11),
                                const SizedBox(width: 7),
                                Text(p.displayName, style: bodyFont(size: 13, weight: FontWeight.w700, color: p.uid == profileId ? Colors.white : AppColors.ink2)),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Avatar(initial: profile.initial, color: Color(profile.color), size: 72, fontSize: 30),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: dispFont(size: 26, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.4)),
                        Text('${rank}e du classement · $points pts cumulés', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Row(children: [
                  _stat('$wins', 'Victoires', AppColors.green),
                  const SizedBox(width: 10),
                  _stat('$played', 'Parties', AppColors.ink),
                  const SizedBox(width: 10),
                  _stat('${(ratio * 100).round()}%', 'Winrate', AppColors.accent),
                ]),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Par jeu'),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: breakdown.isEmpty
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: EmptyState(emoji: '🎮', message: "Pas encore de partie jouée."))
                      : Column(
                          children: [
                            for (final b in breakdown)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(11)),
                                      child: Text(b.game.emoji, style: const TextStyle(fontSize: 19)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(b.game.name, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                                          Text('${b.played} parties · ${b.wins} V', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(b.avg.toStringAsFixed(1), style: dispFont(size: 16, weight: FontWeight.w700, color: AppColors.ink)),
                                        Text('moy. pts', style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: Pressable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.people_alt_rounded, size: 19, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Mes amis', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                        if (app.friends.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('${app.friends.length}', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut)),
                          ),
                        Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Pressable(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.palette_rounded, size: 19, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Personnalisation', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                        Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const _SwitchAccountDialog()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  minimumSize: const Size.fromHeight(0),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: Text('Changer de compte', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.accent)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _confirmSignOut(context, app),
                style: TextButton.styleFrom(foregroundColor: AppColors.mut),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('Se déconnecter', style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.mut)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const _DeleteAccountDialog())),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  minimumSize: const Size.fromHeight(0),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: Text('Supprimer mon compte', style: bodyFont(size: 14, weight: FontWeight.w700, color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Se déconnecter ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text('Vous pourrez sélectionner un autre compte sur l’écran de connexion.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Se déconnecter', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (confirmed == true) await app.signOut();
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          children: [
            Text(value, style: dispFont(size: 26, weight: FontWeight.w700, color: color)),
            const SizedBox(height: 1),
            Text(label, style: bodyFont(size: 11, weight: FontWeight.w700, color: AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_passwordCtrl.text.isEmpty) return;
    final ok = await app.deleteAccount(_passwordCtrl.text);
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
            Text('Supprimer votre compte ?', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              "Cette action est définitive : votre profil sera supprimé, vous quitterez tous vos groupes, et les groupes dont vous êtes propriétaire seront supprimés avec tout leur historique.",
              style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.mut),
            ),
            const SizedBox(height: 18),
            Text('Confirmez avec votre mot de passe', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
            const SizedBox(height: 9),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
              decoration: appFieldDecoration(
                focusColor: Colors.red,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.mut),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (app.flowError != null) ...[
              const SizedBox(height: 8),
              Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.red)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: app.busy ? null : () => _submit(app),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  elevation: 0,
                ),
                child: app.busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Supprimer définitivement', style: bodyFont(size: 16, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lists every account actually signed in this app run (see
/// [SessionManager.openAccounts]) — tapping a different one switches to it
/// instantly, no password, since it's already got a live session running in
/// the background. "Ajouter un compte" is the only way to get a *second*
/// account into that list in the first place: it opens a brand new session
/// alongside the current one via [SessionManager.openSession], rather than
/// replacing it the way signing in from the login screen would.
class _SwitchAccountDialog extends StatefulWidget {
  const _SwitchAccountDialog();

  @override
  State<_SwitchAccountDialog> createState() => _SwitchAccountDialogState();
}

class _SwitchAccountDialogState extends State<_SwitchAccountDialog> {
  bool _addingAccount = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _addAccount(SessionManager sessionManager) async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) return;
    final ok = await sessionManager.openSession(email: _emailCtrl.text, password: _passCtrl.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = context.watch<SessionManager>();
    final app = context.watch<AppState>();
    final accounts = sessionManager.openAccounts;
    final activeUid = app.currentUser?.uid;

    return Dialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Changer de compte', style: dispFont(size: 20, weight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),
            for (final account in accounts) _accountTile(context, sessionManager, account, isActive: account.uid == activeUid),
            const SizedBox(height: 4),
            if (!_addingAccount)
              TextButton.icon(
                onPressed: () => setState(() => _addingAccount = true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter un compte'),
              )
            else
              _addAccountForm(sessionManager),
          ],
        ),
      ),
    );
  }

  Widget _accountTile(BuildContext context, SessionManager sessionManager, AppUser account, {required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: isActive
            ? null
            : () {
                sessionManager.switchTo(account.uid);
                Navigator.of(context).pop();
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentSoft : AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Avatar(initial: account.initial, color: Color(account.color), size: 32, fontSize: 13),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(account.displayName, style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(account.email, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                  ],
                ),
              ),
              if (isActive) Text('Actif', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addAccountForm(SessionManager sessionManager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('E-mail', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(),
        ),
        const SizedBox(height: 12),
        Text('Mot de passe', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
        const SizedBox(height: 9),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(),
        ),
        if (sessionManager.lastError != null) ...[
          const SizedBox(height: 8),
          Text(sessionManager.lastError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.red)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Se connecter', loading: sessionManager.busy, onPressed: () => _addAccount(sessionManager)),
      ],
    );
  }
}
