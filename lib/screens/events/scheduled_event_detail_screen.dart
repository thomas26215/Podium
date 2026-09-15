import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth, hhmm;
import '../new_game/new_game_sheet.dart';

/// Full view of one scheduled event: date/time, sign-up list (with a
/// waitlist section once the confirmed slots are full — see
/// `ScheduledEvent.confirmedIds`/`waitlistIds`), a "S'inscrire"/"Se
/// désinscrire" toggle open to any Salon member, and "Lancer"/"Supprimer"
/// for admins (see `AppState.canManageEvents`). Looks the event up live by
/// id so it stays current as sign-ups come in from other devices.
class ScheduledEventDetailScreen extends StatelessWidget {
  final String eventId;
  const ScheduledEventDetailScreen({super.key, required this.eventId});

  Future<void> _confirmDelete(BuildContext context, AppState app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Supprimer cet évènement ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text(
          'Cette action est définitive — les inscriptions seront perdues. La partie ou le tournoi déjà lancé(e) depuis cet évènement, s\'il y en a un, n\'est pas affecté(e).',
          style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('Supprimer', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (confirmed != true) return;
    final event = app.events.where((e) => e.id == eventId).firstOrNull;
    if (event == null) return;
    final ok = await app.deleteScheduledEvent(event);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.flowError ?? "Échec de la suppression — vérifiez votre connexion et réessayez.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final event = app.events.where((e) => e.id == eventId).firstOrNull;

    if (event == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, foregroundColor: AppColors.ink),
        body: Center(child: EmptyState(emoji: '📅', message: "Cet évènement n'existe plus.")),
      );
    }

    final game = app.gameById(event.gameId);
    final server = app.currentSalonServer;
    final canManage = server != null && app.canManageEvents(server);
    final uid = app.currentUser?.uid;
    final isSignedUp = uid != null && event.signups.contains(uid);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(event.name, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          if (canManage) IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _confirmDelete(context, app)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
                child: Text(game?.emoji ?? '📅', style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game?.name ?? 'Jeu inconnu', style: dispFont(size: 19, weight: FontWeight.w800, color: AppColors.ink)),
                    Text(
                      '${event.kind == 'tournament' ? 'Tournoi' : 'Partie'} · ${frenchDayMonth(event.scheduledAt)} à ${hhmm(event.scheduledAt)}',
                      style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (canManage && !event.isStarted)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PrimaryButton(
                label: 'Lancer',
                onPressed: () {
                  app.startEvent(event);
                  showNewGameSheet(context, app);
                },
              ),
            ),
          if (event.isStarted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Cet évènement a déjà été lancé.', style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink))),
                ],
              ),
            )
          else if (uid != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => isSignedUp ? app.unregisterFromEvent(event) : app.registerForEvent(event),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isSignedUp ? AppColors.accent : AppColors.ink,
                  side: BorderSide(color: isSignedUp ? AppColors.accent : AppColors.line, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: Text(
                  isSignedUp ? 'Se désinscrire' : (event.isFull ? 'Rejoindre la liste d\'attente' : 'S\'inscrire'),
                  style: bodyFont(size: 14, weight: FontWeight.w700, color: isSignedUp ? AppColors.accent : AppColors.ink),
                ),
              ),
            ),
          const SizedBox(height: 22),
          SectionHeader(
            title: event.capacity == null
                ? 'Inscrits (${event.confirmedIds.length})'
                : 'Inscrits (${event.confirmedIds.length}/${event.capacity})',
          ),
          if (event.confirmedIds.isEmpty)
            EmptyState(emoji: '🧍', message: 'Personne ne s\'est encore inscrit.')
          else
            for (final id in event.confirmedIds)
              Builder(builder: (_) {
                final p = app.playerById(id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 36, fontSize: 14),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p?.displayName ?? 'Joueur', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                      if (id == uid) Text('Toi', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.green)),
                    ],
                  ),
                );
              }),
          if (event.waitlistIds.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionHeader(title: 'Liste d\'attente (${event.waitlistIds.length})'),
            for (final (i, id) in event.waitlistIds.indexed)
              Builder(builder: (_) {
                final p = app.playerById(id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.line), shape: BoxShape.circle),
                        child: Text('${i + 1}', style: bodyFont(size: 11, weight: FontWeight.w800, color: AppColors.mut)),
                      ),
                      const SizedBox(width: 10),
                      Avatar(initial: p?.initial ?? '?', color: p != null ? Color(p.color) : AppColors.mut, size: 32, fontSize: 13),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p?.displayName ?? 'Joueur', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
                      if (id == uid) Text('Toi', style: bodyFont(size: 12, weight: FontWeight.w700, color: AppColors.mut)),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
