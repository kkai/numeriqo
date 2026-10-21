# Numeriqo 3.1.1: submission runbook

**Staged 2026-10-21, both apps: 3.1.1 versions created, build 3111 attached,
not submitted.** Merged into `main` and pushed (`b63085c`). 3.1 (3102) went
live on both SKUs on 2026-10-21.

| App | 3.1.1 version id | Build 3111 id (= delivery id) |
|---|---|---|
| Numeriqo (6749287069, en-US) | `ed769351-990d-4223-8399-72dddc1cb9da` | `17fbfc0e-a5e9-4afe-9359-8cb7963f1a31` |
| Numeriqo Pro (6751394841, en-GB) | `80272489-d771-4a42-af25-564a4aed64c5` | `255d26a9-dda8-424d-911f-2a6302f37f11` |

A bug-fix release for the daily, both SKUs, iOS only. Version 3.1.1, build 3111.

## What changed and why

| # | Bug in 3.1 | Fix |
|---|---|---|
| 1 | The daily shared the one save slot. Opening today's puzzle and backing out silently replaced an unfinished game (the very thing `requestStart` guards against for Play). | The daily has its own slot, `numeriqo.saveDaily.v1`, dated. Opening the daily resumes that day's save; a save from another day is replaced. |
| 2 | A daily left unfinished came back under Continue the next day. Finishing it credited **today** (`DailyPuzzle.today`), extended the streak, and locked today's real daily as solved. | A daily carries its day (`GameSnapshot.dailyDay`, `NumeriqoGame.dailyDay`) and is credited to it. A daily started before midnight counts for its own day. |
| 3 | The streak showed the stored count, so after missed days Home said "5 days in a row. Keep it going." until the next solve reset it. Stats too. | `ProgressStore.displayStreak(today:)`, as in Kakuro, Hashi and Shikaku. |
| 4 | `recordDailyCompleted` reset the streak to 1 when a day older than the last one was recorded. Unreachable in 3.1, reachable once #2 records the game's own day. | `lastCompletedDay` only moves forward; an older day changes nothing. |
| 5 | "Play another" after the daily regenerated the **same** daily (same seed) and counted it again in the stats and the 6×6 Steady best time. | It starts a fresh 6×6 Steady, or, if a game is saved, becomes "Continue your game" and resumes it. |
| 6 | "New puzzle" after finishing a **resumed** game reloaded the old save, back to where it was when resumed. | `GameView.source` is state; the win banner swaps it for a fresh game at the same size and tier. |
| 7 | Home computed today once per render, so left open overnight it still showed yesterday's daily as solved. | Refreshed on `significantTimeChangeNotification` and on appear. |

**3.1 saves:** a 3.1 daily save sits in the main slot with `isDaily` and no
day. When it is resumed, `GameView.load` regenerates today's daily. If it is
the same board, the save moves to the daily slot dated today. If not, it plays
on as an ordinary 6×6 Steady with no streak credit.

The compilation (`../compilation`) builds Numeriqo from `games.lock` (`eb46484`)
and reads `progress.daily` directly, so it is unaffected until that line moves.

## How it was checked

2026-10-21, iPhone 16 Pro, iOS 18.5, run serially:
- Scheme Numeriqo: 81 unit tests (5 new: late older daily, missed-day
  display, dated daily slot, 3.1 save decoding, daily board) and 29 UI tests
  pass. New UI test `testTheDailyLeavesTheSavedGameAlone`: leave a 4×4
  unfinished, open the daily and back out, relaunch, finish the daily,
  "Continue your game" opens the 4×4.
- Scheme Numeriqo Pro: 9 tests pass.
- Engine harness under bare `swiftc`: 9,689 checks pass (no engine changes).
- Not checked: a real device, iPad, and the midnight rollover live.

## What is left

- [x] Merged into `main` and pushed.
- [x] 3.1.1 iOS versions created (MANUAL, copyright "Kai Kunze"). What's New
  from `STORE.md` (3.1.1 block) and read back. Review notes now open with a
  "New in 3.1.1" paragraph in place of the 3.1 one.
- [x] Build 3111, both SKUs: `.ipa` inspected (bundle ids, 3.1.1/3111,
  `ITSAppUsesNonExemptEncryption` false, no `.storekit`, debug or preview
  dylibs, privacy manifest present, no `-uiTestResetState`/kenken/kendoku in
  the binary), `--validate-app` clean, uploaded, `VALID`, attached.
- [x] Description, keywords and screenshots (5 iPhone + 5 iPad) carried over.
- [ ] Kai: submit each for review (web, or the reviewSubmissions API flow),
  then Release once approved.
- [ ] Device check: leave a game unfinished, open the daily, back out,
  Continue still there; finish a daily after midnight.
