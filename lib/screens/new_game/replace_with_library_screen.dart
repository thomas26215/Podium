import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/game_filter.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Picks the library game that should replace [target] in the catalog (see
/// [AppState.replaceGameWithLibrary]) — e.g. swapping a hand-made "Coinche"
/// for the library's, without losing the matches already recorded for it.
/// The search starts from [target]'s own name.
class ReplaceWithLibraryScreen extends StatefulWidget {
  final Game target;
  const ReplaceWithLibraryScreen({super.key, required this.target});

  @override
  State<ReplaceWithLibraryScreen> createState() => _ReplaceWithLibraryScreenState();
}

class _ReplaceWithLibraryScreenState extends State<ReplaceWithLibraryScreen> {
  // A hand-made game most likely has a library match under its own name;
  // one already from the library is being swapped for a different game.
  late final _searchCtrl = TextEditingController(text: widget.target.followsLibrary ? '' : widget.target.name);

  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies listeners, which can't happen
    // while this screen is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().ensureGameLibraryLoaded();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(AppState app, Game libraryGame) async {
    final target = widget.target;
    final played = app.matches.where((m) => m.gameId == target.id).length;
    final duplicate = app.libraryCopyOf(libraryGame);
    final merging = duplicate != null && duplicate.id != target.id;
    final mergedCount = merging ? app.matches.where((m) => m.gameId == duplicate.id).length : 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Remplacer « ${target.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          [
            'Son nom, ses règles de score et son aide-mémoire seront remplacés par ceux de « ${libraryGame.name} » de la bibliothèque, '
                'et il suivra ensuite ses mises à jour.',
            switch (played) {
              0 => "Aucune partie n'a encore été jouée à ce jeu.",
              1 => 'La partie déjà enregistrée est conservée.',
              _ => 'Les $played parties déjà enregistrées sont conservées.',
            },
            if (merging)
              '« ${duplicate.name} » était déjà importé : ${switch (mergedCount) { 0 => "ce doublon sera supprimé", 1 => "sa partie sera regroupée ici, puis ce doublon sera supprimé", _ => "ses $mergedCount parties seront regroupées ici, puis ce doublon sera supprimé" }}.',
          ].join('\n\n'),
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remplacer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await app.replaceGameWithLibrary(target, libraryGame);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.flowError ?? 'Impossible de remplacer ce jeu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final query = _searchCtrl.text;
    // The library game it already follows (if any) isn't a replacement.
    final results = app.contextLibrary.where((g) => g.id != widget.target.libraryId && gameMatchesQuery(g, query)).take(60).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Remplacer par la bibliothèque', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            'Choisissez le jeu de la bibliothèque qui remplacera « ${widget.target.name} ». Les parties déjà jouées sont conservées.',
            style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
            decoration: appFieldDecoration(
              hintText: 'Rechercher un jeu…',
              prefixIcon: Icon(Icons.search, size: 20, color: AppColors.mut),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          if (app.libraryLoading)
            Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (results.isEmpty)
            EmptyState(emoji: '🔎', message: app.gameLibrary.isEmpty ? 'La bibliothèque est indisponible pour le moment.' : 'Aucun jeu ne correspond à cette recherche.')
          else
            for (final g in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GameTileRow(
                  emoji: g.emoji,
                  onTap: () {
                    if (!app.busy) _pick(app, g);
                  },
                  trailing: Icon(Icons.swap_horiz_rounded, color: AppColors.mut, size: 24),
                  title: Text(g.name, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  subtitle: Text(
                    [g.category, ?g.summaryLine(), if (app.libraryCopyOf(g) != null) 'déjà importé'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
