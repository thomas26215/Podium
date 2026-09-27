import 'package:flutter_test/flutter_test.dart';
import 'package:podium/logic/personal_records.dart';
import 'package:podium/logic/time_format.dart';
import 'package:podium/models/game.dart';
import 'package:podium/models/match.dart';

void main() {
  group('time format', () {
    test('formats milliseconds as m:ss.mmm, with hours once needed', () {
      expect(formatDuration(112340), '1:52.340');
      expect(formatDuration(48120), '0:48.120');
      expect(formatDuration(3723000), '1:02:03.000');
      expect(formatDuration(5), '0:00.005');
    });

    test('reads the usual ways of typing a time', () {
      expect(parseDuration('1:52.340'), 112340);
      expect(parseDuration(' 1:52,34 '), 112340);
      expect(parseDuration('52.3'), 52300);
      expect(parseDuration('52'), 52000);
      expect(parseDuration('1:02:03'), 3723000);
      expect(parseDuration('1\'52"340'), 112340);
      expect(parseDuration(formatDuration(98765)), 98765);
    });

    test('rejects what isn\'t a positive time', () {
      for (final bad in ['', 'abc', '1:75', '0', '0:00.000', '1:2:3:4', '1.2.3', '-5']) {
        expect(parseDuration(bad), isNull, reason: bad);
      }
    });

    test('score labels follow the match unit', () {
      expect(scoreLabel(112340, 'time'), '1:52.340');
      expect(scoreLabel(12, 'points'), '12 pts');
    });

    test('a time rule is won by the lowest value and round-trips', () {
      const rule = GameRule(id: 'clm', name: 'Contre-la-montre', countType: CountType.time);
      expect(rule.lowWins, isTrue);
      expect(rule.isTime, isTrue);
      expect(rule.defaultUnit, 'time');
      expect(GameRule.fromMap(rule.toMap()).countType, CountType.time);
    });
  });

  group('personal records', () {
    const mk = Game(
      id: 'mk',
      name: 'Mario Kart',
      emoji: '🏎️',
      category: 'Jeu vidéo',
      rules: [
        GameRule(id: 'gp', name: 'Grand Prix', countType: CountType.highWins),
        GameRule(id: 'clm', name: 'Contre-la-montre', countType: CountType.time),
      ],
    );
    GameMatch run(String id, String ruleId, int points, int day, {String unit = 'time'}) => GameMatch(
          id: id,
          gameId: 'mk',
          groupId: 'solo',
          mode: 'ffa',
          unit: unit,
          lowWins: unit == 'time',
          entries: [MatchEntry(playerId: 'me', points: points)],
          timeline: const [],
          createdAt: DateTime(2026, 9, day),
          ruleId: ruleId,
        );

    test('keeps the fastest time per rule, the progression and the last improvement', () {
      final records = computePersonalRecords([
        run('a', 'clm', 115000, 1),
        run('b', 'clm', 113500, 2),
        run('c', 'clm', 112700, 3),
        run('d', 'gp', 40, 2, unit: 'points'),
        run('e', 'gp', 52, 1, unit: 'points'),
      ], (id) => id == 'mk' ? mk : null, 'me');

      expect(records, hasLength(2));
      final clm = records.first;
      expect(clm.rule.id, 'clm', reason: 'most recently played first');
      expect(clm.best, 112700);
      expect(clm.bestLabel, '1:52.700');
      expect(clm.played, 3);
      expect(clm.results, [115000, 113500, 112700]);
      expect(clm.lastImprovement, 800);

      final gp = records.last;
      expect(gp.best, 52);
      expect(gp.bestLabel, '52 pts');
      expect(gp.lastImprovement, isNull, reason: 'the last result wasn\'t the record');
    });

    test('flags each attempt that beat the record at the time, and its gap to today\'s best', () {
      final matches = [
        run('a', 'clm', 115000, 1),
        run('b', 'clm', 118000, 2),
        run('c', 'clm', 112340, 3),
        run('d', 'gp', 40, 1, unit: 'points'),
        run('e', 'gp', 52, 2, unit: 'points'),
      ];
      final attempts = computeSoloAttempts(matches, (_) => mk, 'me');
      expect(attempts['a']!.wasRecord, isTrue, reason: 'a first attempt is a record');
      expect(attempts['a']!.gapToBest, 2660);
      expect(attempts['b']!.wasRecord, isFalse);
      expect(attempts['b']!.gapToBest, 5660);
      expect(attempts['c']!.wasRecord, isTrue);
      expect(attempts['c']!.gapToBest, 0);
      expect(attempts['e']!.wasRecord, isTrue, reason: 'highest wins for points');
      expect(attempts['d']!.gapToBest, 12);
      expect(recordsBeaten(attempts.values), 2, reason: 'c and e — first attempts don\'t beat anything');
    });

    test('ignores other players and unknown games', () {
      final other = GameMatch(
        id: 'x',
        gameId: 'mk',
        groupId: 'solo',
        mode: 'ffa',
        unit: 'time',
        lowWins: true,
        entries: const [MatchEntry(playerId: 'someone', points: 1000)],
        timeline: const [],
        createdAt: DateTime(2026),
        ruleId: 'clm',
      );
      expect(computePersonalRecords([other], (_) => mk, 'me'), isEmpty);
      expect(computePersonalRecords([run('a', 'clm', 1000, 1)], (_) => null, 'me'), isEmpty);
    });
  });
}
