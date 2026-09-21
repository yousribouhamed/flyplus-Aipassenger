import Foundation

/// A place in the terminal, framed by route and time rather than by category.
///
/// Note `isAirside`. Following Delta's airport map, which labels a destination
/// "After Security", whether a place is landside or airside is more
/// decision-relevant than its distance — a two-minute walk through passport
/// control is not a two-minute walk. Every POI and every route carries the flag.
struct PointOfInterest: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: Category
    let detail: String
    /// Walking minutes from the passenger's current position.
    let walkMinutes: Int
    /// Extra minutes this adds to the journey versus going straight to the gate.
    let detourMinutes: Int
    let isOnRoute: Bool
    let isAirside: Bool
    let isOpenNow: Bool
    let floor: String

    enum Category: String, Sendable {
        case prayerRoom, food, coffee, pharmacy, charging, lounge, restroom, shop, gate, assistance

        var symbol: String {
            switch self {
            case .prayerRoom: "moon.stars.fill"
            case .food:       "fork.knife"
            case .coffee:     "cup.and.saucer.fill"
            case .pharmacy:   "cross.case.fill"
            case .charging:   "bolt.fill"
            case .lounge:     "sofa.fill"
            case .restroom:   "figure.dress.line.vertical.figure"
            case .shop:       "bag.fill"
            case .gate:       "airplane.departure"
            case .assistance: "figure.roll"
            }
        }
    }

    /// Curated POIs for the demo concourse. The research is explicit that a
    /// static floor map with curated POIs is enough for the POC — what is not
    /// acceptable is a confident blue dot in the wrong concourse.
    static let demo: [PointOfInterest] = [
        .init(id: "prayer-b", name: "Prayer room", category: .prayerRoom,
              detail: "Men's and women's · open now", walkMinutes: 2, detourMinutes: 0,
              isOnRoute: true, isAirside: true, isOpenNow: true, floor: "L2"),
        .init(id: "coffee-b", name: "Coffee & food", category: .coffee,
              detail: "3 places on your route", walkMinutes: 3, detourMinutes: 4,
              isOnRoute: true, isAirside: true, isOpenNow: true, floor: "L2"),
        .init(id: "charging-32", name: "Charging point", category: .charging,
              detail: "At the gate", walkMinutes: 6, detourMinutes: 0,
              isOnRoute: true, isAirside: true, isOpenNow: true, floor: "L2"),
        .init(id: "pharmacy-b", name: "Pharmacy", category: .pharmacy,
              detail: "Concourse B, near Gate 28", walkMinutes: 4, detourMinutes: 5,
              isOnRoute: false, isAirside: true, isOpenNow: true, floor: "L2"),
        .init(id: "lounge-b", name: "Wellbeing lounge", category: .lounge,
              detail: "Pay on entry · quiet zone", walkMinutes: 7, detourMinutes: 9,
              isOnRoute: false, isAirside: true, isOpenNow: true, floor: "L1"),
        .init(id: "assistance-b", name: "Meet & Assist desk", category: .assistance,
              detail: "Step-free help to the gate", walkMinutes: 3, detourMinutes: 3,
              isOnRoute: true, isAirside: true, isOpenNow: true, floor: "L2")
    ]

    static func demo(_ id: String) -> PointOfInterest {
        demo.first { $0.id == id } ?? demo[0]
    }
}

/// One segment of a walking route.
struct RouteLeg: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    /// Minutes of walking to reach this node from the previous one.
    let walkMinutes: Int
    /// How long the passenger is assumed to spend *at* this node.
    ///
    /// The research leaves this open — a prayer is not a coffee — and
    /// recommends asking, learning, or stating the assumption. The POC states
    /// it: nine minutes for a prayer stop, and the deadline guard means an
    /// over-run is caught rather than silently eating the buffer.
    let dwellMinutes: Int
    let kind: Kind

    enum Kind: Sendable { case origin, stop, destination }

    init(id: String, name: String, detail: String, walkMinutes: Int, dwellMinutes: Int = 0, kind: Kind) {
        self.id = id
        self.name = name
        self.detail = detail
        self.walkMinutes = walkMinutes
        self.dwellMinutes = dwellMinutes
        self.kind = kind
    }
}

/// A walking route through the terminal.
///
/// The POC draws this from a static floor map, a curated POI set and a simple
/// routing graph. The *design* is the production experience on purpose — the
/// scope document asks that the UX be unchanged when a real indoor positioning
/// provider is swapped in — so what is faked is the data, not the interface.
struct RoutePlan: Sendable, Identifiable, Hashable {
    var id: String { destination }

    let destination: String
    let destinationDetail: String
    let totalWalkMinutes: Int
    let distanceMetres: Int
    let isStepFree: Bool
    let floor: String
    /// Landside or airside — stated, per the Delta detail above.
    let isAirside: Bool
    let legs: [RouteLeg]
    /// The next instruction, for turn-by-turn. Every instruction names a
    /// visible landmark, because "80 m" is not verifiable by eye indoors.
    let steps: [NavigationStep]

    var hasStop: Bool { legs.contains { $0.kind == .stop } }

    /// Walking plus time spent at any stop — what the deadline guard is
    /// actually measured against.
    var totalElapsedMinutes: Int {
        legs.reduce(0) { $0 + $1.walkMinutes + $1.dwellMinutes }
    }

    static let toGate = RoutePlan(
        destination: "Gate 32",
        destinationDetail: "Concourse B · Level 2",
        totalWalkMinutes: 8,
        distanceMetres: 540,
        isStepFree: true,
        floor: "L2",
        isAirside: true,
        legs: [
            .init(id: "you", name: "You are here", detail: "Concourse B, near Gate 24", walkMinutes: 0, kind: .origin),
            .init(id: "gate", name: "Gate 32", detail: "Concourse B · Level 2", walkMinutes: 8, kind: .destination)
        ],
        steps: NavigationStep.demoToGate
    )

    static let viaPrayerRoom = RoutePlan(
        destination: "Gate 32",
        destinationDetail: "via Prayer room",
        totalWalkMinutes: 8,
        distanceMetres: 620,
        isStepFree: true,
        floor: "L2",
        isAirside: true,
        legs: [
            .init(id: "you", name: "You are here", detail: "Concourse B, near Gate 24", walkMinutes: 0, kind: .origin),
            .init(id: "prayer", name: "Prayer room", detail: "Stay as long as you need", walkMinutes: 2, dwellMinutes: 9, kind: .stop),
            .init(id: "gate", name: "Gate 32", detail: "Concourse B · Level 2", walkMinutes: 6, kind: .destination)
        ],
        steps: NavigationStep.demoToGate
    )

    static let toNewGate = RoutePlan(
        destination: "Gate 41",
        destinationDetail: "Concourse C · one floor up",
        totalWalkMinutes: 11,
        distanceMetres: 760,
        isStepFree: true,
        floor: "L3",
        isAirside: true,
        legs: [
            .init(id: "you", name: "Prayer room", detail: "You are here", walkMinutes: 0, kind: .origin),
            .init(id: "gate", name: "Gate 41", detail: "Concourse C · one floor up", walkMinutes: 11, kind: .destination)
        ],
        steps: NavigationStep.demoToNewGate
    )
}

/// A single turn-by-turn instruction.
struct NavigationStep: Sendable, Identifiable, Hashable {
    let id: Int
    let instruction: String
    /// The landmark that makes the instruction checkable by eye.
    let landmark: String
    let distanceMetres: Int
    let symbol: String

    static let demoToGate: [NavigationStep] = [
        .init(id: 0, instruction: "Continue straight", landmark: "past the duty free", distanceMetres: 80, symbol: "arrow.up"),
        .init(id: 1, instruction: "Turn right", landmark: "at the escalator", distanceMetres: 120, symbol: "arrow.turn.up.right"),
        .init(id: 2, instruction: "Continue straight", landmark: "along the window wall", distanceMetres: 140, symbol: "arrow.up"),
        .init(id: 3, instruction: "Gate 32 is ahead", landmark: "on your left, past the water point", distanceMetres: 80, symbol: "flag.checkered")
    ]

    static let demoToNewGate: [NavigationStep] = [
        .init(id: 0, instruction: "Turn left out of the prayer room", landmark: "towards the atrium", distanceMetres: 60, symbol: "arrow.turn.up.left"),
        .init(id: 1, instruction: "Take the lift to Level 3", landmark: "beside the information desk", distanceMetres: 40, symbol: "arrow.up.square"),
        .init(id: 2, instruction: "Follow Concourse C", landmark: "past the prayer hall entrance", distanceMetres: 320, symbol: "arrow.up"),
        .init(id: 3, instruction: "Gate 41 is ahead", landmark: "on your right", distanceMetres: 120, symbol: "flag.checkered")
    ]
}

/// Confidence in the indoor position fix.
///
/// Drawing a confident dot in the wrong concourse erodes trust immediately and
/// often permanently, so uncertainty is a designed state with an escape hatch,
/// not an edge case that falls through to the confident layout.
enum PositionConfidence: Sendable {
    case good
    case uncertain

    var message: String? {
        switch self {
        case .good: nil
        case .uncertain: "We're not certain where you are. Walk a few steps, or set your location."
        }
    }
}
