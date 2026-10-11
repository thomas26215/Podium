#!/bin/bash
# Replays and saves tonight's Skyjo from a fresh app start (the world after it: Léa leads, 69 matches).
set -e
bash ./to_round6.sh
python3 round.py 8 12 9 21; ./ui.py tap '^Valider la manche$'; sleep 1.5
adb shell input keyevent KEYCODE_BACK; sleep 1.2  # closes the keyboard, which covers the save button
./ui.py tap '^Enregistrer la partie$'; sleep 8
