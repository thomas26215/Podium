import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../models/scheduled_event.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/match_card.dart' show frenchDayMonth, hhmm;
import 'scheduled_event_detail_screen.dart';
import 'scheduled_event_form_screen.dart';

/// Every scheduled event in the currently-viewed Salon, soonest first —
/// reached from the "Tout voir" link on the home screen's "Évènements à
/// venir" section (Salon-only, see `AppState.viewEvents`).
class ScheduledEventsListScreen extends StatelessWidget {
  const ScheduledEventsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final events = List<ScheduledEvent>.of(app.viewEvents)
      ..sort((a, b) {
        if (a.isStarted != b.isStarted) return a.isStarted ? 1 : -1;
        return a.scheduledAt.compareTo(b.scheduledAt);
      });
    final server = app.currentSalonServer;
    final canManage = server != null && app.canManageEvents(server);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Évènements', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      floatingActionButton: (canManage && !app.activeContextClosed)
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScheduledEventFormScreen())),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: events.isEmpty
          ? Center(
              child: EmptyState(
                emoji: '📅',
                message: canManage
                    ? "Aucun évènement planifié. Créez-en un avec le bouton +."
                    : "Aucun évènement planifié pour l'instant.",
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = events[i];
                return FadeSlideIn(
                  delay: Duration(milliseconds: i * 40),
                  child: _EventRow(
                    event: e,
                    game: app.gameById(e.gameId),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScheduledEventDetailScreen(eventId: e.id))),
                  ),
                );
              },
            ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final ScheduledEvent event;
  final Game? game;
  final VoidCallback onTap;
  const _EventRow({required this.event, required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final capacityLabel = event.capacity == null ? '${event.signups.length} inscrits' : '${event.confirmedIds.length}/${event.capacity} inscrits';
    final waitlistLabel = event.waitlistIds.isNotEmpty ? ' · ${event.waitlistIds.length} en attente' : '';
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(game?.emoji ?? '📅', style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(
                    '${frenchDayMonth(event.scheduledAt)} à ${hhmm(event.scheduledAt)} · $capacityLabel$waitlistLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: event.isStarted ? AppColors.accentSoft : AppColors.bg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                event.isStarted ? 'Lancé' : (event.kind == 'tournament' ? 'Tournoi' : 'Partie'),
                style: bodyFont(size: 10.5, weight: FontWeight.w800, color: event.isStarted ? AppColors.accent : AppColors.mut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
