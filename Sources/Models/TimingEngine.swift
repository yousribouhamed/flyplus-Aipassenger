import Foundation

/// Every number the passenger acts on comes from here.
///
/// Timing is deterministic and never the model's guess: the assistant may
/// *say* the result, but it does not compute it. The formula is fixed by the
/// POC scope document:
///
///     available = boarding − now − walk − buffer
///
/// with a 15-minute safety buffer at the gate. A model that invents "you have
/// about half an hour" is the single fastest way to lose an airport's trust,
/// so the arithmetic lives in one testable place and the copy layer only
/// renders what it returns.
enum TimingEngine {
    /// The safety buffer the passenger should still have at the gate once they
    /// arrive. Owned by the deployment, not by the model — the open question of
    /// who sets it per airport is recorded in the research document.
    static let safetyBufferMinutes = 15

    // MARK: Core arithmetic

    static func minutes(from start: Date, to end: Date) -> Int {
        Int((end.timeIntervalSince(start) / 60).rounded())
    }

    /// The moment the passenger must start walking to reach the gate with the
    /// full buffer intact.
    static func leaveBy(boarding: Date, walkMinutes: Int) -> Date {
        boarding.addingTimeInterval(TimeInterval(-(walkMinutes + safetyBufferMinutes) * 60))
    }

    /// Minutes of genuinely free time: what is left after the walk and the
    /// buffer are taken out. Can go negative, which is the "running late" case.
    static func slackMinutes(now: Date, boarding: Date, walkMinutes: Int) -> Int {
        minutes(from: now, to: boarding) - walkMinutes - safetyBufferMinutes
    }

    /// When the passenger would arrive if they left now.
    static func arrival(leaving departure: Date, walkMinutes: Int) -> Date {
        departure.addingTimeInterval(TimeInterval(walkMinutes * 60))
    }

    // MARK: Pressure

    enum Pressure: Sendable {
        /// More than half an hour spare — the assistant leads with reassurance.
        case plenty
        /// Spare time, but a decision worth making now.
        case enough
        /// The buffer is being eaten; leaving is the only recommendation.
        case leaveNow
        /// Past the leave-by. The recommendation becomes the whole screen.
        case late
    }

    static func pressure(slackMinutes slack: Int) -> Pressure {
        switch slack {
        case ..<0:   .late
        case 0..<5:  .leaveNow
        case 5..<20: .enough
        default:     .plenty
        }
    }

    // MARK: Phrasing

    /// Shipped apps overwhelmingly count deadlines *down* rather than naming a
    /// clock time — American's "Boards in 17 minutes", Flighty's "Gate
    /// Departure in 2h 58m". Qantas draws the rule worth adopting: a scheduled
    /// event gets a clock time, a deadline gets a countdown.
    static func countdown(minutes total: Int) -> String {
        guard total > 0 else { return "now" }
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        let minutes = total % 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    /// The one deliberate deviation from the category. A leave-by is an
    /// instruction the passenger acts on *after* they stop looking at the
    /// phone, and a countdown that keeps moving is harder to plan against — so
    /// this one stays absolute. Flagged in the research as an assumption to
    /// test, not as settled best practice.
    static func leaveByPhrase(_ date: Date, using tr: Translator) -> String {
        tr("Leave by \(tr.clock(date))", "غادر قبل \(tr.clock(date))")
    }
}
