# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift/SwiftUI iOS/macOS application called "gengen" - a multiplatform app supporting iPhone, iPad, Mac, and Apple Vision Pro. The project uses a minimal SwiftUI architecture with basic sandbox entitlements.

## Development Commands

### Building
```bash
# Build the project (Debug configuration)
xcodebuild -project gengen.xcodeproj -scheme gengen -configuration Debug build

# Build for release
xcodebuild -project gengen.xcodeproj -scheme gengen -configuration Release build

# Build and run in simulator
xcodebuild -project gengen.xcodeproj -scheme gengen -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for macOS
xcodebuild -project gengen.xcodeproj -scheme gengen -destination 'platform=macOS' build
```

### Testing
```bash
# Run tests
xcodebuild test -project gengen.xcodeproj -scheme gengen -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run tests on macOS
xcodebuild test -project gengen.xcodeproj -scheme gengen -destination 'platform=macOS'
```

### Running
Open the project in Xcode and use Cmd+R to run, or use xcodebuild with appropriate destination parameters.

## Architecture

- **App Entry Point**: `gengenApp.swift` - Main app struct with WindowGroup scene
- **Main View**: `ContentView.swift` - Simple SwiftUI view with globe icon and "Hello, world!" text
- **Target Platforms**: iOS 18.5+, macOS 15.5+, visionOS 2.5+
- **Swift Version**: 5.0
- **Bundle ID**: de.kaikunze.gengen

## Key Configuration

- App uses sandbox entitlements with read-only file access
- Development team: 8H42EZRCCP
- Multi-platform support with device families: iPhone, iPad, Apple Vision Pro
- SwiftUI Previews enabled
- Hardened Runtime enabled for macOS