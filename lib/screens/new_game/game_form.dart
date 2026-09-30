import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../models/game_themes.dart';
import '../../state/app_state.dart';
import '../../state/new_game_draft.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/option_chip.dart';
import '../../widgets/theme_picker.dart';

/// The "create/edit a game" form shown inside the new-game sheet, in airy
/// sections: who the game is (emoji, name, category), its fixed parameters
/// (player count, theme tags), what each player picks (heroes, wonders…,
/// optional), what a match is set up with (Dominion's kingdom cards,
/// expansions…, optional), and how it is scored (one or
/// several [GameRule]s). Detail only takes space where it is being edited —
/// extra rules are collapsible cards.
class CreateGameForm extends StatelessWidget {
  const CreateGameForm({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdentitySection(),
        SizedBox(height: 28),
        _ParametersSection(),
        SizedBox(height: 28),
        _CharacterChoiceSection(),
        SizedBox(height: 28),
        _SetupChoiceSection(),
        SizedBox(height: 28),
        _RulesSection(),
      ],
    );
  }
}

// ── Shared building blocks ─────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  const _SectionTitle(this.title, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
          ],
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _FormCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: child,
    );
  }
}

/// Low-key "+ label" action used wherever a list can grow.
class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(label, style: bodyFont(size: 13.5, weight: FontWeight.w700, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _RemoveLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RemoveLink(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.mut),
            const SizedBox(width: 4),
            Text(label, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

Widget _fieldLabel(String s) => Text(s, style: bodyFont(size: 13, weight: FontWeight.w800, color: AppColors.ink2));

Widget _helper(String s) => Text(s, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut));

/// A titled row with a trailing switch — several stack inside one card,
/// separated by hairlines.
class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  _helper(subtitle),
                ],
              ),
            ),
            Switch(value: value, activeThumbColor: AppColors.accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ── Identity ───────────────────────────────────────────────────────────────

class _IdentitySection extends StatelessWidget {
  const _IdentitySection();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = app.gameForm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Pressable(
              onTap: () => _pickEmoji(context, app),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text(f.emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: f.name,
                onChanged: (v) => app.setGameForm((f) => f..name = v),
                style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
                decoration: appFieldDecoration(hintText: 'Nom du jeu (ex. Trivial Pursuit)', contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in Game.categories)
              OptionChip(
                label: c,
                selected: f.category == c,
                onTap: () => app.setGameForm((f) {
                  f.category = c;
                  // Each category has its own theme list — drop the tags the new one doesn't offer.
                  f.themes = f.cleanThemes;
                  return f;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickEmoji(BuildContext context, AppState app) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Choisir un emoji', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in Game.emojiChoices)
              Pressable(
                onTap: () => Navigator.of(dialogContext).pop(e),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: app.gameForm.emoji == e ? AppColors.accentSoft : AppColors.card,
                    border: Border.all(color: app.gameForm.emoji == e ? AppColors.accent : AppColors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) app.setGameForm((f) => f..emoji = picked);
  }
}

// ── Game parameters ────────────────────────────────────────────────────────

/// The "Paramètres du jeu" section: fixed descriptors of the game — how many
/// players it takes and its theme tags (drawn from a closed list per
/// category, see [themesForCategory]). Nothing here is named by the user.
class _ParametersSection extends StatelessWidget {
  const _ParametersSection();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = app.gameForm;
    final tags = themesForCategory(f.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Paramètres du jeu', hint: 'Optionnel — pour décrire le jeu et le retrouver plus facilement.'),
        _fieldLabel('Nombre de joueurs'),
        const SizedBox(height: 8),
        // "Mon espace solo" only holds one-player games (see Game.asSolo).
        if (app.isPersonalContext)
          _helper('1 joueur — les jeux de votre espace solo se jouent seul.')
        else
          Row(
            children: [
              Expanded(child: _playersField('Min. (ex. 2)', f.minPlayers, (f, v) => f.minPlayers = v, app)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _helper('à')),
              Expanded(child: _playersField('Max. (ex. 4)', f.maxPlayers, (f, v) => f.maxPlayers = v, app)),
            ],
          ),
        if (!app.isPersonalContext && !f.playersValid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Au moins 2 joueurs, et le minimum ne peut pas dépasser le maximum.', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 22),
          _fieldLabel('Thèmes'),
          const SizedBox(height: 8),
          if (f.themes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags)
                    if (f.themes.contains(t.id)) _SelectedTag(label: t.label, onRemove: () => app.setGameForm((f) => f..themes = f.themes.where((id) => id != t.id).toList())),
                ],
              ),
            ),
          _AddButton(f.themes.isEmpty ? 'Ajouter des thèmes' : 'Modifier les thèmes', onTap: () async {
            final picked = await showThemePicker(context, groups: themesByGroup(f.category), selected: f.themes);
            if (picked != null) app.setGameForm((f) => f..themes = picked);
          }),
        ],
      ],
    );
  }

  Widget _playersField(String hint, String value, void Function(GameFormDraft f, String v) set, AppState app) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.number,
      onChanged: (v) => app.setGameForm((f) {
        set(f, v);
        return f;
      }),
      style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
      decoration: appFieldDecoration(hintText: hint),
    );
  }
}

// ── Per-player choice ──────────────────────────────────────────────────────

/// The "Choix par joueur" section (see [Game.characterChoice]): off by
/// default; once switched on, the choice gets a name and gender ("Héros",
/// "Merveille"…) so the match wizard reads naturally, and its list of
/// options, typed in by the user.
class _CharacterChoiceSection extends StatefulWidget {
  const _CharacterChoiceSection();

  @override
  State<_CharacterChoiceSection> createState() => _CharacterChoiceSectionState();
}

class _CharacterChoiceSectionState extends State<_CharacterChoiceSection> {
  late final TextEditingController _label;
  final _option = TextEditingController();
  final _optionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: context.read<AppState>().gameForm.characterLabel);
  }

  @override
  void dispose() {
    _label.dispose();
    _option.dispose();
    _optionFocus.dispose();
    super.dispose();
  }

  void _addOption(AppState app) {
    final name = _option.text.trim();
    if (name.isEmpty) return;
    if (!app.gameForm.characters.contains(name)) app.setGameForm((f) => f..characters = [...f.characters, name]);
    _option.clear();
    _optionFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = app.gameForm;
    final label = f.characterLabel.trim().isEmpty ? CharacterChoice.defaultLabel : f.characterLabel.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Choix par joueur'),
        _FormCard(
          padding: EdgeInsets.zero,
          child: _SwitchRow(
            title: 'Chacun choisit un élément',
            subtitle: 'Un héros, une merveille, une faction… à choisir pour chaque joueur en début de partie.',
            value: f.characterEnabled,
            onChanged: (v) => app.setGameForm((f) => f..characterEnabled = v),
          ),
        ),
        if (f.characterEnabled) ...[
          const SizedBox(height: 18),
          _fieldLabel('Nom du choix'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _label,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => app.setGameForm((f) => f..characterLabel = v),
                  style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                  decoration: appFieldDecoration(hintText: 'Ex. Héros, Merveille, Faction'),
                ),
              ),
              const SizedBox(width: 8),
              OptionChip(label: 'un', selected: !f.characterFeminine, onTap: () => app.setGameForm((f) => f..characterFeminine = false)),
              const SizedBox(width: 6),
              OptionChip(label: 'une', selected: f.characterFeminine, onTap: () => app.setGameForm((f) => f..characterFeminine = true)),
            ],
          ),
          const SizedBox(height: 18),
          _fieldLabel('Nombre par joueur'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var n = 1; n <= 4; n++)
                OptionChip(label: '$n', selected: f.characterCount == n, onTap: () => app.setGameForm((f) => f..characterCount = n)),
            ],
          ),
          const SizedBox(height: 6),
          _helper('Affiché « ${CharacterChoice(label: label, feminine: f.characterFeminine, count: f.characterCount).pickPrompt} » pendant la partie.'),
          const SizedBox(height: 18),
          _fieldLabel('Éléments proposés'),
          const SizedBox(height: 8),
          if (f.characters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in f.characters) _SelectedTag(label: c, onRemove: () => app.setGameForm((f) => f..characters = f.characters.where((x) => x != c).toList())),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _option,
                  focusNode: _optionFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addOption(app),
                  style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                  decoration: appFieldDecoration(hintText: f.characters.isEmpty ? 'Ex. Babylone, Rhodes, Gizeh…' : 'Ajouter un élément'),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => _addOption(app),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(Icons.add_rounded, color: AppColors.accent),
                ),
              ),
            ],
          ),
          if (!f.charactersValid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Ajoutez au moins un élément, ou désactivez le choix.', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
            ),
        ],
      ],
    );
  }
}

// ── Match setup ────────────────────────────────────────────────────────────

/// The "Sélection pour la partie" section (see [Game.setupChoice]): what a
/// match is set up with — Dominion's kingdom cards, Catan's expansions,
/// Carcassonne's modules… Left without options, the match wizard never
/// asks about it.
class _SetupChoiceSection extends StatefulWidget {
  const _SetupChoiceSection();

  @override
  State<_SetupChoiceSection> createState() => _SetupChoiceSectionState();
}

class _SetupChoiceSectionState extends State<_SetupChoiceSection> {
  late final TextEditingController _label;
  late final TextEditingController _count;
  final _option = TextEditingController();
  final _optionFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final f = context.read<AppState>().gameForm;
    _label = TextEditingController(text: f.setupLabel);
    _count = TextEditingController(text: f.setupCount);
  }

  @override
  void dispose() {
    _label.dispose();
    _count.dispose();
    _option.dispose();
    _optionFocus.dispose();
    super.dispose();
  }

  void _addOption(AppState app) {
    final name = _option.text.trim();
    if (name.isEmpty) return;
    if (!app.gameForm.setupOptions.contains(name)) app.setGameForm((f) => f..setupOptions = [...f.setupOptions, name]);
    _option.clear();
    _optionFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = app.gameForm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Sélection pour la partie', hint: 'Optionnel — cartes Royaume de Dominion, extensions, modules… cochés au lancement de chaque partie.'),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Nom'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _label,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => app.setGameForm((f) => f..setupLabel = v),
                    style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: appFieldDecoration(hintText: 'Ex. Cartes Royaume'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Par partie'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => app.setGameForm((f) => f..setupCount = v),
                    style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: appFieldDecoration(hintText: 'Ex. 10'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        f.setupCountValid
            ? _helper('Le nombre est facultatif : il permet de tirer la sélection au hasard.')
            : Text('Le nombre par partie doit être un entier positif.', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.accent)),
        const SizedBox(height: 18),
        _fieldLabel('Éléments proposés'),
        const SizedBox(height: 8),
        if (f.setupOptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in f.setupOptions) _SelectedTag(label: o, onRemove: () => app.setGameForm((f) => f..setupOptions = f.setupOptions.where((x) => x != o).toList())),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _option,
                focusNode: _optionFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addOption(app),
                style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                decoration: appFieldDecoration(hintText: f.setupOptions.isEmpty ? 'Ex. Chapelle, Village, Sorcière…' : 'Ajouter un élément'),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: () => _addOption(app),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(Icons.add_rounded, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A chosen theme, shown in the form — tap to remove it.
class _SelectedTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SelectedTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
        decoration: BoxDecoration(color: AppColors.accentSoft, border: Border.all(color: AppColors.accent, width: 1.5), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: bodyFont(size: 13, weight: FontWeight.w700, color: AppColors.accent)),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 15, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// ── Scoring rules ──────────────────────────────────────────────────────────

class _RulesSection extends StatelessWidget {
  const _RulesSection();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rules = app.gameForm.rules;
    final multi = rules.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(multi ? 'Règles' : 'Comptage', hint: multi ? 'Chaque règle a sa façon de compter — on choisit laquelle au lancement d’une partie.' : null),
        if (!multi)
          _RuleFields(index: 0, rule: rules.single)
        else
          for (final (i, rule) in rules.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CollapsibleRuleCard(key: ValueKey(rule.id), index: i, rule: rule, initiallyExpanded: i == rules.length - 1),
            ),
        SizedBox(height: multi ? 0 : 10),
        _AddButton('Ajouter une règle', onTap: () => app.setGameForm((f) => f..rules.add(GameRuleFormDraft(name: 'Règle ${f.rules.length + 1}')))),
      ],
    );
  }
}

String _countLabel(CountType t) => switch (t) {
      CountType.highWins => 'Points · plus haut',
      CountType.lowWins => 'Points · plus bas',
      CountType.wins => 'Manches gagnées',
      CountType.ranks => 'Classement',
      CountType.winLoss => 'Victoire / défaite',
      CountType.time => 'Temps',
    };

String _countHint(CountType t) => switch (t) {
      CountType.highWins => 'Le plus haut score gagne — Catan, Time’s Up, Mario Kart…',
      CountType.lowWins => 'Le plus bas score gagne — Skyjo, golf, Uno cumulé…',
      CountType.wins => 'On compte les manches gagnées — Président, belote, ping-pong…',
      CountType.ranks => 'Un classement, avec ou sans places nommées (Président…).',
      CountType.winLoss => 'Qui a gagné, sans points — échecs, matchs 1 contre 1…',
      CountType.time => 'Un temps, le plus rapide gagne — contre-la-montre Mario Kart, speedrun…',
    };

/// Short one-line summary of a rule's counting config (e.g. "Points · plus
/// haut · 100 pts max") — shown as the collapsed-card subtitle in
/// [_CollapsibleRuleCard] (see `StepRule`'s own `_RuleOption._description`
/// for the equivalent over a persisted [GameRule] rather than a form draft).
String ruleSummaryLine(GameRuleFormDraft rule) {
  final bits = <String>[
    _countLabel(rule.countType),
    if (rule.parsedPointLimit != null) '${rule.parsedPointLimit} pts max',
    if (rule.coop) 'Coopératif',
  ];
  return bits.join(' · ');
}

/// A rule's card in multi-rule mode: a compact header (name, one-line
/// summary, remove button, expand/collapse chevron) whose body — the same
/// [_RuleFields] editor used in single-rule mode — only takes up space
/// while expanded. Keyed by the rule's id (see [_RulesSection]) so a
/// newly-added rule opens expanded while the others keep whatever
/// collapsed/expanded state the user left them in.
class _CollapsibleRuleCard extends StatefulWidget {
  final int index;
  final GameRuleFormDraft rule;
  final bool initiallyExpanded;
  const _CollapsibleRuleCard({super.key, required this.index, required this.rule, required this.initiallyExpanded});

  @override
  State<_CollapsibleRuleCard> createState() => _CollapsibleRuleCardState();
}

class _CollapsibleRuleCardState extends State<_CollapsibleRuleCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = widget.rule;
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: f.name,
                  onChanged: (v) => app.setGameForm((f) => f..rules[widget.index].name = v),
                  style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink),
                  decoration: appFieldDecoration(hintText: 'Nom de la règle', fillColor: AppColors.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
              ),
              IconButton(
                icon: AnimatedRotation(duration: const Duration(milliseconds: 150), turns: _expanded ? 0.5 : 0, child: Icon(Icons.expand_more_rounded, size: 22, color: AppColors.ink2)),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: _helper(ruleSummaryLine(f)),
            ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            _RuleFields(index: widget.index, rule: f),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: _RemoveLink('Supprimer cette règle', onTap: () => app.setGameForm((f) => f..rules.removeAt(widget.index))),
            ),
          ],
        ],
      ),
    );
  }
}

/// One rule's scoring settings — type de comptage, then whatever that type
/// needs (catégories de score, places nommées, limite de points), then the
/// coop / manches multiples switches. Shared by [_RulesSection]'s
/// single-rule layout and each [_CollapsibleRuleCard]'s expanded body.
class _RuleFields extends StatelessWidget {
  final int index;
  final GameRuleFormDraft rule;
  const _RuleFields({required this.index, required this.rule});

  void _setCoop(AppState app, bool v) => app.setGameForm((f) {
        final r = f.rules[index];
        r.coop = v;
        // A coop game has no ranking between players — see GameRule.coop.
        if (v && r.countType == CountType.ranks) r.countType = CountType.highWins;
        return f;
      });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final f = rule;
    final isPointGame = f.countType == CountType.highWins || f.countType == CountType.lowWins;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in CountType.values)
              // No ranking between players in a coop game (see AppState._ruleFromForm's matching guard).
              if (!(f.coop && t == CountType.ranks))
                OptionChip(label: _countLabel(t), selected: f.countType == t, onTap: () => app.setGameForm((f) => f..rules[index].countType = t)),
          ],
        ),
        const SizedBox(height: 8),
        _helper(_countHint(f.countType)),
        if (isPointGame) ...[
          const SizedBox(height: 22),
          _scoreFields(context, app),
        ],
        if (f.countType == CountType.ranks) ...[
          const SizedBox(height: 22),
          _namedPlaces(app),
        ] else if (isPointGame) ...[
          const SizedBox(height: 22),
          _fieldLabel('Limite de points (optionnel)'),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: f.pointLimit,
            keyboardType: TextInputType.number,
            onChanged: (v) => app.setGameForm((f) => f..rules[index].pointLimit = v),
            style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
            decoration: appFieldDecoration(hintText: 'Ex. 100'),
          ),
          const SizedBox(height: 6),
          _helper('La partie est signalée comme terminée dès qu’un joueur atteint ce score.'),
        ],
        // A time is one run per player: no shared outcome, no rounds.
        if (f.countType != CountType.time) ...[
          const SizedBox(height: 22),
          _FormCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  title: 'Partie coopérative',
                  subtitle: 'Tout le groupe joue ensemble contre le jeu.',
                  value: f.coop,
                  onChanged: (v) => _setCoop(app, v),
                ),
                Divider(height: 1, thickness: 1, color: AppColors.line),
                _SwitchRow(
                  title: 'Manches multiples',
                  subtitle: f.scoreFields.isNotEmpty ? 'Indisponible avec des catégories de score.' : 'Les scores se cumulent manche après manche.',
                  value: f.multiRound,
                  onChanged: f.scoreFields.isNotEmpty ? null : (v) => app.setGameForm((f) => f..rules[index].multiRound = v),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _scoreFields(BuildContext context, AppState app) {
    final fields = rule.scoreFields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _fieldLabel('Catégories de score')),
            _AddButton('Ajouter', onTap: () => app.setGameForm((f) => f
              ..rules[index].scoreFields.add(_newScoreField(f.rules[index].scoreFields.length))
              ..rules[index].multiRound = false)),
          ],
        ),
        if (fields.isEmpty)
          _helper('Optionnel — ex. merveilles, pièces, science… Le total est calculé pour vous.')
        else
          for (final (i, field) in fields.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Pressable(
                    onTap: () async {
                      final picked = await _pickScoreFieldColor(context, field.color);
                      if (picked == null) return;
                      if (!context.mounted) return;
                      app.setGameForm((f) => f..rules[index].scoreFields[i] = field.copyWith(color: picked));
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Color(field.color), shape: BoxShape.circle),
                      child: const Icon(Icons.palette_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(field.id),
                      initialValue: field.label,
                      onChanged: (v) => app.setGameForm((f) => f..rules[index].scoreFields[i] = field.copyWith(label: v)),
                      style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                      decoration: appFieldDecoration(hintText: 'Ex. Science', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), focusColor: Color(field.color)),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: AppColors.mut),
                    onPressed: () => app.setGameForm((f) => f..rules[index].scoreFields.removeAt(i)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _namedPlaces(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Places nommées (optionnel)'),
        const SizedBox(height: 4),
        _helper('Laissez vide pour un simple classement — les places non nommées restent neutres.'),
        const SizedBox(height: 14),
        _roleList(
          app,
          'top',
          'Depuis la 1ère place',
          rule.topRoles,
          labelFor: (i) => _ordinal(i + 1),
          hintFor: (i) => i == 0 ? 'Ex. Président' : 'Ex. Vice-président',
          onChange: (i, v) => app.setGameForm((f) => f..rules[index].topRoles[i] = v),
          onRemove: (i) => app.setGameForm((f) => f..rules[index].topRoles.removeAt(i)),
          onAdd: () => app.setGameForm((f) => f..rules[index].topRoles.add('')),
        ),
        const SizedBox(height: 14),
        _roleList(
          app,
          'bottom',
          'Depuis la dernière place',
          rule.bottomRoles,
          labelFor: (i) => i == 0 ? 'Dernière' : (i == 1 ? 'Avant-dernière' : '${_ordinal(i + 1)} avant la fin'),
          hintFor: (i) => i == 0 ? 'Ex. Trou du cul' : 'Ex. Vice-trou du cul',
          onChange: (i, v) => app.setGameForm((f) => f..rules[index].bottomRoles[i] = v),
          onRemove: (i) => app.setGameForm((f) => f..rules[index].bottomRoles.removeAt(i)),
          onAdd: () => app.setGameForm((f) => f..rules[index].bottomRoles.add('')),
        ),
      ],
    );
  }

  String _ordinal(int n) => n == 1 ? '1ère' : '${n}e';

  GameScoreField _newScoreField(int i) {
    final color = GameScoreField.palette[i % GameScoreField.palette.length];
    return GameScoreField(id: 'score_${DateTime.now().microsecondsSinceEpoch}_$i', label: '', color: color);
  }

  Widget _roleList(
    AppState app,
    String keyPrefix,
    String title,
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
        Text(title, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.mut)),
        const SizedBox(height: 8),
        for (final (i, role) in roles.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 92, child: Text(labelFor(i), style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2))),
                Expanded(
                  // Keyed on the list length so removing a row rebuilds the
                  // fields from the updated list rather than shifting stale text.
                  child: TextFormField(
                    key: ValueKey('${rule.id}-$keyPrefix-$i-${roles.length}'),
                    initialValue: role,
                    onChanged: (v) => onChange(i, v),
                    style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
                    decoration: appFieldDecoration(hintText: hintFor(i), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
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
        _AddButton('Ajouter une place', onTap: onAdd),
      ],
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
                        Pressable(
                          onTap: () => setState(() => selected = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
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
