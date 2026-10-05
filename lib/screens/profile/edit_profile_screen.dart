import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/badges.dart';
import '../../models/app_user.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/badge_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/option_chip.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/profile_style.dart';
import 'profile_header.dart';

const _avatarEmojis = [
  '😎', '🤠', '🥸', '🤓', '😈', '👻', '💀', '🤖', //
  '👾', '🎃', '👑', '🧙', '🥷', '🦸', '🧛', '🧜', //
  '🦊', '🐼', '🐯', '🦁', '🐸', '🐙', '🦄', '🐲', //
  '🦖', '🐧', '🦉', '🐺', '🦝', '🐨', '🐵', '🐝', //
  '🧠', '🍕', '🌮', '🍩', '🍀', '🌟', '🌈', '🚀', //
  '⚽', '🏀', '🎳', '🏓', '🎱', '🎯', '🛹', '🥊', //
  '🎲', '♟️', '🃏', '🀄', '🧩', '🎮', '🕹️', '🏆', //
  '🔥', '⚡', '💎', '🎸', '🎨', '🍷', '☕', '🪐', //
];

const _statusEmojis = ['🎲', '🎮', '🃏', '♟️', '🏆', '🔥', '🍕', '🍻', '😴', '📚', '🤔', '🎉'];

const _tabs = <({String label, IconData icon})>[
  (label: 'Profil', icon: Icons.badge_outlined),
  (label: 'Avatar', icon: Icons.face_rounded),
  (label: 'Carte', icon: Icons.style_rounded),
  (label: 'Vitrine', icon: Icons.emoji_events_outlined),
  (label: 'Comptes', icon: Icons.sports_esports_outlined),
];

/// Edits the signed-in player's profile, Discord-style: identity (name,
/// pronouns, title, status, bio), avatar (emoji, colour, decoration), card
/// (banner, name font & effect, profile effect), showcase (pinned badges,
/// favourite game) and game accounts — with the card previewed live on top.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final AppUser _initial;
  late AppUser _draft;
  late final TextEditingController _name, _bio, _pronouns, _status;
  late final Map<String, TextEditingController> _accounts;
  late String _bannerCategory;
  int _tab = 0;
  int _effectReplay = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _initial = app.currentUser!;
    _draft = _initial;
    TextEditingController field(String text) => TextEditingController(text: text)..addListener(() => setState(() {}));
    _name = field(_initial.displayName);
    _bio = field(_initial.bio);
    _pronouns = field(_initial.pronouns);
    _status = field(_initial.status);
    _accounts = {for (final p in kGamePlatforms) p.id: field(_initial.gameAccounts[p.id] ?? '')};
    // A plain colour opens on the game themes instead — the "Couleurs"
    // chip sits last, off screen, and the themes are the point.
    final category = bannerThemeById(_initial.banner).category;
    _bannerCategory = category == 'Couleurs' ? kBannerCategories.first : category;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) app.ensureGameLibraryLoaded();
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _pronouns, _status, ..._accounts.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(AppUser Function(AppUser d) change) => setState(() => _draft = change(_draft));

  /// The draft with the text fields folded in — what gets saved.
  AppUser get _built => _draft.copyWith(
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        pronouns: _pronouns.text.trim(),
        status: _status.text.trim(),
        gameAccounts: {
          for (final e in _accounts.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        },
      );

  /// What the preview card shows (never an empty name).
  AppUser get _preview {
    final b = _built;
    return b.displayName.isEmpty ? b.copyWith(displayName: _initial.displayName) : b;
  }

  static String _signature(AppUser u) {
    final m = u.toProfileMap();
    final accounts = (m['gameAccounts'] as Map<String, String>).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    m['gameAccounts'] = {for (final e in accounts) e.key: e.value};
    return jsonEncode(m);
  }

  bool get _dirty => _signature(_built) != _signature(_initial);

  Future<void> _save(AppState app) async {
    setState(() => _saving = true);
    final ok = await app.saveProfile(_built);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      app.showToast('Profil mis à jour.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.currentUser ?? _initial;
    final favoriteGame = _draft.favoriteGameId == null ? null : app.libraryGameById(_draft.favoriteGameId!);
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final previewHeight = math.min(240.0, MediaQuery.sizeOf(context).height * 0.32);

    final tabContent = switch (_tab) {
      0 => _identityTab(app, me),
      1 => _avatarTab(me),
      2 => _cardTab(),
      3 => _showcaseTab(app, me),
      _ => _accountsTab(),
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Modifier le profil', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // The live preview stays pinned above the options — scaled down
            // to fit — so every banner, effect or font you try plays right
            // there; it steps aside while the keyboard is up.
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: keyboardUp
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: previewHeight),
                        child: LayoutBuilder(
                          builder: (context, box) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: box.maxWidth,
                              child: FadeSlideIn(child: ProfileHeaderCard(user: _preview, favoriteGame: favoriteGame, subtitle: 'Aperçu', effectReplayToken: _effectReplay)),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final (i, t) in _tabs.indexed) ...[
                    OptionChip(label: t.label, icon: t.icon, selected: i == _tab, onTap: () => setState(() => _tab = i)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child),
                    ),
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    child: KeyedSubtree(key: ValueKey(_tab), child: tabContent),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (app.flowError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: Colors.red)),
                    ),
                  PrimaryButton(label: 'Enregistrer', loading: _saving, onPressed: _dirty && _name.text.trim().isNotEmpty ? () => _save(app) : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================== tabs ==============================

  Widget _identityTab(AppState app, AppUser me) {
    final earned = app.earnedBadgeIds(me.uid);
    return _section([
      _label('Pseudo'),
      TextField(
        controller: _name,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
        decoration: appFieldDecoration(hintText: 'Votre pseudo').copyWith(counterText: ''),
      ),
      const SizedBox(height: 18),
      _label('Pronoms'),
      TextField(
        controller: _pronouns,
        maxLength: 20,
        style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
        decoration: appFieldDecoration(hintText: 'elle, il/lui, iel…').copyWith(counterText: ''),
      ),
      const SizedBox(height: 18),
      _label('Statut'),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final e in [null, ..._statusEmojis])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _pickCircle(
                  selected: _draft.statusEmoji == e,
                  size: 40,
                  onTap: () => _edit((d) => d.copyWith(statusEmoji: () => e)),
                  child: e == null ? Icon(Icons.block_rounded, size: 18, color: AppColors.mut) : Text(e, style: const TextStyle(fontSize: 19)),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _status,
        maxLength: 60,
        style: bodyFont(size: 15, weight: FontWeight.w600, color: AppColors.ink),
        decoration: appFieldDecoration(hintText: 'Partant pour un Catan ce soir…').copyWith(counterText: ''),
      ),
      const SizedBox(height: 18),
      _label('Bio'),
      TextField(
        controller: _bio,
        maxLength: 120,
        maxLines: 3,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        style: bodyFont(size: 15, weight: FontWeight.w600, color: AppColors.ink),
        decoration: appFieldDecoration(hintText: 'Joueur de Catan invaincu depuis 2019…'),
      ),
      const SizedBox(height: 14),
      _label('Titre'),
      Text('Affiché sous votre pseudo. Les badges en débloquent de nouveaux.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _textChip(label: 'Aucun', selected: _draft.titleId == null, onTap: () => _edit((d) => d.copyWith(titleId: () => null))),
          for (final t in kTitles)
            Builder(builder: (_) {
              final unlocked = t.isUnlocked(earned);
              final badge = t.badgeId == null ? null : badgeById(t.badgeId!);
              return _textChip(
                label: unlocked ? t.label : '🔒 ${t.label}',
                selected: _draft.titleId == t.id,
                locked: !unlocked,
                onTap: unlocked
                    ? () => _edit((d) => d.copyWith(titleId: () => t.id))
                    : () => app.showToast('Débloqué avec le badge « ${badge?.name ?? '?'} »', error: true),
              );
            }),
        ],
      ),
    ]);
  }

  Widget _avatarTab(AppUser me) {
    return _section([
      _label('Avatar'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pickCircle(
            selected: _draft.avatarEmoji == null,
            onTap: () => _edit((d) => d.copyWith(avatarEmoji: () => null)),
            child: Avatar(initial: me.letter, color: Color(_draft.color), size: 34, fontSize: 15),
          ),
          for (final e in _avatarEmojis)
            _pickCircle(selected: _draft.avatarEmoji == e, onTap: () => _edit((d) => d.copyWith(avatarEmoji: () => e)), child: Text(e, style: const TextStyle(fontSize: 21))),
        ],
      ),
      const SizedBox(height: 22),
      _label('Couleur'),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in kAvatarPalette)
            _pickCircle(
              selected: _draft.color == c,
              fill: Color(c),
              onTap: () => _edit((d) => d.copyWith(color: c)),
              child: AnimatedOpacity(opacity: _draft.color == c ? 1 : 0, duration: const Duration(milliseconds: 180), child: const Icon(Icons.check_rounded, color: Colors.white, size: 20)),
            ),
        ],
      ),
      const SizedBox(height: 22),
      _label('Décoration'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
        children: [
          for (final f in [(id: null, label: 'Aucune'), ...kAvatarFrames])
            _tile(
              selected: _draft.avatarFrame == f.id,
              onTap: () => _edit((d) => d.copyWith(avatarFrame: () => f.id)),
              label: f.label,
              child: FramedAvatar(
                frameId: f.id,
                size: 38,
                child: Avatar(initial: _draft.avatarEmoji ?? me.letter, color: Color(_draft.color), size: 38, fontSize: 15),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _cardTab() {
    final themes = kBannerThemes.where((b) => b.category == _bannerCategory).toList();
    return _section([
      _label('Bannière'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in kBannerCategories) ...[
              OptionChip(label: c, selected: c == _bannerCategory, onTap: () => setState(() => _bannerCategory = c)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        key: ValueKey(_bannerCategory),
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          for (final (i, b) in themes.indexed)
            FadeSlideIn(
              delay: staggerDelay(i, stepMs: 40),
              child: Pressable(
                onTap: () => _edit((d) => d.copyWith(banner: b.id)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md + 3),
                    border: Border.all(color: _draft.banner == b.id ? AppColors.accent : Colors.transparent, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      children: [
                        // The chosen one plays live; the others hold a still frame.
                        Positioned.fill(child: ProfileBannerBackground(themeId: b.id, phase: _draft.banner == b.id ? null : 0.35)),
                        Positioned(
                          left: 10,
                          bottom: 8,
                          right: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(b.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white).copyWith(shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6)])),
                              ),
                              AnimatedScale(
                                scale: _draft.banner == b.id ? 1 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      _label('Police du pseudo'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in kNameFonts)
            _darkTile(
              selected: _draft.nameFont == f.id,
              onTap: () => _edit((d) => d.copyWith(nameFont: () => f.id)),
              caption: f.label,
              child: StyledName(text: _preview.displayName, fontId: f.id, size: 17, accent: Color(_draft.color)),
            ),
        ],
      ),
      const SizedBox(height: 22),
      _label('Effet du pseudo'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in kNameEffects)
            _darkTile(
              selected: _draft.nameEffect == e.id,
              onTap: () => _edit((d) => d.copyWith(nameEffect: () => e.id)),
              caption: e.label,
              child: StyledName(text: _preview.displayName, fontId: _draft.nameFont, effectId: e.id, size: 17, accent: Color(_draft.color)),
            ),
        ],
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(child: _label('Effet de profil')),
          if (_draft.profileEffect != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Pressable(
                onTap: () => setState(() => _effectReplay++),
                child: Row(children: [
                  Icon(Icons.replay_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text('Rejouer', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.accent)),
                ]),
              ),
            ),
        ],
      ),
      Text('Joué une fois à l\'ouverture de votre profil.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.5,
        children: [
          for (final e in [(id: null, label: 'Aucun', emoji: '🚫'), ...kProfileEffects])
            _tile(
              selected: _draft.profileEffect == e.id,
              onTap: () {
                _edit((d) => d.copyWith(profileEffect: () => e.id));
                setState(() => _effectReplay++);
              },
              label: e.label,
              child: Text(e.emoji, style: const TextStyle(fontSize: 24)),
            ),
        ],
      ),
    ]);
  }

  Widget _showcaseTab(AppState app, AppUser me) {
    final earned = kBadges.where((b) => me.badges.contains(b.id)).toList();
    final owned = me.ownedGameIds.map(app.libraryGameById).whereType<Game>().where((g) => g.collectible).toList();
    final showcased = _draft.showcasedBadges;
    return _section([
      _label('Badges mis en avant · ${showcased.length}/$kMaxShowcasedBadges'),
      if (earned.isEmpty)
        Text('Jouez des parties pour débloquer vos premiers badges !', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut))
      else
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
          children: [
            for (final b in earned)
              Builder(builder: (_) {
                final on = showcased.contains(b.id);
                final full = !on && showcased.length >= kMaxShowcasedBadges;
                return Opacity(
                  opacity: full ? 0.4 : 1,
                  child: Pressable(
                    onTap: full ? null : () => _edit((d) => d.copyWith(showcasedBadges: on ? showcased.where((x) => x != b.id).toList() : [...showcased, b.id])),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            BadgeMedal(badge: b, earned: true, size: 56),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: AnimatedScale(
                                scale: on ? 1 : 0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutBack,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2)),
                                  child: Text('${showcased.indexOf(b.id) + 1}', style: bodyFont(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(b.name, maxLines: 2, textAlign: TextAlign.center, style: bodyFont(size: 11, weight: FontWeight.w800, color: on ? AppColors.accent : AppColors.ink2, height: 1.15)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      const SizedBox(height: 22),
      _label('Jeu préféré'),
      if (app.libraryLoading && owned.isEmpty)
        const Align(alignment: Alignment.centerLeft, child: PodiumLoader(size: 22))
      else if (owned.isEmpty)
        Text('Ajoutez des jeux à votre collection pour choisir votre préféré.', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in owned)
              _textChip(
                label: '${g.emoji}  ${g.name}',
                selected: _draft.favoriteGameId == g.id,
                onTap: () => _edit((d) => d.copyWith(favoriteGameId: () => d.favoriteGameId == g.id ? null : g.id)),
              ),
          ],
        ),
    ]);
  }

  Widget _accountsTab() {
    return _section([
      Text('Vos pseudos sur les plateformes de jeu — les autres joueurs pourront les copier depuis votre profil.', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
      const SizedBox(height: 14),
      for (final p in kGamePlatforms)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              PlatformLogo(platform: p, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _accounts[p.id],
                  maxLength: 40,
                  style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                  decoration: appFieldDecoration(hintText: p.hint, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)).copyWith(
                    counterText: '',
                    labelText: p.label,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelStyle: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.mut),
                  ),
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  // ============================== bits ==============================

  Widget _section(List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Text(text, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
      );

  Widget _pickCircle({required bool selected, required Widget child, required VoidCallback onTap, Color? fill, double size = 46}) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.88,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill ?? (selected ? AppColors.accentSoft : AppColors.card),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2.5 : 1.5),
        ),
        child: AnimatedScale(scale: selected ? 1.12 : 1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutBack, child: child),
      ),
    );
  }

  Widget _textChip({required String label, required bool selected, required VoidCallback onTap, bool locked = false}) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : (locked ? AppColors.bg : AppColors.card),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: bodyFont(size: 13, weight: FontWeight.w700, color: selected ? AppColors.accent : (locked ? AppColors.mut : AppColors.ink2))),
      ),
    );
  }

  /// A selectable square tile with a visual on top and a caption.
  Widget _tile({required bool selected, required VoidCallback onTap, required String label, required Widget child}) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: selected ? AppColors.accent : AppColors.ink2)),
          ],
        ),
      ),
    );
  }

  /// A dark swatch previewing a name style, as it'll look on a banner.
  Widget _darkTile({required bool selected, required VoidCallback onTap, required String caption, required Widget child}) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 148,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bannerThemeById(_draft.banner).colors),
          border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 30, child: Align(alignment: Alignment.centerLeft, child: child)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(caption, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.8)))),
                if (selected) const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
