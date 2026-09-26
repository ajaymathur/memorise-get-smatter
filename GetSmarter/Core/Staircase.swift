/// 2-down/1-up adaptive staircase (Levitt 1971): two consecutive successes step up,
/// one failure steps down. Converges near 70.7 % success (design.md §5).
struct Staircase: Sendable, Equatable {
    private(set) var level: Int
    let range: ClosedRange<Int>
    private var streak = 0

    init(level: Int, range: ClosedRange<Int>) {
        self.range = range
        self.level = min(max(level, range.lowerBound), range.upperBound)
    }

    mutating func record(success: Bool) {
        if success {
            streak += 1
            if streak == 2 {
                level = min(level + 1, range.upperBound)
                streak = 0
            }
        } else {
            level = max(level - 1, range.lowerBound)
            streak = 0
        }
    }
}
