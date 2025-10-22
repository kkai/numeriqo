# Repository Guidelines

## Project Structure & Module Organization
Numeriqo is an Xcode project focused on the SwiftUI app target `Numeriqo`. Source sits in `Numeriqo/` with app entry (`NumeriqoApp.swift`), core gameplay logic (`KenKenGame.swift`), primary UI (`ContentView.swift`, `KenKenGameView.swift`), and best-time storage. Shared assets live in `Numeriqo/Assets.xcassets`. Product marketing copy is stored under `appstore/`, release narratives in `plans/`, and reference imagery in `screenshots/`. Update these alongside feature work to keep storefront collateral current.

## Build, Test, and Development Commands
Run a debug build locally with `xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -configuration Debug build`. Use the same command with `-configuration Release` before cutting TestFlight or App Store builds. For platform validation, swap in a destination flag such as `-destination 'platform=iOS Simulator,name=iPhone 15 Pro'`. Tests are driven through the app scheme: `xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=macOS'`.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: camelCase for methods and properties, PascalCase for types. Maintain four-space indentation as seen in `KenKenGame.swift`. Keep view structs small and compose state using `ObservableObject` like `MathMazeGame`. Co-locate helper extensions beside the types they support, and prefer descriptive names for cages, operations, and grid helpers.

## Testing Guidelines
Add new XCTest cases under a `NumeriqoTests` target (create if missing) to cover puzzle validation, timer accuracy, and platform-specific UI logic. Name test files after the class under test, e.g. `MathMazeGameTests.swift`. Keep unit tests deterministic by seeding any random puzzle generation. Run the full suite with `xcodebuild test ...` for every pull request, and capture failures in PR notes.

## Commit & Pull Request Guidelines
Write concise, present-tense commit messages (`fix win condition`) that describe the behavior change. Squash noisy WIP commits before merging. Pull requests should include: a short summary, before/after screenshots for UI tweaks, mentions of impacted assets (`appstore/`, `screenshots/`), and links to related issues or plans. Flag any migrations or data resets in bold within the PR body.

## Assets & Release Collateral
When updating gameplay visuals, refresh `screenshots/` and note the simulator or device used. Any copy edits must be mirrored in `appstore/*.txt`. Keep localized or platform-specific assets grouped in subdirectories. Document significant release decisions in `plans/` so future agents can trace rationale.
