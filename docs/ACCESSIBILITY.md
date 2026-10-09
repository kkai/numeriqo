# Accessibility — Numeriqo 3.1

Work on branch `3.1-a11y`, 2026-10-09. Tag `pre-3.1-a11y` marks `main` before
it (3.1 build 3101: swipe and daily fixes, never shipped); tag `v3.0` marks the
commit the live 3.0 (build 3001) was built from. Both SKUs, iOS only.

Unlike the Just Puzzles apps, Numeriqo was not starting from zero. 3.0 already
had per-screen `performAccessibilityAudit` tests in light and dark, a labelled
board with "Go to … in this cage" actions, semantic text styles everywhere off
the board, Reduce Motion, and announcements for the win, hints and cage jumps.
This pass closes what was left, using the pieces proven in Just Kakuro
(`../kakuro/docs/ACCESSIBILITY.md`).

## Findings

🔴 blocks a common task · 🟠 puts a feature claim at risk · 🟡 friction · 🟢 polish

| # | Sev | Finding | Status |
|---|---|---|---|
| 1 | 🔴 | Entering a digit with VoiceOver meant selecting the cell, leaving the board for the pad, finding the digit and coming back, for every entry. | **Fixed.** Each cell offers "Enter 1" … "Enter n" (or "Note n" in notes mode) and "Clear" as actions. They call the same game methods as the pad, so undo, note clean-up, the error check and haptics are unchanged. Lessons and the tutorial offer none, so a script cannot be bypassed. |
| 2 | 🟠 | Nothing said what had changed on the board: a placement, a completed cage, a completed row. Sighted players get these from the board and from the haptics. | **Fixed.** `BoardSpeech.boardChanged` names up to three placements (then counts), clears, and every cage, row and column a move completes. Notes are announced by the action that toggled them. |
| 3 | 🟠 | The cell label read position, contents and cage as one string, so a changed digit re-read the whole thing, and the label changed under anything that searched for it. | **Fixed.** Label is the position ("Row 3, column 2"); value is contents then cage ("7, incorrect, cage 12 plus, 3 cells"). |
| 4 | 🟠 | A hint's banner said "these cells" without naming them. | **Fixed.** `BoardSpeech.spokenHint` adds the focus cells (up to four) and, at the last rung, the placement. |
| 5 | 🟠 | Increase Contrast did nothing. At standard contrast the light accents run 3.0–6.2:1 (Sharp 2.99), clue ink 4.9:1. | **Fixed.** Every token that recedes on purpose has a high-contrast variant: accents and error at ≥ 7:1 on both `paper` and `surface` in light and dark, secondary and clue ink at 0.92 and 0.88 alpha, cell rules about twice as strong, cage rules solid. Cage lines go from 2 to 3 pt, dotted rules from 1 to 1.5 pt, the selection border from 2 to 3 pt. Paper, surface and ink are already at full strength and stay put. |
| 6 | 🟢 | No test covered the app at the largest text size. | **Added** `testHomeAtLargestTextSize`. It passes without filters: everything off the board already used semantic styles. |

### Accepted, with reasons

- **Board digits, clues and notes** are sized to their cells, as before 3.0's
  audit recorded (`testBoard`, `testHintBanner` keep their `XCTExpectFailure`).
  VoiceOver reads every cell in full, so nothing is lost to a player who
  cannot read the board.
- **The custom actions cannot be driven from XCUITest**, which has no public
  API for them. They are checked from the simulator's accessibility tree
  (`idb ui describe-all` lists `custom_actions` per cell), and the code they
  call is covered by the unit tests below.

### Strengths (kept)

- Cages are traversable directly ("Go to row 1, column 2 in this cage").
- Errors are spoken ("incorrect") and shown by colour and by the hint ladder,
  never by colour alone.
- Reduce Motion is honoured on Home, the board, the pad and the loading view.
- The audits run in light and in dark (`DarkAccessibilityAuditTests`).

## Tests

- `NumeriqoTests/AccessibilityTests.swift`:
  - `BoardSpeechTests`: positions, cell values with cages, "incorrect",
    spoken operations, placement, clear, row completion, counting, notes
    staying silent, and `clearNotes` as one undoable move.
  - `ContrastTests`: every meaningful colour ≥ 7:1 on `paper` and `surface` at
    high contrast in light and dark, and every receding token actually changes.
- `NumeriqoUITests/AccessibilityAuditTests.swift`: the existing per-screen
  audits plus `testBoardCellsSpeakPositionThenContents` and
  `testHomeAtLargestTextSize`, each in light and dark.

## Result

`xcodebuild test`, scheme Numeriqo, iPhone 16 Pro, iOS 18.5, 2026-10-09:
104 tests, 96 passed, 8 expected failures (the documented board-sizing and
stock-control findings, unchanged from the 87-test baseline on `pre-3.1-a11y`),
0 failures.

Simulator: a cell reads label "Row 1, column 1", value "empty, cage 3 divided
by, 2 cells", with the actions "Enter 1" … "Enter 4" beside the cage action.
With Increase Contrast on (simulator accessibility setting), clues, rules
and cage lines visibly strengthen; checked by screenshot in light. Dark at
high contrast is covered by `ContrastTests` and by the dark audit subclass:
the simulator's appearance switch did not reach the app in this session.

## Accessibility Nutrition Labels

Claimable for iPhone and iPad once 3.1 ships:
- VoiceOver
- Voice Control (cell actions under "Show actions")
- Larger Text (with the board exception above)
- Sufficient Contrast
- Dark Interface
- Differentiate Without Color Alone
- Reduced Motion

Captions and Audio Descriptions do not apply.
