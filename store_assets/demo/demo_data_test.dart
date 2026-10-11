// Checks that the store demo's story holds (see demo_data.dart): Hugo leads
// the Elo before tonight's Skyjo and Léa after it, the pronostic makes her
// the outsider, and her win earns exactly one new badge, "Numéro 1".
// Not part of the app's suite — run it on its own:
//   flutter test store_assets/demo/demo_data_test.dart
// With DEMO_SEED_SEARCH=1 it also scans other seeds for kDemoSeed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/badges.dart';
import 'package:podium/logic/elo.dart';

import 'demo_data.dart';

/// What tonight's Skyjo does to Les Bandits, in [data].
class _Story {
  final DemoData data;
  final EloResult before, after;
  final List<double> chances;
  final List<String> freshBadges;
  final String? winsLeader;

  _Story._(this.data, this.before, this.after, this.chances, this.freshBadges, this.winsLeader);

  factory _Story.of(DemoData data, DateTime now) {
    final members = data.groups[kBandits]!.memberIds;
    final matches = data.groupMatches[kBandits]!;
    final after = [...matches, DemoData.tonightMatch(now)];
    final lea = data.users['lea']!;
    final stats = computeBadgeStats(
      uid: 'lea',
      matches: after,
      tournaments: data.groupTournaments[kBandits]!,
      leading: true,
      ownedGames: lea.ownedGameIds.length,
      friends: lea.friendIds.length,
    );
    final elo = computeElo(matches);
    return _Story._(
      data,
      elo,
      computeElo(after),
      eloWinChances(elo, [for (final uid in kTonightPlayers) [uid]], gameId: 'skyjo'),
      [for (final b in kBadges) if (b.isEarned(stats) && !lea.badges.contains(b.id)) b.id],
      DemoData.winsLeader(matches, members),
    );
  }

  double rating(String uid, {bool later = false}) => (later ? after : before).ratings[uid]!;
  double chance(String uid) => chances[kTonightPlayers.indexOf(uid)];
  String? leader({bool later = false}) {
    final r = later ? after : before;
    final ids = data.groups[kBandits]!.memberIds.where(r.ratings.containsKey).toList()..sort((a, b) => r.ratings[b]!.compareTo(r.ratings[a]!));
    return ids.firstOrNull;
  }

  bool get holds =>
      leader() == 'hugo' &&
      leader(later: true) == 'lea' &&
      chances.every((c) => c >= chance('lea')) &&
      chances.every((c) => c <= chance('hugo')) &&
      freshBadges.length == 1 &&
      freshBadges.first == 'leader';

  /// Hugo leads the wins too, and nobody else took the lead in the chat
  /// lately.
  bool get polished =>
      winsLeader == 'hugo' &&
      !data.groupMessages[kBandits]!.any((m) => m.system && m.text.contains('prend la tête') && !m.text.startsWith('Hugo'));

  String get summary {
    String table(EloResult r) {
      final ids = data.groups[kBandits]!.memberIds.where(r.ratings.containsKey).toList()..sort((a, b) => r.ratings[b]!.compareTo(r.ratings[a]!));
      return [for (final id in ids) '$id ${r.ratings[id]!.round()} (${eloTier(r.ratings[id]!).name}, ${r.played[id]} parties)'].join(', ');
    }

    final tonight = after.deltas['tonight']!;
    final matches = data.groupMatches[kBandits]!;
    return '''
${matches.length} parties chez les Bandits (${matches.where((m) => m.gameId == 'skyjo').length} Skyjo, ${matches.where((m) => m.tournamentId != null).length} de tournoi), meneur aux victoires : $winsLeader
Avant ce soir : ${table(before)}
Pronostic Skyjo : ${[for (final uid in kTonightPlayers) '$uid ${(chance(uid) * 100).round()} %'].join(', ')}
Ce soir : ${[for (final uid in kTonightPlayers) '$uid ${tonight[uid]!.round()}'].join(', ')}
Après : ${table(after)}
Badges de Léa : ${data.users['lea']!.badges.join(', ')} ; nouveaux ce soir : $freshBadges
Discussion : ${data.groupMessages[kBandits]!.map((m) => m.text).join(' | ')}''';
  }
}

void main() {
  final now = DateTime(2026, 10, 7, 20, 40);

  test('the demo story holds', () {
    final story = _Story.of(DemoData.build(now), now);
    // ignore: avoid_print
    print(story.summary);
    expect(story.leader(), 'hugo');
    expect(story.leader(later: true), 'lea');
    expect(story.chances.every((c) => c >= story.chance('lea')), isTrue, reason: 'Léa is the outsider');
    expect(story.chances.every((c) => c <= story.chance('hugo')), isTrue, reason: 'Hugo is the favourite');
    expect(story.freshBadges, ['leader']);
  });

  test('seed search', () {
    final passes = List.filled(6, 0);
    final fresh = <String, int>{};
    for (var seed = 1; seed <= 20000; seed++) {
      final story = _Story.of(DemoData.build(now, seed: seed), now);
      final checks = [
        story.leader() == 'hugo',
        story.leader(later: true) == 'lea',
        story.chances.every((c) => c >= story.chance('lea')),
        story.chances.every((c) => c <= story.chance('hugo')),
        story.freshBadges.length == 1 && story.freshBadges.first == 'leader',
        story.leader() == 'hugo' && story.leader(later: true) == 'lea',
      ];
      for (var i = 0; i < checks.length; i++) {
        if (checks[i]) passes[i]++;
      }
      final key = story.freshBadges.join(',');
      fresh[key] = (fresh[key] ?? 0) + 1;
      if (seed == 20000) {
        // ignore: avoid_print
        print('passes $passes, fresh $fresh');
      }
      if (!story.holds) continue;
      final gap = story.rating('hugo') - story.rating('lea');
      if (!story.polished) continue;
      // ignore: avoid_print
      print('seed $seed${story.polished ? ' ★' : ''} [victoires: ${story.winsLeader}] — Léa ${story.rating('lea').round()} → ${story.rating('lea', later: true).round()}, '
          'Hugo ${story.rating('hugo').round()} → ${story.rating('hugo', later: true).round()}, écart ${gap.round()}, '
          'Léa ${(story.chance('lea') * 100).round()} %, Hugo ${(story.chance('hugo') * 100).round()} % | '
          '${story.data.groupMessages[kBandits]!.where((m) => m.system).map((m) => m.text).join(' / ')}');
    }
  }, skip: Platform.environment['DEMO_SEED_SEARCH'] == null);
}
