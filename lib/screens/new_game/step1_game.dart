import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_actions_sheet.dart';

class Step1Game extends StatelessWidget {
  const Step1Game({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            for (final g in app.topLevelGames)
              Builder(builder: (_) {
                final variants = app.variantsOf(g.id);
                final baseSub = g.pointLimit != null ? '${g.category} · ${g.pointLimit} pts max' : g.category;
                final selected = app.draft.gameId == g.id || variants.any((v) => v.id == app.draft.gameId);
                return _GameCard(
                  emoji: g.emoji,
                  name: g.name,
                  sub: variants.isEmpty ? baseSub : '$baseSub · ${variants.length} variante${variants.length > 1 ? 's' : ''}',
                  selected: selected,
                  onTap: () => variants.isEmpty ? app.pickGame(g.id) : _showVariantPicker(context, app, g, variants),
                  onLongPress: () => showGameActionsSheet(context, app, g),
                );
              }),
            _GameCard(emoji: '＋', name: 'Nouveau jeu', sub: 'Créer', selected: false, dashed: true, onTap: () => _showNewGameChooser(context, app)),
          ],
        ),
        if (app.topLevelGames.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Appui long sur un jeu pour le modifier ou le supprimer.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
        ],
      ],
    );
  }
}

Future<void> _showNewGameChooser(BuildContext context, AppState app) async {
  final hasOtherGroups = app.groups.any((g) => g.isRoot && g.id != app.currentRootId);
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajouter un jeu', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),
          ChooserOption(
            icon: Icons.cloud_download_rounded,
            title: 'Importer depuis la bibliothèque',
            subtitle: 'Jeux prêts à l\'emploi, y compris ceux avec des règles spéciales (Président…).',
            onTap: () {
              Navigator.of(sheetContext).pop();
              app.startBrowsingLibrary();
            },
          ),
          if (hasOtherGroups) ...[
            const SizedBox(height: 10),
            ChooserOption(
              icon: Icons.groups_rounded,
              title: 'Depuis un autre de vos groupes',
              subtitle: 'Réutilisez un jeu déjà créé dans un autre groupe.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                app.startBrowsingOtherGroups();
              },
            ),
          ],
          const SizedBox(height: 10),
          ChooserOption(
            icon: Icons.edit_rounded,
            title: 'Créer un jeu personnalisé',
            subtitle: 'Points ou manches gagnées, avec une limite optionnelle.',
            onTap: () {
              Navigator.of(sheetContext).pop();
              app.startNewGame();
            },
          ),
        ],
      ),
    ),
  );
}

/// Shown when tapping a game that has variants — pick the base game or one
/// of its variants, or add another variant.
Future<void> _showVariantPicker(BuildContext context, AppState app, Game base, List<Game> variants) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(base.name, style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('Choisissez une variante.', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
          const SizedBox(height: 16),
          _VariantOption(
            game: base,
            label: 'Jeu de base',
            selected: app.draft.gameId == base.id,
            onTap: () {
              app.pickGame(base.id);
              Navigator.of(sheetContext).pop();
            },
          ),
          for (final v in variants) ...[
            const SizedBox(height: 8),
            _VariantOption(
              game: v,
              selected: app.draft.gameId == v.id,
              onTap: () {
                app.pickGame(v.id);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Navigator.of(sheetContext).pop();
              app.startNewGame(parentGameId: base.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text('+ Ajouter une variante', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VariantOption extends StatelessWidget {
  final Game game;
  final String? label;
  final bool selected;
  final VoidCallback onTap;
  const _VariantOption({required this.game, this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Text(game.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  if (label != null) Text(label!, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String sub;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _GameCard({required this.emoji, required this.name, required this.sub, required this.selected, required this.onTap, this.dashed = false, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : (dashed ? Colors.transparent : AppColors.card),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 30, color: dashed ? AppColors.accent : null, fontWeight: dashed ? FontWeight.w700 : null)),
            const SizedBox(height: 8),
            Text(name, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

class CreateGameForm extends StatelessWidget {
  const CreateGameForm({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = app.gameForm;
    final parent = f.parentGameId != null ? app.gameById(f.parentGameId!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parent != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_split_rounded, size: 15, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('Variante de « ${parent.name} »', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _label('Nom du jeu'),
        const SizedBox(height: 9),
        TextFormField(
          initialValue: f.name,
          onChanged: (v) => app.setGameForm((f) => f..name = v),
          style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Ex. Trivial Pursuit',
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 18),
        _label('Emoji'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in Game.emojiChoices)
              GestureDetector(
                onTap: () => app.setGameForm((f) => f..emoji = e),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: f.emoji == e ? AppColors.accentSoft : AppColors.card,
                    border: Border.all(color: f.emoji == e ? AppColors.accent : AppColors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Catégorie'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in Game.categories)
              GestureDetector(
                onTap: () => app.setGameForm((f) => f..category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: f.category == c ? AppColors.ink : AppColors.card,
                    border: Border.all(color: f.category == c ? AppColors.ink : AppColors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(c, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: f.category == c ? Colors.white : AppColors.ink2)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Type de comptage'),
        const SizedBox(height: 9),
        _countOption(app, CountType.highWins, 'Points — le plus haut gagne', 'Catan, Time’s Up, Mario Kart…'),
        _countOption(app, CountType.lowWins, 'Points — le plus bas gagne', 'Skyjo, golf, Uno cumulé…'),
        _countOption(app, CountType.wins, 'Manches gagnées', 'Président, belote, ping-pong…'),
        _countOption(app, CountType.ranks, 'Classement', 'Simple classement, ou avec des places nommées (Président…)'),
        _countOption(app, CountType.winLoss, 'Victoire / défaite', 'Marquez qui a gagné et qui a perdu, sans compter de points — échecs, matchs 1 contre 1…'),
        if (f.countType == CountType.ranks) ...[
          const SizedBox(height: 18),
          Text(
            'On classe les joueurs du 1er au dernier. Vous pouvez nommer certaines places (optionnel) en partant du haut et/ou du bas — les autres restent neutres. Laissez tout vide pour un simple classement, sans noms.',
            style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
          ),
          const SizedBox(height: 16),
          _label('En partant de la 1ère place'),
          const SizedBox(height: 9),
          _roleList(
            app,
            f.topRoles,
            labelFor: (i) => _ordinal(i + 1),
            hintFor: (i) => i == 0 ? 'Ex. Président' : 'Ex. Vice-président',
            onChange: (i, v) => app.setGameForm((f) => f..topRoles[i] = v),
            onRemove: (i) => app.setGameForm((f) => f..topRoles.removeAt(i)),
            onAdd: () => app.setGameForm((f) => f..topRoles.add('')),
          ),
          const SizedBox(height: 16),
          _label('En partant de la dernière place'),
          const SizedBox(height: 9),
          _roleList(
            app,
            f.bottomRoles,
            labelFor: (i) => i == 0 ? 'Dernière' : (i == 1 ? 'Avant-dernière' : '${_ordinal(i + 1)} avant la fin'),
            hintFor: (i) => i == 0 ? 'Ex. Trou du cul' : 'Ex. Vice-trou du cul',
            onChange: (i, v) => app.setGameForm((f) => f..bottomRoles[i] = v),
            onRemove: (i) => app.setGameForm((f) => f..bottomRoles.removeAt(i)),
            onAdd: () => app.setGameForm((f) => f..bottomRoles.add('')),
          ),
        ] else if (f.countType != CountType.wins && f.countType != CountType.winLoss) ...[
          const SizedBox(height: 18),
          _label('Limite de points (optionnel)'),
          const SizedBox(height: 9),
          TextFormField(
            initialValue: f.pointLimit,
            keyboardType: TextInputType.number,
            onChanged: (v) => app.setGameForm((f) => f..pointLimit = v),
            style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Ex. 100',
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('La partie sera signalée comme terminée dès qu’un joueur atteint ce score.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
          ),
        ],
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => app.setGameForm((f) => f..multiRound = !f.multiRound),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: f.multiRound ? AppColors.accentSoft : AppColors.card,
              border: Border.all(color: f.multiRound ? AppColors.accent : AppColors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manches multiples', style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(
                        f.multiRound
                            ? 'Nombre de manches illimité — les scores se cumulent (ex. Président en plusieurs donnes, Skyjo en plusieurs tours).'
                            : 'Une seule manche décide de la partie.',
                        style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: f.multiRound,
                  activeThumbColor: AppColors.accent,
                  onChanged: (v) => app.setGameForm((f) => f..multiRound = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String s) => Text(s, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2));

  String _ordinal(int n) => n == 1 ? '1ère' : '${n}e';

  Widget _roleList(
    AppState app,
    List<String> roles, {
    required String Function(int i) labelFor,
    required String Function(int i) hintFor,
    required void Function(int i, String v) onChange,
    required void Function(int i) onRemove,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, role) in roles.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(labelFor(i), style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: role,
                    onChanged: (v) => onChange(i, v),
                    style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: hintFor(i),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
                    ),
                  ),
                ),
                if (roles.length > 1)
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.mut),
                    onPressed: () => onRemove(i),
                  ),
              ],
            ),
          ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Text('+ Ajouter une place', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
          ),
        ),
      ],
    );
  }

  Widget _countOption(AppState app, CountType type, String title, String desc) {
    final selected = app.gameForm.countType == type;
    return GestureDetector(
      onTap: () => app.setGameForm((f) => f..countType = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 7 : 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink)),
                  Text(desc, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
