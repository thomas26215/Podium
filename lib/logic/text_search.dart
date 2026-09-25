/// Lower-cases and strips French accents so "ecole" finds "École" — the
/// folding every in-app search (games, themes, library) compares through.
String foldText(String s) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}
