import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../services/game_rules_pdf.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Rules reminders for a game, grouped into categories the group defines
/// itself (e.g. for Rami: "Règles générales", "Règle de la première pose",
/// "Règles spéciales"…), each holding its own list of individual rules —
/// purely a reference, never consulted by the scoring logic.
class GameRulesScreen extends StatefulWidget {
  final Game game;
  const GameRulesScreen({super.key, required this.game});

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> {
  late List<_SectionForm> _sections;

  @override
  void initState() {
    super.initState();
    _sections = widget.game.ruleSections.isEmpty
        ? [_SectionForm()]
        : widget.game.ruleSections.map((s) => _SectionForm(title: s.title, rules: s.rules)).toList();
  }

  @override
  void dispose() {
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSection() => setState(() => _sections.add(_SectionForm()));

  void _removeSection(int i) => setState(() {
        _sections.removeAt(i).dispose();
      });

  void _addRule(int sectionIndex) => setState(() => _sections[sectionIndex].ruleCtrls.add(TextEditingController()));

  void _removeRule(int sectionIndex, int ruleIndex) => setState(() {
        _sections[sectionIndex].ruleCtrls.removeAt(ruleIndex).dispose();
      });

  List<GameRuleSection> _currentSections() => _sections
      .map((s) => GameRuleSection(
            title: s.titleCtrl.text.trim(),
            rules: s.ruleCtrls.map((c) => c.text.trim()).where((r) => r.isNotEmpty).toList(),
          ))
      .where((s) => s.title.isNotEmpty || s.rules.isNotEmpty)
      .toList();

  Future<void> _save(AppState app) async {
    final ok = await app.updateGameRules(widget.game, _currentSections());
    if (ok && mounted) Navigator.of(context).pop();
  }

  // Exports whatever is currently on screen, saved or not — no need to save
  // first just to preview/print the PDF.
  Future<void> _export() => exportGameRulesPdf(widget.game.copyWith(ruleSections: _currentSections()));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Règles — ${widget.game.name}', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf_rounded, color: AppColors.ink), tooltip: 'Exporter en PDF', onPressed: _export),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (app.flowError != null) ...[
            Text(app.flowError!, style: bodyFont(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
            const SizedBox(height: 12),
          ],
          Text(
            "Ces règles sont juste un aide-mémoire pour le groupe — elles n'ont aucun effet sur le calcul des scores.",
            style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
          ),
          const SizedBox(height: 16),
          for (final (i, s) in _sections.indexed) ...[
            _SectionCard(
              section: s,
              onRemoveSection: _sections.length > 1 ? () => _removeSection(i) : null,
              onAddRule: () => _addRule(i),
              onRemoveRule: (ruleIndex) => _removeRule(i, ruleIndex),
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _addSection,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text('+ Ajouter une catégorie', style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.ink2)),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Enregistrer', loading: app.busy, onPressed: () => _save(app)),
        ],
      ),
    );
  }
}

class _SectionForm {
  final TextEditingController titleCtrl;
  final List<TextEditingController> ruleCtrls;
  _SectionForm({String title = '', List<String>? rules})
      : titleCtrl = TextEditingController(text: title),
        ruleCtrls = (rules == null || rules.isEmpty) ? [TextEditingController()] : rules.map((r) => TextEditingController(text: r)).toList();

  void dispose() {
    titleCtrl.dispose();
    for (final c in ruleCtrls) {
      c.dispose();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final _SectionForm section;
  final VoidCallback? onRemoveSection;
  final VoidCallback onAddRule;
  final void Function(int ruleIndex) onRemoveRule;
  const _SectionCard({required this.section, this.onRemoveSection, required this.onAddRule, required this.onRemoveRule});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: section.titleCtrl,
                  style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Ex. Règles générales',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (onRemoveSection != null) IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.mut), onPressed: onRemoveSection),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, ctrl) in section.ruleCtrls.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('•', style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.mut)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      style: bodyFont(size: 13.5, weight: FontWeight.w600, color: AppColors.ink2),
                      decoration: InputDecoration(
                        hintText: 'Une règle…',
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.line, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
                      ),
                    ),
                  ),
                  if (section.ruleCtrls.length > 1)
                    IconButton(icon: Icon(Icons.close, size: 16, color: AppColors.mut), onPressed: () => onRemoveRule(i)),
                ],
              ),
            ),
          GestureDetector(
            onTap: onAddRule,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text('+ Ajouter une règle', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2)),
            ),
          ),
        ],
      ),
    );
  }
}
