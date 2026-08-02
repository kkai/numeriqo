# Monetization

**Decision: Numeriqo 3.0 is a major update to the existing app, monetized with a
single one-time unlock, modelled directly on Just Kakuro.**

Just Kakuro's `Kakuro/Store/` is a working, tested implementation of exactly
this. Port it rather than re-deriving it — including the comments, which record
mistakes already paid for once.

---

## 1. The product

One non-consumable. No subscription, no ads, no consumables.

| | |
|---|---|
| Product ID | `de.kaikunze.numeriqo.full` |
| Type | Non-consumable |
| Price | $4.99 (tier matching Just Kakuro) |
| Family shareable | **Yes** (Kakuro sets `familyShareable: true`) |
| Display name | Numeriqo Full |
| Description | "Every lesson, every drill, teaching hints, large grids and stats. One purchase, forever." |

Config file at `StoreKit/Numeriqo.storekit`, wired through the **shared** scheme's
`<StoreKitConfigurationFileReference>`. Keep it **outside** the synchronized
source root or it ships inside the app bundle — a mistake Kakuro's notes flag
explicitly.

## 2. The free / paid line

Chosen so that **the free tier exactly matches what today's free Numeriqo already
offers**: grids 3×3–5×5, all difficulties. No existing free user loses anything
in the upgrade, which is the constraint that matters most.

**Free**
- The interactive rules tutorial, in full.
- Technique lessons 1–3: Freebie Cage, Cage Combinations, Naked & Hidden Single.
- Grids **3×3 – 5×5**, every difficulty tier on them.
- The "something here is wrong" error hint — enough to feel what the hint engine
  would be doing for you.
- **Best times per grid size and difficulty.**

**Paid**
- The remaining technique lessons (Rule of N, parity, innies/outies, fish, …).
- All practice drills.
- Mastery **display** (tracking keeps running for free players — see §5).
- The full four-level hint ladder.
- Grids **6×6 – 9×9**.
- The full stats screen.

### Best times stay free — deliberately

Kakuro gates stats wholesale. Numeriqo **must not**, because today's free
Numeriqo already tracks best times per grid size via `BestTimesManager`, and
taking that away in an update is a straight regression for existing users. The
rule for this release is that **3.0 never removes something 2.x gave away.**

So the split within stats is:

| Free | Paid |
|---|---|
| Best time per (grid size, difficulty) | Solve counts and history |
| | Hints-taken trend — the number that proves the app works |
| | Mastery path across every technique |
| | Per-technique accuracy |

Legacy best-time records must migrate intact. The existing `BestTimesManager`
already runs a one-time migration moving pre-difficulty records into the medium
tier; that migration has to survive the rewrite, so **read the old
UserDefaults keys, do not reset them**. A test should assert that a 2.x defaults
plist loads with its records intact.

Difficulty is **never** gated. A free player can play Severe on a 5×5. Kakuro
makes the same call and it is right: gating difficulty punishes the players most
likely to buy.

## 3. Migrating Numeriqo Pro owners — the real problem

Today there are two paid-up-front SKUs:

| App | Bundle | ASC ID | Today |
|---|---|---|---|
| Numeriqo | `de.kaikunze.numeriqo` | 6749287069 | 3×3–5×5 |
| Numeriqo Pro | `de.kaikunze.numeriqopro` | 6751394841 | 3×3–9×9, paid app |

If Numeriqo 3.0 goes free-with-IAP, **people who already bought Numeriqo Pro
would have to pay again**. That is the fastest way to earn one-star reviews from
exactly the users who liked the app most.

### The fix: ship 3.0 to *both* apps, and keep the `NUMERIQO_PRO` flag as a permanent entitlement override

The codebase already has a `NUMERIQO_PRO` compilation flag. Reuse it as the
entitlement source:

```swift
static func isUnlockedByBuild() -> Bool {
    #if NUMERIQO_PRO
    true          // Pro was bought up front. It is unlocked, forever, for free.
    #else
    false
    #endif
}
```

`EntitlementStore.isUnlocked` returns `isUnlockedByBuild() || storeKitSaysOwned`.
The Pro build never shows a paywall and never talks to StoreKit for entitlement.

Why this beats the alternatives:

- **No keychain/App-Group migration dance.** The obvious approach — have Pro
  write a shared keychain flag that the standard app reads — requires the user to
  launch Pro once after updating, silently fails for anyone who deleted it, and
  adds a security surface. This approach requires nothing from the user at all.
- **Pro owners get the entire 3.0 teaching product for free**, in the app they
  already paid for. That is the correct outcome — they bought "the full
  Numeriqo," and 3.0 is what the full Numeriqo now is.
- **One codebase, one flag.** Shipping the Pro build is a second archive of the
  same source, which is already how the project works.

### Store lifecycle for Pro

1. Ship 3.0 to both SKUs **simultaneously**.
2. Then **remove Numeriqo Pro from sale**. Existing owners keep it, can
   re-download it, and keep receiving updates; it simply stops taking new
   customers.
3. Keep shipping Pro builds indefinitely. The marginal cost is one extra archive
   per release.

Do **not** delete the Pro app. Deleting it would strand paying customers.

### Release-note copy for the Pro build

Say this plainly, because silence here reads as a downgrade:

> Numeriqo 3.0 is a complete rebuild around teaching you the game — a full
> technique curriculum, hints that explain the reasoning instead of filling in
> the answer, and practice drills. **As a Pro owner you already have all of it.
> Nothing to buy, now or later.**

## 4. Architecture — port from Kakuro

Four files, same shape:

| File | Role |
|---|---|
| `Entitlement.swift` | `PaidFeature` enum (headline + pitch per feature) and `FeatureGate` — **every gating decision as pure `nonisolated` functions**, no StoreKit, exhaustively testable. |
| `EntitlementStore.swift` | `@Observable @MainActor`. StoreKit 2 behind the `EntitlementSource` protocol seam. Owns the `Transaction.updates` listener. |
| `PaywallPresenter.swift` | One sheet at the root, not five scattered through the tree. |
| `PaywallView.swift` | The sheet, plus `LockedFeatureView` for wholly-gated screens. |

### The invariants worth restating

These are load-bearing and each is a comment in Kakuro's source:

1. **`EntitlementSource.isOwned` returns `Bool?`. `nil` means "couldn't
   determine" and must never downgrade `isUnlocked`.** Offline or StoreKit-error
   must not take away what somebody bought.
2. **`Transaction.currentEntitlements` is authoritative**; the UserDefaults key
   (`numeriqo.entitlement.v1`) is a *display hint* so the first frame after a
   cold launch doesn't show locks to someone who paid. Yes, editing the plist
   unlocks the app — for a single $4.99 purchase with no server that is the
   right trade. Do not "fix" it by trusting the cache less on launch and more on
   error; the error path is what protects offline players.
3. **The `Transaction.updates` listener starts in `EntitlementStore.init`**, not
   in a view's `.task`. It must be live before any transaction can complete.
4. **Never hardcode the price.** Read `product.displayPrice`. App Review rejects
   a button that disagrees with the real localized price.
5. **All gating lives in `FeatureGate`**, with a test asserting the free set
   exactly — so a drifted gate fails a test instead of shipping.
6. **Gate the mastery *display*, not the tracker.** Keep recording for free
   players; showing an empty progress path to somebody who just paid would
   punish the purchase.
7. **Withholding a hint must not record a hint against mastery.** That would
   silently damage the player's progress path for a hint they never saw.
8. **Paywalled rows stay tappable** — they present the paywall. Only
   mastery-locked rows are `.disabled`. A dead row neither teaches nor sells.

## 5. Contextual paywall

`PaidFeature` carries a headline and a pitch so the sheet leads with whatever the
player just bumped into, rather than showing a generic list. Numeriqo's set:

| Case | Headline | Leads with |
|---|---|---|
| `advancedLessons` | The rest of the curriculum | Rule of N, parity, innies & outies, fish |
| `practiceDrills` | Practice drills | Per-technique drills with mastery tracking |
| `teachingHints` | Hints that teach | Names the technique and draws the argument |
| `largeGrids` | Large grids | 6×6 through 9×9, where the deep techniques matter |
| `stats` | Your progress | Best times, solve counts, mastery across every technique |

The best sales moment in this product is the one where a player has just felt a
hint teach them something and then hits the ceiling. Put the paywall exactly
there, and nowhere else.

## 6. Testing

- `EntitlementTests` asserts the free set **exactly** — every technique, every
  grid size, in and out.
- `PreviewEntitlementSource(owned:)` covers `true` / `false` / `nil`.
- A test asserting the `NUMERIQO_PRO` build reports unlocked without StoreKit.
- Simulator purchases via `StoreKit/Numeriqo.storekit`.
- The scheme's `<TestAction>` must not contain an empty `<TestPlans>` element —
  xcodebuild then reports "not configured for the test action."
