#!/bin/bash
# Replays tonight's Skyjo up to round 6 (empty), from a fresh app start.
set -e
adb shell am force-stop app.podium.games; adb shell am start -n app.podium.games/.MainActivity >/dev/null; sleep 6
./ui.py tap '^Discussion$'; sleep 2
./ui.py tap 'Lancer cette partie' 0; sleep 2
for p in Léa Hugo Inès Malik; do ./ui.py tap "^$p\$"; sleep 0.6; done
./ui.py swipe 540 1900 540 500 400; sleep 0.5; ./ui.py swipe 540 1900 540 500 400; sleep 1.5
./ui.py tap '^Continuer$'; sleep 2
./ui.py tap '^Par manche$'; sleep 1.5
for r in "12 5 18 9" "8 14 21 17" "0 11 7 24" "15 9 12 13" "6 22 15 19"; do python3 round.py $r; ./ui.py tap '^Valider la manche$'; sleep 1.2; done
