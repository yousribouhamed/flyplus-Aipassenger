import Foundation

/// Where the passenger is in their journey. Home is not one screen with
/// variable content — it is one layout rendered against this state machine,
/// and the state decides the "what matters now" block, the verdict line and
/// the primary action. The layout itself never changes.
enum JourneyStage: String, CaseIterable, Identifiable, Sendable {
    case preAirport
    case landside
    case checkedIn
    case airside
    case boardingSoon
    case boarding
    case changed
    case runningLate
    case inFlight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preAirport:   "Pre-airport"
        case .landside:     "At airport, landside"
        case .checkedIn:    "Check-in done"
        case .airside:      "Airside"
        case .boardingSoon: "Boarding soon"
        case .boarding:     "Boarding"
        case .changed:      "Gate changed"
        case .runningLate:  "Running late"
        case .inFlight:     "In flight"
        }
    }

    /// The POC demo starts here: through security, 47 minutes to boarding.
    static let demoDefault: JourneyStage = .airside
}

enum FlightStatus: String, Sendable {
    case onTime      = "On time"
    case delayed     = "Delayed"
    case gateChanged = "Gate changed"
    case boarding    = "Boarding"
    case finalCall   = "Final call"
    case departed    = "Departed"
    case cancelled   = "Cancelled"

    /// State is never carried by colour alone, so every status also has a
    /// symbol and the `rawValue` word above.
    var symbol: String {
        switch self {
        case .onTime:      "checkmark.circle.fill"
        case .delayed:     "clock.badge.exclamationmark.fill"
        case .gateChanged: "arrow.triangle.swap"
        case .boarding:    "figure.walk.departure"
        case .finalCall:   "exclamationmark.triangle.fill"
        case .departed:    "airplane.departure"
        case .cancelled:   "xmark.octagon.fill"
        }
    }

    enum Tone: Sendable { case neutral, timeSensitive, changed }

    var tone: Tone {
        switch self {
        case .onTime, .departed:        .neutral
        case .boarding, .finalCall:     .timeSensitive
        case .delayed, .gateChanged, .cancelled: .changed
        }
    }
}

struct Airport: Sendable, Hashable {
    let code: String
    let city: String
    let name: String
}

/// The passenger's flight. Every value here is hardcoded demo data — there is
/// no networking anywhere in this app, matching the rest of the Fly+ family.
struct Flight: Sendable, Identifiable, Hashable {
    var id: String { number }

    let number: String
    let airline: String
    let origin: Airport
    let destination: Airport
    let scheduledDeparture: Date
    let scheduledArrival: Date
    let boardingTime: Date
    let gate: String
    let terminal: String
    let concourse: String
    let seat: String
    let status: FlightStatus

    /// The fixed demo story: JED to LHR on SV117, gate 32, boarding 17:55,
    /// departure 18:40, passenger already airside.
    static let demo = Flight(
        number: "SV117",
        airline: "Saudia",
        origin: Airport(code: "JED", city: "Jeddah", name: "King Abdulaziz International"),
        destination: Airport(code: "LHR", city: "London", name: "Heathrow"),
        scheduledDeparture: DemoClock.time(18, 40),
        scheduledArrival: DemoClock.time(21, 55),
        boardingTime: DemoClock.time(17, 55),
        gate: "32",
        terminal: "1",
        concourse: "B",
        seat: "24A",
        status: .onTime
    )

    /// The same flight after the gate change that drives screen 13.
    static let demoAfterGateChange = Flight(
        number: demo.number,
        airline: demo.airline,
        origin: demo.origin,
        destination: demo.destination,
        scheduledDeparture: demo.scheduledDeparture,
        scheduledArrival: demo.scheduledArrival,
        boardingTime: demo.boardingTime,
        gate: "41",
        terminal: demo.terminal,
        concourse: "C",
        seat: demo.seat,
        status: .gateChanged
    )
}

/// The demo runs against a clock anchored at 17:08 on the day the app launches,
/// then ticks in real time so countdowns move and journey states actually
/// advance during a walkthrough. Resettable from More, because a demo that has
/// drifted past boarding is no use to the next stakeholder in the room.
enum DemoClock {
    static let anchorHour = 17
    static let anchorMinute = 8

    static func time(_ hour: Int, _ minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: today) ?? today
    }

    static var anchor: Date { time(anchorHour, anchorMinute) }
}
