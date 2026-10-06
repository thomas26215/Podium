import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/text_search.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/option_chip.dart';
import '../../widgets/segmented_control.dart';
import '../new_game/library_game_preview_screen.dart';

/// A player's game collection (see AppUser.ownedGameIds). On your own, a
/// second tab browses the shared library to add games to it; on someone
/// else's, the games you own too are marked.
class CollectionScreen extends StatefulWidget {
  final String uid;
  const CollectionScreen({super.key, required this.uid});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  static const _pageSize = 40;
  int _tab = 0;
  String _search = '';
  String? _category;
  int _shown = _pageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().ensureGameLibraryLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.playerById(widget.uid);
    final isMe = widget.uid == app.currentUser?.uid;
    final ownedIds = user?.ownedGameIds ?? const <String>[];
    final mine = app.currentUser?.ownedGameIds.toSet() ?? const <String>{};
    // Variants flagged non-collectible (see Game.collectible) never show,
    // even if added before the flag existed.
    final owned = ownedIds.map(app.libraryGameById).whereType<Game>().where((g) => g.collectible).toList()..sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(isMe ? 'Ma collection' : 'Collection de ${user?.displayName ?? 'ce joueur'}', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: Column(
        children: [
          if (isMe)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SegmentedControl(
                labels: ['Mes jeux · ${app.gameLibrary.isEmpty ? ownedIds.length : owned.length}', 'Ajouter des jeux'],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
                fontSize: 13,
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: appStepTransition,
              child: app.libraryLoading && app.gameLibrary.isEmpty
                  ? const Center(key: ValueKey('loading'), child: PodiumLoader())
                  : (_tab == 0 || !isMe)
                      ? KeyedSubtree(key: const ValueKey('owned'), child: _ownedGrid(context, app, owned, isMe, mine))
                      : KeyedSubtree(key: const ValueKey('browse'), child: _browse(context, app, mine)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownedGrid(BuildContext context, AppState app, List<Game> owned, bool isMe, Set<String> mine) {
    if (owned.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          EmptyState(emoji: '📦', message: isMe ? 'Votre collection est vide.\nAjoutez les jeux que vous possédez !' : 'Aucun jeu dans sa collection pour l\'instant.'),
          if (isMe)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _tab = 1),
                icon: const Icon(Icons.add_rounded),
                label: Text('Ajouter des jeux', style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.accent)),
              ),
            ),
        ],
      );
    }
    final favorite = app.playerById(widget.uid)?.favoriteGameId;
    final shared = isMe ? 0 : owned.where((g) => mine.contains(g.id)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (!isMe && shared > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('$shared jeu${shared > 1 ? 'x' : ''} en commun avec vous', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
          ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.86,
          children: [
            for (final (i, g) in owned.indexed)
              FadeSlideIn(
                key: ValueKey(g.id),
                delay: staggerDelay(i, stepMs: 25),
                child: _GameCard(
                  game: g,
                  favorite: g.id == favorite,
                  sharedWithMe: !isMe && mine.contains(g.id),
                  onTap: () => isMe ? _ownedActions(context, app, g, g.id == favorite) : _preview(context, g),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _browse(BuildContext context, AppState app, Set<String> mine) {
    final q = foldText(_search.trim());
    final collectible = app.gameLibrary.where((g) => g.collectible).toList();
    final inCategory = _category == null ? collectible : collectible.where((g) => g.category == _category).toList();
    final results = q.isEmpty ? inCategory : inCategory.where((g) => foldText(g.name).contains(q)).toList();
    final visible = results.take(_shown).toList();
    final categories = <String>{for (final g in collectible) g.category};
    final played = app.playedLibraryGames(widget.uid);
    final playedCount = {for (final p in played) p.game.id: p.played};
    final ordered = [...Game.categories.where(categories.contains), ...categories.where((c) => !Game.categories.contains(c))];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        TextField(
          onChanged: (v) => setState(() {
            _search = v;
            _shown = _pageSize;
          }),
          style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
          decoration: appFieldDecoration(
            hintText: 'Rechercher un jeu…',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              OptionChip(label: 'Tous', selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final c in ordered) ...[
                const SizedBox(width: 8),
                OptionChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (q.isEmpty && _category == null && played.isNotEmpty) ...[
          FadeSlideIn(child: _PlayedSection(played: played, mine: mine, app: app, tile: (g, n) => _browseTile(app, g, mine.contains(g.id), played: n))),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text('TOUTE LA BIBLIOTHÈQUE', style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.8)),
          ),
        ],
        if (results.isEmpty)
          const EmptyState(emoji: '🔎', message: 'Aucun jeu ne correspond à cette recherche.')
        else ...[
          for (final (i, g) in visible.indexed)
            i < 20
                ? FadeSlideIn(key: ValueKey('b-${g.id}'), delay: staggerDelay(i, stepMs: 25), child: _browseTile(app, g, mine.contains(g.id), played: playedCount[g.id]))
                : _browseTile(app, g, mine.contains(g.id), played: playedCount[g.id]),
          if (results.length > visible.length)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _shown += _pageSize),
                child: Text('Afficher plus (${results.length - visible.length} restants)', style: bodyFont(size: 14, weight: FontWeight.w800, color: AppColors.accent)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _browseTile(AppState app, Game g, bool owned, {int? played}) {
    return GameTileRow(
      emoji: g.emoji,
      onTap: () => app.toggleOwnedGame(g.id),
      title: Row(
        children: [
          Flexible(child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink))),
          if (played != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(20)),
              child: Text('JOUÉ ×$played', style: bodyFont(size: 9.5, weight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.3)),
            ),
          ],
        ],
      ),
      subtitle: Text([g.category, ?g.summaryLine()].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, a) => RotationTransition(
          turns: Tween<double>(begin: -0.15, end: 0).animate(a),
          child: ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
        ),
        child: owned
            ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: AppColors.green, size: 28)
            : Icon(Icons.add_circle_outline_rounded, key: const ValueKey('off'), color: AppColors.accent, size: 28),
      ),
    );
  }

  void _preview(BuildContext context, Game g) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryGamePreviewScreen(game: g)));

  Future<void> _ownedActions(BuildContext context, AppState app, Game g, bool isFavorite) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: appSheetAnimation,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(g.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(child: Text(g.name, style: dispFont(size: 19, weight: FontWeight.w700, color: AppColors.ink))),
              ]),
              const SizedBox(height: 14),
              _SheetAction(icon: isFavorite ? Icons.favorite_border_rounded : Icons.favorite_rounded, label: isFavorite ? 'Ne plus en faire mon jeu préféré' : 'En faire mon jeu préféré', onTap: () => Navigator.of(sheetContext).pop('fav')),
              _SheetAction(icon: Icons.menu_book_rounded, label: 'Voir la fiche du jeu', onTap: () => Navigator.of(sheetContext).pop('view')),
              _SheetAction(icon: Icons.remove_circle_outline_rounded, label: 'Retirer de ma collection', danger: true, onTap: () => Navigator.of(sheetContext).pop('remove')),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'fav':
        await app.updateProfile(favoriteGameId: () => isFavorite ? null : g.id);
      case 'view':
        _preview(context, g);
      case 'remove':
        await app.toggleOwnedGame(g.id);
    }
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : AppColors.ink;
    return Pressable(
      behavior: HitTestBehavior.opaque,
      dimOnPress: true,
      pressedScale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Icon(icon, size: 21, color: danger ? Colors.red : AppColors.ink2),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: bodyFont(size: 15, weight: FontWeight.w700, color: color))),
        ]),
      ),
    );
  }
}

/// One owned game: big emoji tile + name, a heart on the favourite and a
/// tick on games the viewer owns too.
class _GameCard extends StatelessWidget {
  final Game game;
  final bool favorite;
  final bool sharedWithMe;
  final VoidCallback onTap;
  const _GameCard({required this.game, required this.favorite, required this.sharedWithMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: cardDecoration(
          radius: AppRadius.lg,
          border: favorite ? AppColors.accent : null,
          borderWidth: 1.5,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: wellDecoration(radius: AppRadius.scaled(12)),
                    child: Text(game.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(game.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w800, color: AppColors.ink, height: 1.15)),
              ],
            ),
            if (favorite || sharedWithMe)
              Positioned(
                top: -4,
                right: -2,
                child: Icon(favorite ? Icons.favorite_rounded : Icons.check_circle_rounded, size: 18, color: favorite ? AppColors.accent : AppColors.green),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Vous y avez déjà joué" — the library games behind the player's matches
/// in this group, offered first (with a one-tap "add them all"), since
/// those are the likeliest to be on their shelf.
class _PlayedSection extends StatelessWidget {
  final List<({Game game, int played})> played;
  final Set<String> mine;
  final AppState app;
  final Widget Function(Game game, int played) tile;
  const _PlayedSection({required this.played, required this.mine, required this.app, required this.tile});

  @override
  Widget build(BuildContext context) {
    final missing = played.where((p) => !mine.contains(p.game.id)).map((p) => p.game.id).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vous y avez déjà joué', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                      Text('Dans ce groupe · ${played.length} jeu${played.length > 1 ? 'x' : ''}', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: child)),
                  child: missing.isEmpty
                      ? Row(key: const ValueKey('done'), mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: AppColors.green),
                          const SizedBox(width: 4),
                          Text('Tous ajoutés', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.green)),
                        ])
                      : Pressable(
                          key: const ValueKey('add'),
                          onTap: () => app.addOwnedGames(missing),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: accentDecoration(radius: AppRadius.scaled(12), glow: false),
                            child: Text('Tout ajouter (${missing.length})', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, p) in played.indexed) FadeSlideIn(delay: staggerDelay(i, baseMs: 80, stepMs: 40), child: tile(p.game, p.played)),
        ],
      ),
    );
  }
}
