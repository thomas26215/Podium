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
        if (f.countType == CountType.highWins || f.countType == CountType.lowWins) ...[
          const SizedBox(height: 18),
          _label('Catégories de score'),
          const SizedBox(height: 8),
          Text(
            'Ajoutez les rubriques à compter à la fin de la partie. Chaque champ reçoit sa couleur et le total est calculé automatiquement.',
            style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
          ),
          const SizedBox(height: 12),
          if (f.scoreFields.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Ex. merveilles, pièces, guerre, science…', style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.mut)),
                  ),
                  GestureDetector(
                    onTap: () => app.setGameForm((draft) => draft
                      ..scoreFields.add(_newScoreField(draft.scoreFields.length))
                      ..multiRound = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                      child: Text('+ Ajouter', style: bodyFont(size: 13, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final (i, field) in f.scoreFields.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: Color(field.color).withValues(alpha: 0.55), width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picked = await _pickScoreFieldColor(context, field.color);
                            if (picked == null) return;
                            if (!context.mounted) return;
                            app.setGameForm((draft) => draft..scoreFields[i] = field.copyWith(color: picked));
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: Color(field.color), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(field.color).withValues(alpha: 0.24), blurRadius: 10, offset: const Offset(0, 4))]),
                            child: const Icon(Icons.palette_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: field.label,
                            onChanged: (v) => app.setGameForm((draft) => draft..scoreFields[i] = field.copyWith(label: v)),
                            style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                            decoration: InputDecoration(
                              hintText: 'Ex. Science',
                              filled: true,
                              fillColor: AppColors.bg,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: Color(field.color), width: 1.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: AppColors.mut),
                          onPressed: () => app.setGameForm((draft) => draft..scoreFields.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => app.setGameForm((draft) => draft
                    ..scoreFields.add(_newScoreField(draft.scoreFields.length))
                    ..multiRound = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text('+ Ajouter une catégorie', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
                  ),
                ),
              ],
            ),
        ],
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
          onTap: f.scoreFields.isNotEmpty ? null : () => app.setGameForm((f) => f..multiRound = !f.multiRound),
          child: Opacity(
            opacity: f.scoreFields.isNotEmpty ? 0.45 : 1,
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
                          f.scoreFields.isNotEmpty
                              ? 'Ce champ est grisé car vous jouez avec catégories de score.'
                              : (f.multiRound
                                  ? 'Nombre de manches illimité — les scores se cumulent (ex. Président en plusieurs donnes, Skyjo en plusieurs tours).'
                                  : 'Une seule manche décide de la partie.'),
                          style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    ignoring: f.scoreFields.isNotEmpty,
                    child: Switch(
                      value: f.multiRound,
                      activeThumbColor: AppColors.accent,
                      onChanged: (v) => app.setGameForm((f) => f..multiRound = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String s) => Text(s, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2));

  String _ordinal(int n) => n == 1 ? '1ère' : '${n}e';

  GameScoreField _newScoreField(int index) {
    final color = GameScoreField.palette[index % GameScoreField.palette.length];
    return GameScoreField(id: 'score_${DateTime.now().microsecondsSinceEpoch}_$index', label: '', color: color);
  }

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

Future<int?> _pickScoreFieldColor(BuildContext context, int initialColor) async {
  final swatches = <Color>[
    const Color(0xFF3B82F6),
    const Color(0xFF22C55E),
    const Color(0xFFEF4444),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFF06B6D4),
    const Color(0xFFF97316),
    const Color(0xFFE5537B),
    const Color(0xFF14B8A6),
    const Color(0xFF0F766E),
    const Color(0xFF6366F1),
    const Color(0xFFB45309),
  ];
  var selected = Color(initialColor);
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final hsv = HSVColor.fromColor(selected);
          final previewTextColor = ThemeData.estimateBrightnessForColor(selected) == Brightness.dark ? Colors.white : Colors.black;
          return AlertDialog(
            backgroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: Text('Choisir une couleur', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: selected, borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Text('Aperçu', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: previewTextColor)),
                  ),
                  const SizedBox(height: 14),
                  Text('Palette rapide', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in swatches)
                        GestureDetector(
                          onTap: () => setState(() => selected = color),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: selected.toARGB32() == color.toARGB32() ? AppColors.ink : Colors.transparent, width: 2.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ColorSlider(
                    label: 'Teinte',
                    value: hsv.hue,
                    min: 0,
                    max: 360,
                    activeColor: selected,
                    onChanged: (value) => setState(() => selected = HSVColor.fromAHSV(hsv.alpha, value, hsv.saturation, hsv.value).toColor()),
                  ),
                  _ColorSlider(
                    label: 'Saturation',
                    value: hsv.saturation,
                    min: 0,
                    max: 1,
                    activeColor: selected,
                    onChanged: (value) => setState(() => selected = HSVColor.fromAHSV(hsv.alpha, hsv.hue, value, hsv.value).toColor()),
                  ),
                  _ColorSlider(
                    label: 'Luminosité',
                    value: hsv.value,
                    min: 0,
                    max: 1,
                    activeColor: selected,
                    onChanged: (value) => setState(() => selected = HSVColor.fromAHSV(hsv.alpha, hsv.hue, hsv.saturation, value).toColor()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(selected.toARGB32()),
                style: ElevatedButton.styleFrom(backgroundColor: selected, foregroundColor: previewTextColor, elevation: 0),
                child: const Text('Choisir'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _ColorSlider({required this.label, required this.value, required this.min, required this.max, required this.activeColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: bodyFont(size: 12, weight: FontWeight.w800, color: AppColors.ink2)),
              Text(value.toStringAsFixed(max > 1 ? 0 : 2), style: bodyFont(size: 11.5, weight: FontWeight.w700, color: AppColors.mut)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: activeColor,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.12),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
