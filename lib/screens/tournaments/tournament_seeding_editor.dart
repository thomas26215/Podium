import 'package:flutter/material.dart';

import '../../logic/tournament_bracket.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Shown on a pending tournament's screen (see [Tournament.isPending]):
/// previews the first round (or the pools, for "poules + élimination")
/// exactly as the bracket is built, and lets the organizer rearrange it —
/// tap one participant, then another, to swap their places — or shuffle
/// everything. Locked once the tournament is started.
class TournamentSeedingEditor extends StatefulWidget {
  final AppState app;
  final Tournament tournament;
  final String Function(TournamentEntrant) labelFor;
  const TournamentSeedingEditor({super.key, required this.app, required this.tournament, required this.labelFor});

  @override
  State<TournamentSeedingEditor> createState() => _TournamentSeedingEditorState();
}

class _TournamentSeedingEditorState extends State<TournamentSeedingEditor> {
  /// Seed position of the participant tapped first, waiting for a second tap
  /// to swap with.
  int? _selected;

  void _tap(int position) {
    final selected = _selected;
    setState(() => _selected = selected == null ? position : null);
    if (selected == null || selected == position) return;
    final order = List.of(widget.tournament.entrants);
    final tmp = order[selected];
    order[selected] = order[position];
    order[position] = tmp;
    widget.app.reorderTournamentEntrants(widget.tournament, order);
  }

  void _shuffle() {
    setState(() => _selected = null);
    widget.app.reorderTournamentEntrants(widget.tournament, List.of(widget.tournament.entrants)..shuffle());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final entrants = t.entrants;
    // Seed positions stand in for entrant ids so the bracket helpers lay
    // the preview out exactly like the real bracket.
    final positions = [for (var i = 0; i < entrants.length; i++) '$i'];

    Widget slot(int position) => _SeedSlot(
          label: widget.labelFor(entrants[position]),
          selected: _selected == position,
          onTap: () => _tap(position),
        );

    final isGroups = t.format == TournamentFormat.groupsThenElimination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isGroups ? 'Composition des poules' : 'Premier tour',
                style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
              ),
            ),
            Pressable(
              onTap: _shuffle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shuffle_rounded, size: 16, color: AppColors.ink),
                    const SizedBox(width: 6),
                    Text('Mélanger', style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Touchez deux participants pour les échanger.'
          '${!isGroups && entrants.length != bracketSizeFor(entrants.length) ? ' Les exemptés passent directement au tour suivant.' : ''}',
          style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
        ),
        const SizedBox(height: 12),
        if (isGroups)
          for (final (g, members) in splitIntoGroups(positions, t.groupsCount).indexed)
            _Box(
              title: 'Poule ${g + 1}',
              children: [for (final p in members) slot(int.parse(p))],
            )
        else
          for (final (i, pair) in firstRoundPairs(positions).indexed)
            _Box(
              title: 'Match ${i + 1}',
              children: [
                slot(int.parse(pair[0]!)),
                if (pair[1] != null) slot(int.parse(pair[1]!)) else const _ByeSlot(),
              ],
            ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Box({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
          const SizedBox(height: 8),
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            c,
          ],
        ],
      ),
    );
  }
}

class _SeedSlot extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SeedSlot({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bg,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyFont(size: 13.5, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink),
              ),
            ),
            Icon(Icons.swap_vert_rounded, size: 16, color: selected ? Colors.white : AppColors.mut),
          ],
        ),
      ),
    );
  }
}

class _ByeSlot extends StatelessWidget {
  const _ByeSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Text('Exempt', style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.mut)),
    );
  }
}
