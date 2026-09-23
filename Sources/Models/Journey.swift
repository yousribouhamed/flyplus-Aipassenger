import Foundation

// MARK: - Zone
//
// The single most consequential fact about a person in an airport: which side
// of security they are on. A visitor can never pass it, so routing a visitor to
// an airside café is not a cosmetic bug — it is the app confidently lying.

enum Zone: String, Equatable {
    case landside, airside
}

// MARK: - Why someone is in the building

enum VisitMode: String, Equatable, CaseIterable {
    /// Travelling — the flight is theirs.
    case departing
    /// Here for someone else's arriving flight.
    case meeting
    /// No flight at all: a shop, an errand, a question.
    case visiting

    var title: String {
        switch self {
        case .departing: "Flying today"
        case .meeting: "Meeting someone"
        case .visiting: "Just visiting"
        }
    }
}

// MARK: - Flight

struct Flight: Equatable {
    var number: String
    var airlineName: String
    var originCode: String
    var originCity: String
    var destinationCode: String
    var destinationCity: String
    var status: Status
    var boarding: Date
    var departure: Date
    var gate: String
    var terminal: String
    var baggageBelt: String

    /// Set when this flight is being *met* rather than taken.
    var landing: Date? = nil
    /// Which hall the arriving passenger emerges into.
    var arrivalsExit: String = "Arrivals B"

    enum Status: String, Equatable {
        case onTime = "ON TIME"
        case delayed = "DELAYED"
        case boarding = "BOARDING"
        case gateChanged = "GATE CHANGED"
        case landed = "LANDED"
    }

    var route: String { "\(originCode) → \(destinationCode)" }
}

// MARK: - Journey stage

enum JourneyStage: Int, CaseIterable, Comparable {
    case beforeAirport
    case atAirport
    case beforeSecurity
    case airside
    case boardingSoon
    case arrival

    static func < (a: JourneyStage, b: JourneyStage) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .beforeAirport: "Before airport"
        case .atAirport:     "At the airport"
        case .beforeSecurity:"Before security"
        case .airside:       "Airside"
        case .boardingSoon:  "Boarding soon"
        case .arrival:       "Arrival"
        }
    }

    var nextAction: String {
        switch self {
        case .beforeAirport: "Head to the airport"
        case .atAirport:     "Complete check-in"
        case .beforeSecurity:"Proceed to Security"
        case .airside:       "Make your way to the gate"
        case .boardingSoon:  "Head to your gate now"
        case .arrival:       "Collect your baggage"
        }
    }
}

// MARK: - Context
//
// What the platform knows about the person holding the phone. The `mode`
// decides which anchor Home shows and — via `zone` — what is even reachable.

struct PassengerContext: Equatable {
    var mode: VisitMode
    /// The anchoring flight: theirs when departing, someone else's when meeting,
    /// and absent entirely for a visitor. Nothing may assume this exists.
    var flight: Flight?
    var stage: JourneyStage
    var locationNodeID: String
    var hasCheckedBags: Bool
    var homeAddress: String
    /// Who they're here to meet, when they've said.
    var meetingName: String?

    /// Only a departing passenger who has cleared security is airside.
    var zone: Zone {
        guard mode == .departing else { return .landside }
        return stage >= .airside ? .airside : .landside
    }

    var hasAnchor: Bool { flight != nil }
}
