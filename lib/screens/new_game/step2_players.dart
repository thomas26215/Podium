import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/text_search.dart';
import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show relativeDateLabel;
import '../../widgets/option_chip.dart';

/// One line under the date/format pickers reminding how many players the
/// game takes (see `Game.playersLabel`) — turns into a warning, never a
/// block, once the picked players fall outside that range.
class _PlayerCountHint extends StatelessWidget {
  final Game? game;
  final int selected;
  const _PlayerCountHint({required this.game, required this.selected});

  @override
  Widget build(BuildContext context) {
    final label = game?.playersLabel;
    if (game == null || label == null) return const SizedBox.shrink();
    final outOfRange = selected > 0 && !game!.acceptsPlayerCount(selected);
    final color = outOfRange ? AppColors.accent : AppColors.mut;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(outOfRange ? Icons.warning_amber_rounded : Icons.group_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              outOfRange ? 'Prévu pour $label — vous en avez sélectionné $selected.' : 'Prévu pour $label.',
              style: bodyFont(size: 12.5, weight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class Step2Players extends StatelessWidget {
  const Step2Players({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.draft;
    final players = app.viewPlayers;
    final rule = app.draftRule;
    // Ranks and win/loss rules are always solo scoring, and a rule flagged
    // GameRule.coop picks the mode by itself — none of these ever show the
    // "Chacun pour soi"/"Équipes" choice (see AppState._applyRule, which
    // sets draft.mode accordingly up front). Every other rule keeps that
    // choice exactly as before.
    final modeFixed = rule != null && (rule.isRanks || rule.isWinLoss || rule.coop);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    final chosen = app.effectivePlayedAt;
    final isCustom = chosen != today && chosen != yesterday && chosen != dayBefore;

    // A tournament's entrants are a fixed roster for the whole bracket, not
    // one dated event with a best-of-N format — those two sections only
    // make sense when this step is picking players for a single match (see
    // AppState.isTournamentFlow).
    final isTournamentFlow = app.isTournamentFlow;
    final game = app.gameById(d.gameId ?? '');
    final choice = !isTournamentFlow && game != null && game.hasCharacters ? game.characterChoice : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isTournamentFlow) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quand ?', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DateChip(label: "Aujourd'hui", selected: chosen == today, onTap: () => app.setPlayedAt(null)),
                    _DateChip(label: 'Hier', selected: chosen == yesterday, onTap: () => app.setPlayedAt(yesterday)),
                    _DateChip(label: 'Avant-hier', selected: chosen == dayBefore, onTap: () => app.setPlayedAt(dayBefore)),
                    _DateChip(
                      icon: Icons.calendar_month_rounded,
                      label: isCustom ? relativeDateLabel(chosen) : null,
                      selected: isCustom,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: chosen,
                          firstDate: today.subtract(const Duration(days: 365 * 3)),
                          lastDate: today,
                          helpText: 'Quand a eu lieu la partie ?',
                          cancelText: 'Annuler',
                          confirmText: 'Choisir',
                        );
                        if (picked != null) app.setPlayedAt(picked);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Format de la partie', style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      for (final n in [1, 3, 5, 7])
                        Pressable(
                          onTap: () => app.setBestOf(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: d.bestOf == n ? AppColors.ink : null, borderRadius: BorderRadius.circular(8)),
                            child: Text(n == 1 ? 'x1' : 'Bo$n', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: d.bestOf == n ? Colors.white : AppColors.mut)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!isTournamentFlow && game != null && game.hasSetupChoice) _SetupPicker(choice: game.setupChoice!),
        if (isTournamentFlow)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Sélectionnez les participants dans l\'ordre : en cas de nombre impair, les premiers de la liste ont plus de chances d\'avoir un tour de repos au premier tour.',
              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ),
        if (!isTournamentFlow) _PlayerCountHint(game: game, selected: d.playerIds.length),
        if (!modeFixed) ...[
          Row(
            children: [
              Expanded(child: _ModeCard(label: 'Chacun pour soi', sub: 'Score individuel', selected: d.mode == 'ffa', onTap: () => app.setMode('ffa'))),
              const SizedBox(width: 10),
              Expanded(child: _ModeCard(label: 'Équipes', sub: '2 à 4 camps', selected: d.mode == 'team', onTap: () => app.setMode('team'))),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (d.mode == 'coop')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent.withValues(alpha: 0.35), width: 1.2), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Icon(Icons.diversity_3_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Partie coopérative : tout le groupe gagne ou perd ensemble contre le jeu.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ),
        if (d.mode == 'team')
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Nombre d'équipes", style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                  child: Row(
                    children: [
                      for (final n in [2, 3, 4])
                        Pressable(
                          onTap: () => app.setTeamCount(n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: d.teamCount == n ? AppColors.ink : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$n', style: bodyFont(size: 13, weight: FontWeight.w800, color: d.teamCount == n ? Colors.white : AppColors.mut)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final (i, p) in players.indexed)
          FadeSlideIn(
            delay: Duration(milliseconds: i * 30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: d.playerIds.contains(p.uid) ? AppColors.accent : AppColors.line, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
              Row(
                children: [
                  Pressable(onTap: () => app.togglePlayer(p.uid), child: Avatar(initial: p.initial, color: Color(p.color), size: 38, fontSize: 15)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Pressable(
                      onTap: () => app.togglePlayer(p.uid),
                      child: Text(p.displayName, style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ),
                  if (d.playerIds.contains(p.uid) && d.mode == 'team')
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(11)),
                      child: Row(
                        children: [
                          for (var i = 0; i < d.teamCount; i++)
                            Builder(builder: (_) {
                              final label = String.fromCharCode(65 + i);
                              final on = (d.team[p.uid] ?? 'A') == label;
                              return Pressable(
                                onTap: () => app.setPlayerTeam(p.uid, label),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 34,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: on ? AppColors.ink : null, borderRadius: BorderRadius.circular(8)),
                                  child: Text(label, style: bodyFont(size: 13, weight: FontWeight.w800, color: on ? Colors.white : AppColors.mut)),
                                ),
                              );
                            }),
                        ],
                      ),
                    )
                  else if (!(d.mode == 'team' && d.playerIds.contains(p.uid)))
                    Pressable(
                      onTap: () => app.togglePlayer(p.uid),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: d.playerIds.contains(p.uid) ? AppColors.accent : null,
                          border: Border.all(color: d.playerIds.contains(p.uid) ? AppColors.accent : AppColors.line, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: d.playerIds.contains(p.uid) ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                      ),
                    ),
                ],
              ),
              if (choice != null && d.playerIds.contains(p.uid))
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 50),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CharacterPill(
                      character: d.characters[p.uid],
                      prompt: choice.pickPrompt,
                      onTap: () async {
                        final picked = await _pickCharacter(context, app, p.uid, p.displayName, choice);
                        if (picked != null) app.setPlayerCharacter(p.uid, picked.isEmpty ? null : picked);
                      },
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The "Cartes Royaume"/"Extensions"… block (see [Game.setupChoice]): one
/// chip per option, a live "n/count" tally and, when the game says how many
/// a match uses, a random draw. A search field shows up once the list gets
/// long (a Dominion player may type in every card they own).
class _SetupPicker extends StatefulWidget {
  final SetupChoice choice;
  const _SetupPicker({required this.choice});

  @override
  State<_SetupPicker> createState() => _SetupPickerState();
}

class _SetupPickerState extends State<_SetupPicker> {
  static const _searchThreshold = 30;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final picks = app.draft.setupPicks;
    final choice = widget.choice;
    final count = choice.count;
    final q = foldText(_query.trim());
    final visible = q.isEmpty ? choice.options : choice.options.where((o) => foldText(o).contains(q) || picks.contains(o)).toList();
    final off = count != null && picks.length != count;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: choice.label, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2)),
                    TextSpan(
                      text: count != null ? '  ${picks.length}/$count' : (picks.isEmpty ? '' : '  ${picks.length}'),
                      style: bodyFont(size: 13, weight: FontWeight.w800, color: off ? AppColors.accent : AppColors.mut),
                    ),
                  ]),
                ),
              ),
              if (count != null && count <= choice.options.length)
                Pressable(
                  onTap: app.randomizeSetupPicks,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.casino_rounded, size: 17, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Tirer au hasard', style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.accent)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (choice.options.length > _searchThreshold)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                decoration: appFieldDecoration(hintText: 'Rechercher', prefixIcon: Icon(Icons.search_rounded, color: AppColors.mut)),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in visible)
                OptionChip(
                  label: o,
                  icon: picks.contains(o) ? Icons.check_rounded : null,
                  selected: picks.contains(o),
                  onTap: () => app.toggleSetupPick(o),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the game's [choice] options for `uid` — returns the
/// picked one, '' for "Aucun" (clears it), or null if dismissed. Characters
/// already taken by another player stay pickable (some games allow
/// duplicates) but say who has them.
Future<String?> _pickCharacter(BuildContext context, AppState app, String uid, String playerName, CharacterChoice choice) {
  final current = app.draft.characters[uid];
  final takenBy = <String, String>{
    for (final e in app.draft.characters.entries)
      if (e.key != uid && app.draft.playerIds.contains(e.key)) e.value: app.playerById(e.key)?.displayName ?? '?',
  };
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(choice.ofPlayer(playerName), style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
            ),
            for (final c in choice.options)
              _CharacterOption(label: c, sub: takenBy[c] != null ? choice.takenBy(takenBy[c]!) : null, selected: current == c, onTap: () => Navigator.of(sheetContext).pop(c)),
            if (current != null) _CharacterOption(label: 'Aucun', selected: false, muted: true, onTap: () => Navigator.of(sheetContext).pop('')),
          ],
        ),
      ),
    ),
  );
}

class _CharacterOption extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final bool muted;
  final VoidCallback onTap;
  const _CharacterOption({required this.label, this.sub, required this.selected, this.muted = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.card,
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: bodyFont(size: 15, weight: FontWeight.w700, color: muted ? AppColors.mut : AppColors.ink)),
                  if (sub != null) Text(sub!, style: bodyFont(size: 11.5, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// [prompt] ("Choisir une merveille") or the picked option, under a
/// selected player's row.
class _CharacterPill extends StatelessWidget {
  final String? character;
  final String prompt;
  final VoidCallback onTap;
  const _CharacterPill({required this.character, required this.prompt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final set = character != null;
    final color = set ? AppColors.accent : AppColors.mut;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: set ? AppColors.accentSoft : AppColors.bg,
          border: Border.all(color: set ? AppColors.accent : AppColors.line, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.theater_comedy_rounded, size: 15, color: color),
            const SizedBox(width: 6),
            Text(character ?? prompt, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: color)),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _DateChip({this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.mut;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 14, color: color),
            if (icon != null && label != null) const SizedBox(width: 6),
            if (label != null) Text(label!, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(label, style: bodyFont(size: 14, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
            Text(sub, style: bodyFont(size: 11, weight: FontWeight.w600, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.mut)),
          ],
        ),
      ),
    );
  }
}
