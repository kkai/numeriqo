# KenKen Win Condition Enhancement Plan

## Current State Analysis

The current KenKen implementation correctly validates win conditions but has limited real-time constraint checking:

### Current Win Condition Logic
- **Location**: `MathMazeGame.swift` - `isValidSolution()` method (lines 193-216)
- **Latin Square Validation**: ✅ Correctly checks unique numbers in rows/columns
- **Cage Constraint Validation**: ✅ Correctly validates mathematical operations at game completion
- **Real-time Validation**: ⚠️ Only checks Latin square constraints during play (`isValidMove()` lines 110-128)

### Identified Issues
1. **Limited Real-time Feedback**: `isValidMove()` doesn't check cage constraints during play
2. **Delayed Cage Validation**: Players can enter numbers violating cage math without immediate feedback
3. **Inconsistent Validation**: Different validation rules during play vs completion

## Phase 1: Enhanced Constraint Validation (No UI Changes)

### Goal
Enhance the validation logic to check cage constraints in real-time without adding user feedback yet.

### Implementation Plan

#### 1. Extend `isValidMove()` Method
- **File**: `KenKenGame.swift`
- **Method**: `isValidMove(_:at:)` (lines 110-128)
- **Enhancement**: Add cage constraint validation alongside existing Latin square checks

#### 2. Add Cage State Validation Helper
- **New Method**: `isValidCageState(for cage: Cage) -> Bool`
- **Purpose**: Check if partially filled cage is still solvable
- **Logic**: 
  - For complete cages: validate exact target match
  - For incomplete cages: validate constraints aren't already violated

#### 3. Create Comprehensive Move Validation
- **Enhanced Method**: `isValidMove(_:at:)` 
- **Validation Order**:
  1. Latin square constraints (existing)
  2. Cage constraint validation (new)
  3. Future move possibility check (new)

### Technical Implementation Details

```swift
// Enhanced validation method signature
func isValidMove(_ value: Int, at position: Position) -> Bool {
    // 1. Existing Latin square validation
    // 2. New cage constraint validation
    // 3. Return combined result
}

// New helper method
private func isValidCageState(for cage: Cage) -> Bool {
    // Check if cage constraints are satisfied or still achievable
}
```

## Outstanding Questions

### 1. Validation Timing
Should cage constraint validation happen on every number input, or only when a cage is completely filled? Real-time validation could be distracting if it shows errors for incomplete cages.

### 2. Performance Considerations  
With larger grids (7x7, 8x8, 9x9 in Pro version), should validation be debounced or optimized to avoid UI lag during rapid input?

### 3. Cage State Logic
Should the validation distinguish between:
- "Impossible to complete" (mathematically invalid)
- "Still solvable" (constraints not yet violated)
- "Correctly completed" (target achieved)

### 4. Error Granularity
Should validation return boolean or provide specific error types for different constraint violations?

### 5. Testing Scope
Do you want unit tests for the new validation logic immediately, or after UI feedback is implemented?

### 6. Platform Differences
Should enhanced validation work differently on macOS vs iOS/visionOS given different interaction patterns?

### 7. Backward Compatibility
Should enhanced validation be introduced as a feature flag or directly replace existing behavior?

### 8. User Preference
Should enhanced validation be toggleable, allowing players to choose between "helpful mode" and "challenge mode"?

### 9. Accessibility Considerations
How important is VoiceOver/accessibility support for constraint feedback features?

### 10. Visual Feedback Strategy (Future Phase)
What's the preferred visual indicator for cage violations - border colors, background highlighting, or icon overlays?

## Implementation Phases

### Phase 1: Core Validation (Current Focus)
- Enhance `isValidMove()` with cage constraint checking
- Add comprehensive validation helper methods
- No UI changes or user feedback

### Phase 2: Visual Feedback (Future)
- Add visual indicators for constraint violations
- Implement color coding for cage states
- Provide user-facing error messages

### Phase 3: Advanced Features (Future)
- Debounced validation for performance
- User preference toggles
- Accessibility enhancements

## Success Criteria

### Phase 1 Completion
- [ ] `isValidMove()` validates both Latin square and cage constraints
- [ ] No regression in existing win condition logic
- [ ] Comprehensive unit test coverage
- [ ] Performance maintained on large grids

### Future Phases
- Visual feedback implementation
- User experience enhancements
- Advanced validation features