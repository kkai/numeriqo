# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift/SwiftUI iOS/macOS application called "Numeriqo" - a MathMaze puzzle game supporting iPhone, iPad, Mac, and Apple Vision Pro. The app allows users to play MathMaze puzzles of varying difficulty levels (3x3 to 9x9 grids) with dynamically generated cages and mathematical operations.

## Development Commands

### Building
```bash
# Build the project (Debug configuration)
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -configuration Debug build

# Build for release
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -configuration Release build

# Build and run in simulator
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for macOS
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=macOS' build
```

### Testing
```bash
# Run tests
xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run tests on macOS
xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=macOS'
```

### Running
Open the project in Xcode and use Cmd+R to run, or use xcodebuild with appropriate destination parameters.

## Architecture

### Core Components
- **App Entry Point**: `NumeriqoApp.swift` - Main app struct with WindowGroup scene
- **Main View**: `ContentView.swift` - Navigation between size selection and game play, manages game state
- **Game Logic**: `KenKenGame.swift` - Core game logic, puzzle generation, validation, and Latin square generation
- **Game UI**: `KenKenGameView.swift` - Game interface with grid, cage backgrounds, number picker, and controls

### Key Data Structures
- **MathMazeGame**: ObservableObject managing game state, grid, cages, and validation
- **Cage**: Represents a group of cells with mathematical operation and target value
- **Position**: Row/column coordinate structure for grid positions
- **Operation**: Enum for mathematical operations (add, subtract, multiply, divide, none)

### Game Flow
1. Size selection screen (3x3, 4x4, 5x5, 6x6, 7x7, 8x8, 9x9)
2. Dynamic puzzle generation with Latin square solution
3. Cage generation with adjacent cells and random operations
4. Interactive gameplay with number picker and validation
5. Win condition checking and completion alert

## Technical Details

- **Target Platforms**: iOS 18.5+, macOS 15.5+, visionOS 2.5+
- **Swift Version**: 5.0
- **Bundle ID**: de.kaikunze.numeriqo
- **Development Team**: 8H42EZRCCP
- **Entitlements**: App sandbox with read-only file access
- **UI Framework**: SwiftUI with ObservableObject pattern for state management