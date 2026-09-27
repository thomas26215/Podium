/// Formatting and parsing for [CountType.time] scores, stored everywhere as
/// a plain number of milliseconds in `MatchEntry.points` — so sorting,
/// winners (lowest wins) and storage need nothing special, only what's
/// shown to and typed by the player does.
library;

/// "1:52.340" — minutes:seconds.milliseconds, with hours in front once a
/// run gets that long ("1:02:03.000"). Always shows the minutes, so every
/// time in a list lines up the same way ("0:48.120", not "48.120").
String formatDuration(int ms) {
  final negative = ms < 0;
  var rest = ms.abs();
  final millis = rest % 1000;
  rest ~/= 1000;
  final seconds = rest % 60;
  rest ~/= 60;
  final minutes = rest % 60;
  final hours = rest ~/ 60;
  final s = '${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  final body = hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}:$s' : '$minutes:$s';
  return negative ? '-$body' : body;
}

/// A match score as shown to players: a formatted time for a `'time'` unit
/// (see `GameMatch.unit`), otherwise "12 pts".
String scoreLabel(int points, String unit) => unit == 'time' ? formatDuration(points) : '$points pts';

/// Reads what a player types for a time: "1:52.340", "1:52,34", "52.3",
/// "1:02:03" or "1'52\"340" (Mario Kart's own notation) — a comma works as
/// the decimal separator, and a fraction shorter than 3 digits is read as
/// tenths/hundredths ("1:52.34" = 1:52.340). Null when it isn't a time, or
/// isn't strictly positive.
int? parseDuration(String input) {
  var s = input.trim().replaceAll(',', '.').replaceAll(' ', '');
  // Mario Kart style: 1'52"340 → 1:52.340
  final mk = RegExp(r"""^(\d+)'(\d{1,2})"(\d{1,3})$""").firstMatch(s);
  if (mk != null) s = '${mk[1]}:${mk[2]}.${mk[3]}';
  final m = RegExp(r'^(?:(\d+):)?(?:(\d+):)?(\d+)(?:\.(\d{1,3}))?$').firstMatch(s);
  if (m == null) return null;
  // With a single colon the first group holds the minutes; with two, it's
  // hours then minutes.
  final int hours, minutes;
  if (m[2] != null) {
    hours = int.parse(m[1]!);
    minutes = int.parse(m[2]!);
  } else {
    hours = 0;
    minutes = m[1] != null ? int.parse(m[1]!) : 0;
  }
  final seconds = int.parse(m[3]!);
  // Once minutes are given, seconds (and minutes under hours) must stay
  // below 60 — "1:75" is a typo, not 2:15.
  if ((m[1] != null && seconds >= 60) || (m[2] != null && minutes >= 60)) return null;
  final millis = m[4] == null ? 0 : int.parse(m[4]!.padRight(3, '0'));
  final total = ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
  return total > 0 ? total : null;
}
