# Numeriqo 3.1: submission runbook

**Submitted for review 2026-10-09 ~20:08 UTC, both apps (`WAITING_FOR_REVIEW`).**
Next: Release each once approved (manual release).

Earlier the same day: **ready to submit, both apps, not submitted.** Each 3.1 iOS
version has build 3102 attached and sits in its own draft review submission,
so App Store Connect has already run its completeness check: version and
submission are both `READY_FOR_REVIEW`. What is left is pressing Submit, and
later Release (§1).

## Record facts

| App | ASC id | Locale | 3.1 version id | Build 3102 id (= delivery id) | Draft review submission |
|---|---|---|---|---|---|
| Numeriqo (`de.kaikunze.numeriqo`) | 6749287069 | en-US | `e29c8231-f3b2-477c-b2ca-8dddc0b42155` | `7e32abdd-d90c-471c-a897-859ad983f1d2` | `3d75c87b-8121-42fb-b7a8-ddeae388a1a8` |
| Numeriqo Pro (`de.kaikunze.numeriqopro`) | 6751394841 | en-GB | `5c5fdbea-2c2c-4466-ad9d-04bdefcc7ad1` | `f01253c0-88cd-42e9-9ceb-55a899927bef` | `dc7054b7-2a8d-4ec0-9f37-e8096ead1f1c` |

- Release type **MANUAL**, as 3.0 was: after approval each version waits for
  Release.
- The free app's IAP *Numeriqo Full* is `APPROVED`; nothing rides along.
- Pro's macOS and visionOS 1.0 stay as they are (3.0 dropped those platforms).
- Tags: `v3.0` = the commit build 3001 was built from (`6213419`);
  `pre-3.1-a11y` = `main` before this work. Branch `3.1-a11y`, not merged.

## 1. What is left

Kai, per app:
- [x] **Submitted** 2026-10-09 by API (`submitted: true` on both drafts). Was: **Submit.** App Store Connect → the app → 3.1 → the draft submission →
  Submit for Review. Or by API:
  `asc.py PATCH reviewSubmissions/<id> '{"data":{"type":"reviewSubmissions","id":"<id>","attributes":{"submitted":true}}}'`
- [ ] **Release** each once approved (manual release).
- [ ] Optional: Accessibility Nutrition Labels from `docs/ACCESSIBILITY.md`
  (iPhone and iPad).
- [ ] Still open from `SHIPPING.md` §6: the Calcudoku/MathDoku clearance search
  and a test on a real device from a Release build.

Done by API on 2026-10-09, all read back:
- [x] 3.1 iOS versions created (copyright "Kai Kunze", `MANUAL`)
- [x] What's New on both from `STORE.md` (3.1 block, no em dashes)
- [x] Review notes on both start with a "New in 3.1" paragraph (cell actions,
  announcements, Increase Contrast)
- [x] Keywords, description, promo text, support URL and screenshots
  (5 iPhone + 5 iPad each) carried over from 3.0. Keywords read back free of
  "kenken"/"kendoku". Nothing visible changes at standard contrast, so the
  screenshots stand.
- [x] Builds 3.1 (3102), both SKUs: `.ipa` inspected (bundle ids, version,
  `ITSAppUsesNonExemptEncryption` false, no `.storekit`, no debug or preview
  dylibs, privacy manifest present, no `-uiTestResetState` and no
  "kenken"/"kendoku" in the binary), `--validate-app` clean, uploaded,
  `VALID`, attached
- [x] Draft review submission per app with the version as its item: Apple's
  readiness gate passed on both

## 2. How this was checked

- Scheme Numeriqo, iPhone 16 Pro, iOS 18.5: 104 tests, 0 failures, 8 expected
  failures unchanged from the 87-test baseline at `pre-3.1-a11y`.
- Scheme Numeriqo Pro: its 9 tests pass.
- Engine harness under bare `swiftc`: 9,689 checks pass (no engine changes).
- Simulator: the cells' accessibility tree shows the new label/value split and
  the "Enter n" actions; Increase Contrast checked by screenshot (light).
  Details in `docs/ACCESSIBILITY.md`.
