import Foundation

// MARK: - Journey timing
//
// §12 of the PDF is unusually prescriptive, and for good reason:
//
//     Available Time = Boarding − Now − Walking Time to Gate − Safety Buffer
//
// "Critical journey calculations should be deterministic rather than left
//  entirely to the language model … The underlying platform remains
//  authoritative for timing and business rules."
//
// So the maths lives here. The assistant may only *phrase* what this returns.

struct TimingEngine {

    /// Minutes kept in reserve at the gate. A business rule, not a guess.
    static let safetyBufferMinutes = 15

    /// How long after touchdown an arriving passenger typically takes to clear
    /// immigration and collect bags. This is what makes meeting someone useful:
    /// the landing time is not the time they appear.
    static let clearanceMinutes = 40

    struct Budget: Equatable {
        let minutesToBoarding: Int
        let walkMinutesToGate: Int
        let safetyBufferMinutes: Int
        /// Discretionary minutes: what the passenger may actually spend.
        let availableMinutes: Int

        var isBehindSchedule: Bool { availableMinutes < 0 }
    }

    /// The passenger's discretionary time right now.
    static func budget(now: Date, boarding: Date, walkMinutesToGate: Int) -> Budget {
        let toBoarding = Int((boarding.timeIntervalSince(now) / 60).rounded(.down))
        return Budget(
            minutesToBoarding: toBoarding,
            walkMinutesToGate: walkMinutesToGate,
            safetyBufferMinutes: safetyBufferMinutes,
            availableMinutes: toBoarding - walkMinutesToGate - safetyBufferMinutes
        )
    }

    /// When someone is *meeting* a flight, the deadline is not landing — it is
    /// landing plus clearance. Same arithmetic, different anchor.
    static func meetingBudget(now: Date, landing: Date, walkMinutesToArrivals: Int) -> Budget {
        let emerges = landing.addingTimeInterval(Double(clearanceMinutes) * 60)
        let toEmerge = Int((emerges.timeIntervalSince(now) / 60).rounded(.down))
        return Budget(
            minutesToBoarding: toEmerge,
            walkMinutesToGate: walkMinutesToArrivals,
            safetyBufferMinutes: 5,            // you only need to be there, not seated
            availableMinutes: toEmerge - walkMinutesToArrivals - 5
        )
    }

    static func emergenceTime(landing: Date) -> Date {
        landing.addingTimeInterval(Double(clearanceMinutes) * 60)
    }

    // MARK: Feasibility of an optional stop

    struct Feasibility: Equatable {
        let poi: POI
        /// Extra minutes the detour costs versus going straight to the gate,
        /// including time actually spent at the stop.
        let detourCostMinutes: Int
        let walkMinutesViaStop: Int
        let directWalkMinutes: Int
        let budget: Budget
        let isFeasible: Bool
        /// Minutes left over if the passenger takes the stop.
        let sparedMinutes: Int

        /// Minutes the detour adds to walking alone — 0 when the stop is on the route.
        var addedWalkMinutes: Int { max(0, walkMinutesViaStop - directWalkMinutes) }
        var isOnRoute: Bool { addedWalkMinutes == 0 }
        /// True when there is no deadline at all — a visitor. Distinct from
        /// "feasible", which is a judgement; this is the absence of one.
        var isUnbounded: Bool = false

        /// Someone with nowhere to be. Everything is reachable; nothing is "on route".
        static func unbounded(poi: POI, walkMinutes: Int) -> Feasibility {
            Feasibility(
                poi: poi,
                detourCostMinutes: 0,
                walkMinutesViaStop: walkMinutes,
                directWalkMinutes: 0,
                budget: Budget(minutesToBoarding: 0, walkMinutesToGate: 0,
                               safetyBufferMinutes: 0, availableMinutes: 0),
                isFeasible: true,
                sparedMinutes: 0,
                isUnbounded: true
            )
        }
    }

    /// Can the passenger make this stop and still board comfortably?
    static func evaluate(stop poi: POI,
                         now: Date,
                         boarding: Date,
                         directWalkMinutes: Int,
                         walkMinutesViaStop: Int) -> Feasibility {

        let budget = budget(now: now, boarding: boarding, walkMinutesToGate: directWalkMinutes)
        // The cost of the detour is the extra walking *plus* the time spent there.
        let detour = max(0, walkMinutesViaStop - directWalkMinutes) + poi.dwellMinutes
        let spared = budget.availableMinutes - detour

        return Feasibility(
            poi: poi,
            detourCostMinutes: detour,
            walkMinutesViaStop: walkMinutesViaStop,
            directWalkMinutes: directWalkMinutes,
            budget: budget,
            isFeasible: spared >= 0 && !budget.isBehindSchedule,
            sparedMinutes: spared,
            isUnbounded: false
        )
    }

    // MARK: Phrasing helpers
    //
    // The platform decides; these turn a decision into passenger-facing language.

    static func scheduleVerdict(_ budget: Budget) -> String {
        if budget.isBehindSchedule { return "You should head to your gate now." }
        if budget.availableMinutes < 10 { return "You're on schedule, but don't linger." }
        return "You're on schedule."
    }

    static func durationPhrase(_ minutes: Int) -> String {
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Clock times are always shown in the *airport's* timezone — a passenger
    /// standing in JED reads JED local time, not their device's home offset.
    /// Set once from the active airport; the POC airport is Jeddah.
    nonisolated(unsafe) static var displayTimeZone: TimeZone = TimeZone(identifier: "Asia/Riyadh") ?? .current

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = displayTimeZone
        return f.string(from: date)
    }
}
