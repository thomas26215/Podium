import 'package:flutter_test/flutter_test.dart';

import 'package:podium/widgets/banner_motifs.dart';

void main() {
  // The "Blocs" banner plays a scripted game; these check it plays it by
  // the rules: what a Tetris player watching would expect to see.
  final log = blocksGameLog();

  test('pieces are dealt from 7-piece bags', () {
    expect(log.map((p) => p.piece).join(), 'ILSOZJTSJTOZLII');
    for (final bag in [log.sublist(0, 7), log.sublist(7, 14)]) {
      expect(bag.map((p) => p.piece).toSet(), {'I', 'O', 'T', 'S', 'Z', 'J', 'L'});
    }
  });

  test('from an empty well, the first bag ends on a T-spin double', () {
    expect(log.take(6).every((p) => p.lines == 0), isTrue);
    final t = log[6];
    expect(t.piece, 'T');
    expect(t.tSpin, isTrue);
    expect(t.lines, 2);
    expect(t.allClear, isFalse);
  });

  test('then four lines are stacked, and a vertical I down the right-hand column clears them all', () {
    expect(log.sublist(7, 14).every((p) => p.lines == 0 && !p.tSpin), isTrue);
    final last = log.last;
    expect(last.piece, 'I');
    expect(last.cells.map((c) => c.$1).toSet(), {9}, reason: 'upright, in the rightmost column');
    expect(last.lines, 4);
    expect(last.allClear, isTrue);
  });

  test('the game and its all clear fit in one loop', () {
    expect(log.last.lockAt + 2.3, lessThan(blocksPeriod.inMilliseconds / 1000));
  });
}
