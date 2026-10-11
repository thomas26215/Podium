# Recapturing the store screenshots

Drives the demo app (`../demo/main_store.dart`, release build) on the `podium_store` AVD over adb.

- `./ui.py ls` lists the screen's labelled nodes; `./ui.py tap REGEX [n]` taps one; `./ui.py shot NAME` saves `new/NAME.png`;
  `./ui.py cmp NAME` puts it next to `../raw/NAME.png`.
- `python3 offset.py NAME [range] [top]`: how many px `new/NAME.png` is scrolled against `../raw/NAME.png` (0 = crops still fit;
  else shift the compose `--y` by it). `top` skips a fixed header.
- `bash play_skyjo.sh` replays tonight's Skyjo from a fresh start (`to_round6.sh` stops at round 6, for the scoring shots).

Pitfalls: run loops in bash (zsh doesn't split `$r`); the keyboard covers "Enregistrer la partie" (close it with BACK);
BACK on the app's root screen destroys the in-memory demo world; slow swipes (≥1500 ms) scroll exactly, short ones (<50 px) don't.
Chloé's live views need `--dart-define=DEMO_AS=chloe`. Status bar: SystemUI demo mode, 9:41, wifi `fully true`, mobile hidden.
