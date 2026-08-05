# Podium

A Flutter + Firebase app for tracking game scores with friends long-term:
permanent rankings (wins, cumulative points, win ratio, per-game average),
groups with subgroups, team matches (2–4 teams), and quick or live
(point-by-point, timestamped) score entry.

Ported from the `Podium.dc.html` interactive prototype in the repo root —
see `../README.md` and `../chats/chat1.md` for the original design intent.

## Stack

- Flutter (Dart), Provider for state management
- Firebase Auth (email/password) + Cloud Firestore for data & sync
- `google_fonts` (Space Grotesk + Manrope) for the type system

## Project layout

```
lib/
  models/        Plain data classes (AppUser, Game, Group, GameMatch...)
  repositories/   Auth/Groups/Games/Matches/Users — Firebase-backed, plus
                  in-memory Fake* implementations used by widget tests and
                  the local preview (no Firebase project needed)
  state/          AppState: the ranking math, group-hierarchy aggregation,
                  and new-game-sheet flow, ported from the prototype's JS
  screens/        One folder per tab + auth + the new-game sheet
  widgets/        Shared pieces (Avatar, PodiumWidget, MatchCard, ...)
  theme/          Color tokens & fonts lifted from the prototype's CSS
firestore.rules   Security rules for the data model below
```

## Connect your own Firebase project

This repo ships with a placeholder `lib/firebase_options.dart` — the app
detects that and shows a "connect Firebase" screen instead of crashing.
To go live:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Authentication → Email/Password** and **Firestore Database**.
3. From this directory:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This overwrites `lib/firebase_options.dart` with your real project config.
4. Deploy the security rules: `firebase deploy --only firestore:rules`
   (after `firebase init firestore` / `firebase use <your-project>`).
5. `flutter run`

## Data model (Firestore)

- `users/{uid}` — account profile (email, display name, avatar color)
- `emailIndex/{email}` — `{uid}` lookup so "invite a friend by email" works
  without exposing the whole users collection
- `groups/{groupId}` — a root community (`parentId == null`) or a subgroup
  (`parentId` = the root's id). Subgroups only store the *additional*
  players they bring in; the parent's roster layers underneath. Root
  groups also carry `allMemberIds`, the union of the whole tree's members,
  used by the security rules and by "who can see this group" checks.
- `groups/{rootId}/games/{gameId}` — the game catalog, shared by a root and
  all its subgroups (seeded with a default catalog when a group is created)
- `groups/{rootId}/matches/{matchId}` — recorded matches; each match's own
  `groupId` field says which root/subgroup it was actually played in

## Local preview without Firebase

`lib/main_preview.dart` boots the real UI against seeded in-memory data
(the prototype's original demo group/players/matches) instead of Firebase —
useful for looking at every screen before you've connected a project:

```
flutter run -d chrome -t lib/main_preview.dart
```

## Tests

```
flutter test
```

Widget tests in `test/widget_test.dart` exercise the real screens against
the `Fake*` repositories (sign-in, home/ranking/groups tabs, the new-game
sheet) so the app's logic is verified without needing live Firebase.
