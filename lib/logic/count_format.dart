/// "845", "1,2 k", "12 k", "3,4 M" — a count as shown on a library game,
/// shortened past a thousand. Rounded down, so it never reads as more than
/// it is: 1 999 is "1,9 k".
String compactCount(int n) {
  if (n < 1000) return '$n';
  String short(int value, int unit, String suffix) {
    final tenths = value * 10 ~/ unit;
    final whole = tenths ~/ 10;
    // One decimal below 10 only: "1,2 k", then "12 k".
    final body = whole >= 10 || tenths % 10 == 0 ? '$whole' : '$whole,${tenths % 10}';
    return '$body $suffix';
  }

  return n < 1000000 ? short(n, 1000, 'k') : short(n, 1000000, 'M');
}
