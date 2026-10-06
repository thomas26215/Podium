import 'package:flutter/material.dart';

import '../../logic/tournament_bracket.dart';
import '../../models/tournament.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Shown on a pending tournament's screen (see [Tournament.isPending]):
/// previews the first round (or the pools, for "poules + élimination")
/// exactly as the bracket is built, and lets the organizer rearrange it —
/// tap one place, then another, to swap them (in a bracket, a place can be
/// empty: that's how a bye is moved) — or shuffle everything. Locked once the tournament is started.
class TournamentSeedingEditor extends StatefulWidget {
  final AppState app;
  final Tournament tournament;
  final String Function(TournamentEntrant) labelFor;
  const TournamentSeedingEditor({super.key, required this.app, required this.tournament, required this.labelFor});

  @override
  State<TournamentSeedingEditor> createState() => _TournamentSeedingEditorState();
}

class _TournamentSeedingEditorState extends State<TournamentSeedingEditor> {
  /// Pools: seed position of the participant tapped first, waiting for a
  /// second tap to swap with.
  int? _selectedSeed;

  /// Elimination: first-round slot `(pair index, 0 | 1)` tapped first —
  /// possibly an empty one — waiting for a second tap to swap with.
  (int, int)? _selectedSlot;

  void _tapSeed(int position) {
    final selected = _selectedSeed;
    setState(() => _selectedSeed = selected == null ? position : null);
    if (selected == null || selected == position) return;
    final order = List.of(widget.tournament.entrants);
    final tmp = order[selected];
    order[selected] = order[position];
    order[position] = tmp;
    widget.app.reorderTournamentEntrants(widget.tournament, order);
  }

  void _tapSlot(List<List<String?>> pairs, (int, int) slot) {
    final selected = _selectedSlot;
    setState(() => _selectedSlot = selected == null ? slot : null);
    if (selected == null || selected == slot) return;
    final swapped = swapFirstRoundSlots(pairs, selected, slot);
    if (swapped == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un match du premier tour ne peut pas être entièrement vide.')),
      );
      return;
    }
    widget.app.rearrangeFirstRound(widget.tournament, swapped);
  }

  void _shuffle() {
    setState(() {
      _selectedSeed = null;
      _selectedSlot = null;
    });
    final t = widget.tournament;
    if (t.format == TournamentFormat.groupsThenElimination) {
      widget.app.reorderTournamentEntrants(t, List.of(t.entrants)..shuffle());
    } else {
      // Empty slots are shuffled along with everyone else.
      widget.app.rearrangeFirstRound(t, shuffleFirstRound(currentFirstRound(t)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final entrants = t.entrants;
    final isGroups = t.format == TournamentFormat.groupsThenElimination;
    final firstRound = isGroups ? const <List<String?>>[] : currentFirstRound(t);
    final hasEmptySlots = firstRound.any((p) => p.contains(null));

    Widget seedSlot(int position) => _SeedSlot(
          label: widget.labelFor(entrants[position]),
          selected: _selectedSeed == position,
          onTap: () => _tapSeed(position),
        );

    Widget pairSlot(int pair, int side) {
      final entrant = t.entrantById(firstRound[pair][side]);
      return _SeedSlot(
        label: entrant != null ? widget.labelFor(entrant) : 'Place vide',
        empty: entrant == null,
        selected: _selectedSlot == (pair, side),
        onTap: () => _tapSlot(firstRound, (pair, side)),
      );
    }

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
                decoration: chipDecoration(
                  radius: AppRadius.scaled(10),
                  borderWidth: 1.5,
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
          hasEmptySlots
              ? 'Touchez deux places pour les échanger, y compris une place vide. Face à une place vide, on passe directement au tour suivant.'
              : 'Touchez deux participants pour les échanger.',
          style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
        ),
        const SizedBox(height: 12),
        if (isGroups)
          for (final (g, members) in splitIntoGroups([for (var i = 0; i < entrants.length; i++) '$i'], t.groupsCount).indexed)
            _Box(
              title: 'Poule ${g + 1}',
              children: [for (final p in members) seedSlot(int.parse(p))],
            )
        else
          for (var i = 0; i < firstRound.length; i++)
            _Box(
              title: 'Match ${i + 1}',
              children: [pairSlot(i, 0), pairSlot(i, 1)],
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
      decoration: cardDecoration(radius: AppRadius.lg),
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
  final bool empty;
  final VoidCallback onTap;
  const _SeedSlot({required this.label, required this.selected, this.empty = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onInk : (empty ? AppColors.mut : AppColors.ink);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : (empty ? Colors.transparent : AppColors.bg),
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
                style: bodyFont(size: 13.5, weight: empty ? FontWeight.w600 : FontWeight.w700, color: fg),
              ),
            ),
            Icon(Icons.swap_vert_rounded, size: 16, color: selected ? AppColors.onInk : AppColors.mut),
          ],
        ),
      ),
    );
  }
}
