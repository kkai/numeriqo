//
//  TechniqueContent.swift
//  Numeriqo
//
//  All teaching copy. The engine emits structured facts and no strings; this is
//  the single place they become English.
//
//  One voice throughout: direct, concrete, never mystical about "logic". Say
//  what is true about *this* board, and say what to do about it.
//

import Foundation

nonisolated enum TechniqueContent {

    // MARK: - The rule (hint level 2, and the Learn menu subtitle)

    static func rule(for technique: Technique) -> String {
        switch technique {
        case .freebieCage:
            "A cage with one cell has no operator. The number in the corner is the answer."
        case .divisibility:
            "Every digit in a × cage has to divide its target. If it doesn't divide cleanly, it isn't in the cage."
        case .minMaxBounds:
            "Check what the rest of a + cage can still reach. If a digit puts the target out of reach, high or low, it's out."
        case .pairSets:
            "Two-cell − and ÷ cages have very short lists. In a 6×6, 5− is only {1,6} and 4÷ is only {1,4}."
        case .cageCombination:
            "List the digit sets a cage can hold, then keep only what survives. Anything that appears in none of them can go."
        case .nakedSingle:
            "When a cell has one candidate left, that's the answer. Place it."
        case .hiddenSingle:
            "If a digit fits in only one cell of a row or column, it goes there, whatever else that cell could have been."
        case .lastCellInLine:
            "One empty cell left in a row or column takes the one digit that row or column is missing."
        case .nakedSubset:
            "If k cells in a line share exactly k candidates between them, those digits are spoken for. Clear them from the rest of the line."
        case .hiddenSubset:
            "If k digits can only land in k cells of a line, those cells hold exactly those digits. Everything else in them goes."
        case .pointingCage:
            "If a digit the cage needs can only sit in one row or column, that line holds it. Clear it from the line's other cells."
        case .claimingLine:
            "If a digit in a line can only sit inside one cage, that cage contains it. Every arrangement of the cage that leaves it out is dead."
        case .ruleOfN:
            "Every row and column adds up to the same total. Cages sitting wholly inside a line account for part of it, and the rest is forced."
        case .outie:
            "When the cages covering a line spill past it by one cell, that cell is the difference between their total and the line's."
        case .parity:
            "Every line holds a fixed number of odd digits. Once they're all spoken for, everything left has to be even. It works the other way round too."
        case .xWing:
            "A digit confined to the same two columns in two different rows takes one cell in each. It can leave those columns everywhere else."
        }
    }

    /// A few words for a menu row.
    ///
    /// `rule(for:)` is a full sentence and belongs in the lesson, not in a list
    /// row: at 80 to 140 characters it clipped on six rows at once, which is
    /// exactly what `performAccessibilityAudit` reported.
    static func summary(for technique: Technique) -> String {
        switch technique {
        case .freebieCage: "One cell, one answer"
        case .divisibility: "Only factors of the target"
        case .minMaxBounds: "What the rest can still reach"
        case .pairSets: "Short lists for − and ÷"
        case .cageCombination: "Which digit sets survive"
        case .nakedSingle: "One candidate left"
        case .hiddenSingle: "One home for a digit"
        case .lastCellInLine: "The digit a line is missing"
        case .nakedSubset: "Cells that share their digits"
        case .hiddenSubset: "Digits that share their cells"
        case .pointingCage: "A cage pins a digit to one line"
        case .claimingLine: "A line pins a digit to one cage"
        case .ruleOfN: "Every line adds to the same total"
        case .outie: "Cages that spill past a line"
        case .parity: "Counting odds and evens"
        case .xWing: "One digit, two lines, two columns"
        }
    }

    // MARK: - The lesson (Learn, and the opening beat of a tutorial)

    static func lesson(for technique: Technique) -> String {
        switch technique {
        case .freebieCage:
            "Single-cell cages are the way in. Fill every one before you do anything else. Each is a free digit, and each one narrows its row and column straight away."
        case .divisibility:
            "Multiplication cages give away more than they look. A 40× cage can hold no 3 and no 6, because neither divides 40. Factor the target first and most of the pad disappears."
        case .minMaxBounds:
            "Every partial cage leaves a remainder. If two cells must make 5, neither can be a 5. If three must make 15 in a 6×6, none can be below 3. Bounds rule out most of the pad before you enumerate anything."
        case .pairSets:
            "Two-cell − and ÷ cages leave the fewest options of any clue, and are worth memorising. In a 6×6 there is exactly one pair for 5−, 4÷, 5÷ and 6÷. A 1− cage tells you almost nothing."
        case .cageCombination:
            "Write out the digit sets a cage could hold, then strike the ones its row and column rule out. A digit may repeat inside a cage as long as the repeats don't share a row or column, so a bent cage has more options than a straight one."
        case .nakedSingle:
            "Keep notes as you go. The moment eliminations leave a single candidate, the cell is decided. Enter it and let the new digit ripple down its row and column."
        case .hiddenSingle:
            "Sometimes a cell has options but the line doesn't. Scan a row for a digit it still needs and count how many cells could take it. If there's only one, it was already placed and you hadn't noticed."
        case .lastCellInLine:
            "Five of six cells filled means the sixth is whatever's missing. Worth a sweep every time you place anything."
        case .nakedSubset:
            "Two cells that can only be 3 or 5 have used up both digits between them, even though neither is decided. Nothing else in that line can be a 3 or a 5. Three cells sharing three digits work the same way, and four sharing four."
        case .hiddenSubset:
            "Matching Sets runs the other way round too. If 2, 4 and 7 can only go in three particular cells of a row, then those cells are exactly 2, 4 and 7. Every other candidate in them goes, however plausible it looked."
        case .pointingCage:
            "Cages and lines constrain each other. If a cage must contain a 6 and every cell that could hold it lies in one column, that column's 6 is inside the cage. Clear it from the column's other cells."
        case .claimingLine:
            "Run the same argument backwards. If the only cells in a row that can take a 4 all belong to one cage, that cage contains the row's 4, and every arrangement of the cage without one is dead."
        case .ruleOfN:
            "A 6×6 row always totals 21. Add up the cages sitting wholly inside a row and subtract. Whatever is left belongs to the cells they don't cover, and if that's one cell you have its digit outright."
        case .outie:
            "Rule of N again, one step further. If the cages touching a row cover it and spill over by exactly one cell, subtract the row's total from theirs. What remains is the spilled cell: a digit found outside the line you were looking at."
        case .parity:
            "Odd and even are information on their own. A 6×6 line holds exactly three odd digits. Count the odd cells you've settled, and once you reach three, everything still open in that line must be even. No enumeration needed."
        case .xWing:
            "When two rows both confine a digit to the same pair of columns, those rows take that digit in those columns between them, and no other row can use it there."
        }
    }

    // MARK: - Contextual copy

    /// Hint level 1. Says *where*, never *what* — the player should still have
    /// to find the deduction.
    static func nudge(for step: TechniqueApplication, puzzle: Puzzle) -> String {
        let place = regionPhrase(for: step, puzzle: puzzle)
        switch step.technique {
        case .freebieCage:
            return "There's a cage \(place) that hands you its digit."
        case .divisibility, .cageCombination, .pairSets:
            return "A cage \(place) allows fewer digits than you've ruled out."
        case .minMaxBounds:
            return "The remaining total in a cage \(place) is tighter than it looks."
        case .nakedSingle:
            return "A cell \(place) is down to its last candidate."
        case .hiddenSingle:
            return "A line \(place) needs a digit that has only one home left."
        case .lastCellInLine:
            return "A line \(place) has one cell to go."
        case .nakedSubset, .hiddenSubset:
            return "A few cells \(place) have their digits settled between them, even though none is decided."
        case .pointingCage, .claimingLine:
            return "A cage and a line \(place) are constraining each other."
        case .ruleOfN, .outie:
            return "Try adding up a line \(place) and seeing what the cages leave over."
        case .parity:
            return "Count the odd digits in a line \(place)."
        case .xWing:
            return "Two lines \(place) trap the same digit in the same pair of columns."
        }
    }

    /// Hint level 3. The concrete argument, once the cells are showing.
    static func detail(for step: TechniqueApplication, puzzle: Puzzle) -> String {
        switch step.technique {
        case .freebieCage:
            if let placement = step.placements.first {
                return "This cage has one cell, so its target is its digit: \(placement.digit)."
            }

        case .divisibility:
            if let cage = cage(for: step, in: puzzle), !step.explanation.digits.isEmpty {
                return "\(list(step.explanation.digits)) \(step.explanation.digits.count == 1 ? "does" : "do") not divide \(cage.target), so \(step.explanation.digits.count == 1 ? "it" : "they") cannot appear in this cage."
            }

        case .minMaxBounds:
            if let cage = cage(for: step, in: puzzle) {
                return "The other cells of this \(cage.clueText) cage can't stretch far enough to make the struck candidates work."
            }

        case .pairSets, .cageCombination:
            if let cage = cage(for: step, in: puzzle) {
                let sets = step.explanation.combinations.prefix(3)
                    .map { "{" + DigitSet.digits($0).map(String.init).joined(separator: ",") + "}" }
                    .joined(separator: " or ")
                if !sets.isEmpty {
                    let more = step.explanation.combinations.count > 3 ? ", and a few more" : ""
                    return "\(cage.clueText) can only be \(sets)\(more). Anything outside those sets is struck."
                }
                return "\(cage.clueText) allows fewer digit sets than the struck candidates assume."
            }

        case .nakedSingle:
            if let placement = step.placements.first {
                return "Only \(placement.digit) is left for the highlighted cell."
            }

        case .hiddenSingle:
            if let placement = step.placements.first {
                return "\(placement.digit) fits in exactly one cell of the highlighted \(lineWord(step)): this one."
            }

        case .lastCellInLine:
            if let placement = step.placements.first {
                return "Every other cell in this \(lineWord(step)) is filled. The missing digit is \(placement.digit)."
            }

        case .nakedSubset:
            if !step.explanation.digits.isEmpty {
                return "The highlighted cells hold \(list(step.explanation.digits)) between them, so nothing else in the \(lineWord(step)) can use those digits."
            }

        case .hiddenSubset:
            if !step.explanation.digits.isEmpty {
                return "\(list(step.explanation.digits)) can only land in the highlighted cells, so those cells are exactly those digits. Everything else in them goes."
            }

        case .pointingCage:
            if let digit = step.explanation.digits.first {
                return "This cage has to contain a \(digit), and every cell that could hold it sits in the same \(lineWord(step)). So that's where the \(lineWord(step))'s \(digit) lives."
            }

        case .claimingLine:
            if let digit = step.explanation.digits.first {
                return "The only cells in this \(lineWord(step)) that can take a \(digit) all belong to one cage, so that cage must contain it."
            }

        case .ruleOfN:
            return "This \(lineWord(step)) totals \(LatinSquare.lineSum(size: puzzle.size)). The cages inside it account for most of that, and the rest doesn't stretch to the struck candidates."

        case .outie:
            if let placement = step.placements.first {
                return "The cages covering this \(lineWord(step)) spill over by one cell. Their total minus \(LatinSquare.lineSum(size: puzzle.size)) leaves \(placement.digit) for it."
            }

        case .parity:
            let kind = step.explanation.digits.first.map { $0 % 2 == 0 } ?? false
            return "This \(lineWord(step)) has used up its \(kind ? "even" : "odd") digits. Everything still open has to be \(kind ? "odd" : "even")."

        case .xWing:
            if let digit = step.explanation.digits.first {
                return "Two lines both trap \(digit) in the same pair of columns, so between them they take it there. No other row can use \(digit) in those columns."
            }
        }

        // Every context-dependent branch falls back rather than emitting a
        // sentence with a hole in it.
        return rule(for: step.technique)
    }

    /// Hint level 4. Never repeats level 3 — it adds the instruction.
    static func resolution(for step: TechniqueApplication, puzzle: Puzzle) -> String {
        let body = detail(for: step, puzzle: puzzle)
        if let placement = step.placements.first {
            return "\(body) Tap Apply to place \(placement.digit)."
        }
        return "\(body) Tap Apply to strike them from your notes."
    }

    // MARK: - Error copy

    /// A digit that isn't the one that goes here.
    ///
    /// Deliberately not "you broke a rule" — in Calcudoku a wrong digit usually
    /// breaks nothing visible, and saying otherwise would teach something false.
    static func wrongDigit(count: Int) -> String {
        count == 1
            ? "One of your digits isn't the one that goes there. It breaks no rule. It's simply not the answer."
            : "\(count) of your digits aren't the ones that go there. They break no rules. They're simply not the answers."
    }

    static let wrongNote =
        "One of your notes can't be right. Worth fixing before you build on it."

    static let nothingToFind =
        "Everything on the grid checks out. Keep going."

    static let withheld =
        "There's a move here. Teaching hints name the technique and draw the reasoning on the grid. They come with the full game."

    // MARK: - Helpers

    /// Says roughly where without saying what. Thirds of the board.
    private static func regionPhrase(for step: TechniqueApplication, puzzle: Puzzle) -> String {
        guard let cell = step.focusCells.first
                ?? step.placements.first?.cell
                ?? step.eliminations.first?.cell
        else { return "on the grid" }

        if let line = step.explanation.line {
            return line.kind == .row ? "in row \(line.index + 1)" : "in column \(line.index + 1)"
        }

        let third = max(puzzle.size / 3, 1)
        let vertical = cell.row < third ? "top" : (cell.row >= puzzle.size - third ? "bottom" : "middle")
        let horizontal = cell.col < third ? "left" : (cell.col >= puzzle.size - third ? "right" : "centre")
        if vertical == "middle" && horizontal == "centre" { return "in the middle of the grid" }
        return "in the \(vertical) \(horizontal)"
    }

    private static func lineWord(_ step: TechniqueApplication) -> String {
        switch step.explanation.line?.kind {
        case .row: "row"
        case .column: "column"
        case nil: "line"
        }
    }

    private static func cage(for step: TechniqueApplication, in puzzle: Puzzle) -> Cage? {
        guard let index = step.involvedCages.first, index < puzzle.cages.count else { return nil }
        return puzzle.cages[index]
    }

    /// Makes a digit list read as English.
    private static func list(_ digits: [Int]) -> String {
        let strings = digits.map(String.init)
        switch strings.count {
        case 0: return "nothing"
        case 1: return strings[0]
        case 2: return "\(strings[0]) and \(strings[1])"
        default: return strings.dropLast().joined(separator: ", ") + " and " + strings.last!
        }
    }
}
