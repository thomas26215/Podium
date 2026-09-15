import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth, hhmm;

/// Admin-only form (see `AppState.canManageEvents`) to schedule a new game
/// or tournament ahead of time in the current Salon — reached from the "+"
/// on `ScheduledEventsListScreen`. Picks from the Salon's existing catalog
/// only (no "create a new game" shortcut here, unlike the plain new-game
/// wizard) since the point is scheduling something already known, not
/// building the catalog.
class ScheduledEventFormScreen extends StatefulWidget {
  const ScheduledEventFormScreen({super.key});

  @override
  State<ScheduledEventFormScreen> createState() => _ScheduledEventFormScreenState();
}

class _ScheduledEventFormScreenState extends State<ScheduledEventFormScreen> {
  String? _gameId;
  String _kind = 'game';
  final _nameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 14, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _submit(AppState app) async {
    final gameId = _gameId;
    final server = app.currentSalonServer;
    final salonId = app.currentSalonId;
    if (gameId == null || server == null || salonId == null) return;
    setState(() => _saving = true);
    final capacity = int.tryParse(_capacityCtrl.text.trim());
    final saved = await app.createScheduledEvent(
      serverId: server.id,
      salonId: salonId,
      gameId: gameId,
      kind: _kind,
      name: _nameCtrl.text,
      scheduledAt: _scheduledAt,
      capacity: capacity,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final games = app.games;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Planifier un évènement', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _label('Jeu'),
          const SizedBox(height: 9),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final g in games)
                Pressable(
                  onTap: () => setState(() => _gameId = g.id),
                  child: _GameTile(game: g, selected: _gameId == g.id),
                ),
            ],
          ),
          if (games.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Aucun jeu dans ce salon pour l\'instant.', style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut)),
            ),
          const SizedBox(height: 22),
          _label('Type'),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _KindCard(label: 'Partie', selected: _kind == 'game', onTap: () => setState(() => _kind = 'game'))),
              const SizedBox(width: 10),
              Expanded(child: _KindCard(label: 'Tournoi', selected: _kind == 'tournament', onTap: () => setState(() => _kind = 'tournament'))),
            ],
          ),
          const SizedBox(height: 22),
          _label('Nom (optionnel)'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _nameCtrl,
            style: bodyFont(size: 15, weight: FontWeight.w700, color: AppColors.ink),
            decoration: appFieldDecoration(hintText: _gameId != null ? app.gameById(_gameId!)?.name : 'Ex. Tournoi TCG du samedi'),
          ),
          const SizedBox(height: 22),
          _label('Date et heure'),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      helpText: 'Quand ?',
                      cancelText: 'Annuler',
                      confirmText: 'Choisir',
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: _PickerField(icon: Icons.calendar_month_rounded, label: frenchDayMonth(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time, helpText: 'À quelle heure ?');
                    if (picked != null) setState(() => _time = picked);
                  },
                  child: _PickerField(icon: Icons.access_time_rounded, label: hhmm(_scheduledAt)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _label('Nombre de places (optionnel)'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _capacityCtrl,
            keyboardType: TextInputType.number,
            style: bodyFont(size: 16, weight: FontWeight.w700, color: AppColors.ink),
            decoration: appFieldDecoration(hintText: 'Illimité'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Au-delà de cette limite, les inscriptions suivantes rejoignent une liste d\'attente et prennent la place automatiquement en cas de désistement.',
              style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Planifier', onPressed: _gameId == null ? null : () => _submit(app), loading: _saving),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(s, style: bodyFont(size: 12.5, weight: FontWeight.w800, color: AppColors.ink2));
}

class _GameTile extends StatelessWidget {
  final Game game;
  final bool selected;
  const _GameTile({required this.game, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : AppColors.card,
        border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Text(game.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _KindCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          border: Border.all(color: selected ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(label, style: bodyFont(size: 14, weight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PickerField({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
        ],
      ),
    );
  }
}
