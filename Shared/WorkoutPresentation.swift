import Foundation
import RowivoCore

func localized(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }
func clockText(_ seconds: Int) -> String { String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60) }
func minuteText(_ minutes: Int) -> String { String(format: String(localized: "%lld min"), Int64(minutes)) }
func durationText(_ seconds: Int) -> String {
    if seconds % 60 == 0 { return minuteText(seconds / 60) }
    if seconds < 60 { return String(format: String(localized: "%lld sec"), Int64(seconds)) }
    return String(format: String(localized: "%lld min %lld sec"), Int64(seconds / 60), Int64(seconds % 60))
}
func blockText(_ block: Int) -> String { String(format: String(localized: "Block %lld"), Int64(block)) }

extension WorkoutKind {
    /// Presentation copy is independent of the raw values stored in existing training data.
    var displayName: String {
        switch self {
        case .technique: String(localized: "Technique practice")
        case .endurance: String(localized: "Endurance")
        case .intervals: String(localized: "Intervals")
        case .recovery: String(localized: "Recovery row")
        }
    }
}

extension Workout {
    var displayName: String {
        let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? kind.displayName : name
    }
}

extension WorkoutCompletion {
    var displayName: String {
        let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? title.displayName : name
    }
}

