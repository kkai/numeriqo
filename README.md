# Numeriqo

A MathMaze puzzle game for iOS, macOS, and Apple Vision Pro built with SwiftUI.

## Overview

Numeriqo is a mathematical puzzle game where players fill grids with numbers following Latin square rules while satisfying mathematical constraints within cages. Each cage contains a target value and mathematical operation that must be achieved using the numbers within that cage.

## Features

- **Multiple Grid Sizes**: Play on 3x3, 4x4, 5x5, 6x6, 7x7, 8x8, or 9x9 grids
- **Dynamic Puzzle Generation**: Each game generates a unique puzzle with Latin square solution
- **Mathematical Operations**: Cages use addition, subtraction, multiplication, and division
- **Cross-Platform**: Native support for iPhone, iPad, Mac, and Apple Vision Pro
- **SwiftUI Interface**: Modern, responsive user interface

## Requirements

- iOS 18.5+ / macOS 15.5+ / visionOS 2.5+
- Xcode 16.0+
- Swift 5.0+

## Building

### Debug Build
```bash
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -configuration Debug build
```

### Release Build
```bash
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -configuration Release build
```

### Platform-Specific Builds
```bash
# iOS Simulator
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# macOS
xcodebuild -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=macOS' build
```

## Testing

```bash
# iOS Tests
xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# macOS Tests
xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo -destination 'platform=macOS'
```

## Running

Open `Numeriqo.xcodeproj` in Xcode and press Cmd+R to run, or use the build commands above with appropriate destination parameters.

## Architecture

### Core Components

- **NumeriqoApp.swift**: Main app entry point
- **ContentView.swift**: Navigation and game state management
- **KenKenGame.swift**: Core game logic and puzzle generation
- **KenKenGameView.swift**: Game interface and user interaction

### Key Classes

- **MathMazeGame**: ObservableObject managing game state
- **Cage**: Mathematical constraint groups
- **Position**: Grid coordinate system
- **Operation**: Mathematical operations enum

## License

Copyright © 2024 Kai Kunze. All rights reserved.