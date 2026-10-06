import 'package:flutter/material.dart';

import '../logic/text_search.dart';
import '../models/game_themes.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'option_chip.dart';

/// Opens the searchable, multi-select theme picker over [groups] (each
/// [ThemeGroup] becomes a titled section) and resolves to the ids picked, in
/// the groups' own order, once "Valider" is tapped — null when dismissed.
/// Used both to tag a game (see `CreateGameForm`) and to filter the game grid.
Future<List<String>?> showThemePicker(
  BuildContext context, {
  required Map<ThemeGroup, List<GameThemeTag>> groups,
  required List<String> selected,
  String title = 'Thèmes',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    sheetAnimationStyle: appSheetAnimation,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThemePickerSheet(groups: groups, initial: selected, title: title),
  );
}

class _ThemePickerSheet extends StatefulWidget {
  final Map<ThemeGroup, List<GameThemeTag>> groups;
  final List<String> initial;
  final String title;
  const _ThemePickerSheet({required this.groups, required this.initial, required this.title});

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  late final Set<String> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = foldText(_query.trim());
    final groups = <ThemeGroup, List<GameThemeTag>>{
      for (final e in widget.groups.entries)
        if (q.isEmpty) e.key: e.value else if (e.value.any((t) => foldText(t.label).contains(q))) e.key: e.value.where((t) => foldText(t.label).contains(q)).toList(),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: bodyFont(size: 18, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2)),
                        Text(
                          _selected.isEmpty ? 'Choisissez-en autant que vous voulez' : '${_selected.length} sélectionné${_selected.length > 1 ? 's' : ''}',
                          style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.close_rounded, color: AppColors.ink), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                decoration: appFieldDecoration(
                  hintText: 'Rechercher un thème',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.mut),
                ),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(child: Text('Aucun thème ne correspond.', style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      children: [
                        for (final e in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(e.key.label.toUpperCase(), style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in e.value)
                                OptionChip(
                                  label: t.label,
                                  selected: _selected.contains(t.id),
                                  onTap: () => setState(() => _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 22),
                        ],
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line)), color: AppColors.bg),
              child: PrimaryButton(
                label: 'Valider',
                onPressed: () => Navigator.of(context).pop([
                  for (final tags in widget.groups.values)
                    for (final t in tags)
                      if (_selected.contains(t.id)) t.id,
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
