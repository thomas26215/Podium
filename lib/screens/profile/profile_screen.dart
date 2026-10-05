import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/badges.dart';
import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../state/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/badge_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/profile_style.dart';
import '../settings/settings_screen.dart';
import 'badges_screen.dart';
import 'collection_screen.dart';
import 'edit_profile_screen.dart';
import 'friends_screen.dart';
import 'profile_header.dart';
import 'profile_stats.dart';
import 'profile_elo_section.dart';

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

    if (profileId == null || profile == null) {
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

    final winRows = app.headlineStandings;
    final rank = winRows.indexWhere((r) => r.player.uid == profileId) + 1;
    final rows = app.computeRows(null);
    final mine = rows.where((r) => r.player.uid == profileId).toList();
    final played = mine.isNotEmpty ? mine.first.played : 0;
    final wins = mine.isNotEmpty ? mine.first.wins : 0;
    final ratio = mine.isNotEmpty ? mine.first.ratio : 0.0;
    final points = mine.isNotEmpty ? mine.first.points : 0;
    final eloRow = mine.firstOrNull;
    final isMe = profileId == app.currentUser?.uid;
    // Discord-style profile theme: the screen picks up a wash of the
    // player's banner colour at the top.
    final tint = Color.alphaBlend(bannerThemeById(profile.banner).colors.first.withValues(alpha: AppColors.isDark ? 0.45 : 0.16), AppColors.bg);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: tint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Profil', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tint, AppColors.bg])),
            ),
          ),
          SafeArea(
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
                                    Text(p.displayName, style: bodyFont(size: 13, weight: FontWeight.w700, color: p.uid == profileId ? AppColors.onInk : AppColors.ink2)),
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
                    child: ProfileHeaderCard(
                      user: profile,
                      subtitle: '${rank > 0 ? '${rank}e du classement' : 'Pas encore classé'} · $points pts cumulés',
                      favoriteGame: profile.favoriteGameId == null ? null : app.libraryGameById(profile.favoriteGameId!),
                      onEdit: isMe ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())) : null,
                      onTapBadge: (b) => _openBadge(context, app, profile, b),
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
                      if (app.eloAvailable) ...[
                        const SizedBox(width: 10),
                        _stat(eloRow?.elo != null ? '${eloRow!.elo!.round()}' : '—', 'Elo', AppColors.gold),
                      ],
                    ]),
                  ),
                  if (!profile.isGuest) ...[
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Badges · ${app.earnedBadgeIds(profileId).where((id) => badgeById(id) != null).length}/${kBadges.length}',
                      actionLabel: 'Tout voir',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BadgesScreen(uid: profileId))),
                    ),
                    FadeSlideIn(delay: const Duration(milliseconds: 110), child: _BadgeShelf(user: profile, isMe: isMe)),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Collection · ${profile.ownedGameIds.length} jeu${profile.ownedGameIds.length > 1 ? 'x' : ''}',
                      actionLabel: isMe ? 'Gérer' : (profile.ownedGameIds.isEmpty ? null : 'Tout voir'),
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionScreen(uid: profileId))),
                    ),
                    FadeSlideIn(delay: const Duration(milliseconds: 120), child: _CollectionShelf(user: profile, isMe: isMe)),
                    if (profile.gameAccounts.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Comptes de jeu'),
                      FadeSlideIn(delay: const Duration(milliseconds: 130), child: _GameAccounts(user: profile)),
                    ],
                  ],
                  if (app.eloAvailable && eloRow?.elo != null) ...[
                    const SizedBox(height: 22),
                    const SectionHeader(title: 'Elo'),
                    FadeSlideIn(delay: const Duration(milliseconds: 120), child: ProfileEloSection(uid: profileId)),
                  ],
                  const SizedBox(height: 22),
                  const SectionHeader(title: 'Statistiques'),
                  FadeSlideIn(delay: const Duration(milliseconds: 140), child: ProfileStatsCard(uid: profileId)),
                  if (isMe) ...[
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
                              Expanded(child: Text('Apparence & réglages', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => showAppDialog(context: context, builder: (_) => const _SwitchAccountDialog()),
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
                      onPressed: () => showAppDialog(context: context, builder: (_) => ChangeNotifierProvider.value(value: app, child: const _DeleteAccountDialog())),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppState app) async {
    final confirmed = await showAppDialog<bool>(
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

  void _openBadge(BuildContext context, AppState app, AppUser user, BadgeDef b) {
    final isMe = user.uid == app.currentUser?.uid;
    showBadgeDetail(
      context,
      badge: b,
      earned: app.earnedBadgeIds(user.uid).contains(b.id),
      stats: app.badgeStatsFor(user.uid),
      showcased: user.showcasedBadges.contains(b.id),
      onToggleShowcase: isMe ? () => app.toggleShowcasedBadge(b.id) : null,
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: dispFont(size: 26, weight: FontWeight.w700, color: color))),
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

/// The profile's badge row: the player's unlocked medals (most prestigious
/// first) — or, before any, the ones they're closest to.
class _BadgeShelf extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  const _BadgeShelf({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final earnedIds = app.earnedBadgeIds(user.uid);
    final earned = kBadges.where((b) => earnedIds.contains(b.id)).toList()..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    final stats = app.badgeStatsFor(user.uid);
    final upcoming = earned.isEmpty ? (kBadges.toList()..sort((a, b) => b.progress(stats).compareTo(a.progress(stats)))).take(4).toList() : const <BadgeDef>[];
    final shown = earned.isNotEmpty ? earned : upcoming;
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (earned.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(isMe ? 'Vos prochains badges :' : 'Pas encore de badge débloqué.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
            ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final b = shown[i];
                final isEarned = earned.isNotEmpty;
                return FadeSlideIn(
                  delay: staggerDelay(i, baseMs: 150, stepMs: 50),
                  child: Pressable(
                    onTap: () => showBadgeDetail(
                      context,
                      badge: b,
                      earned: isEarned,
                      stats: stats,
                      showcased: user.showcasedBadges.contains(b.id),
                      onToggleShowcase: isMe ? () => app.toggleShowcasedBadge(b.id) : null,
                    ),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          BadgeMedal(badge: b, earned: isEarned, size: 54, progress: isEarned ? null : b.progress(stats)),
                          const SizedBox(height: 6),
                          Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: bodyFont(size: 10.5, weight: FontWeight.w800, color: isEarned ? AppColors.ink2 : AppColors.mut)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal peek at the player's game collection; the full list (and,
/// on your own profile, adding games) is in CollectionScreen.
class _CollectionShelf extends StatefulWidget {
  final AppUser user;
  final bool isMe;
  const _CollectionShelf({required this.user, required this.isMe});

  @override
  State<_CollectionShelf> createState() => _CollectionShelfState();
}

class _CollectionShelfState extends State<_CollectionShelf> {
  @override
  void initState() {
    super.initState();
    // Owned games are stored as library ids — the library itself is only
    // fetched on demand.
    if (widget.user.ownedGameIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppState>().ensureGameLibraryLoaded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = widget.user;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionScreen(uid: user.uid)));
    if (user.ownedGameIds.isEmpty) {
      return Pressable(
        onTap: widget.isMe ? open : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
          child: Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isMe ? 'Ajoutez les jeux que vous possédez pour savoir chez qui jouer à quoi.' : 'Aucun jeu dans sa collection pour l\'instant.',
                  style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
                ),
              ),
              if (widget.isMe) Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 26),
            ],
          ),
        ),
      );
    }
    if (app.libraryLoading && app.gameLibrary.isEmpty) {
      return const SizedBox(height: 96, child: Center(child: PodiumLoader(size: 26)));
    }
    final games = user.ownedGameIds.map(app.libraryGameById).whereType<Game>().where((g) => g.collectible).toList();
    // The favourite first, then most recently added.
    games.sort((a, b) {
      if (a.id == user.favoriteGameId) return -1;
      if (b.id == user.favoriteGameId) return 1;
      return user.ownedGameIds.indexOf(b.id).compareTo(user.ownedGameIds.indexOf(a.id));
    });
    final mine = app.currentUser?.ownedGameIds.toSet() ?? const <String>{};
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: games.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final g = games[i];
          final fav = g.id == user.favoriteGameId;
          return FadeSlideIn(
            delay: staggerDelay(i, baseMs: 160, stepMs: 40),
            child: Pressable(
              onTap: open,
              child: Container(
                width: 88,
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: fav ? AppColors.accent : AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Text(g.emoji, style: const TextStyle(fontSize: 30)),
                        const Spacer(),
                        Text(g.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.ink, height: 1.15)),
                      ],
                    ),
                    if (fav) Positioned(top: -4, right: -2, child: Icon(Icons.favorite_rounded, size: 16, color: AppColors.accent))
                    else if (!widget.isMe && mine.contains(g.id)) Positioned(top: -4, right: -2, child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.green)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The player's game platform handles (see AppUser.gameAccounts) — tap one
/// to copy it, e.g. to add them as a friend on Steam.
class _GameAccounts extends StatelessWidget {
  final AppUser user;
  const _GameAccounts({required this.user});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final entries = [
      for (final p in kGamePlatforms)
        if (user.gameAccounts[p.id] case final handle?) (platform: p, handle: handle),
    ];
    return Column(
      children: [
        for (final (i, e) in entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FadeSlideIn(
              delay: staggerDelay(i, baseMs: 140, stepMs: 40),
              child: Pressable(
                pressedScale: 0.98,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: e.handle));
                  HapticFeedback.selectionClick();
                  app.showToast('${e.platform.label} : « ${e.handle} » copié');
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Row(
                    children: [
                      PlatformLogo(platform: e.platform, size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.platform.label, style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut)),
                            Text(e.handle, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                          ],
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 18, color: AppColors.mut),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
