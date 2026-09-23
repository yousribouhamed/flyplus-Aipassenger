import CoreGraphics
import Foundation

// MARK: - Points of interest

enum POICategory: String, CaseIterable, Identifiable {
    case gate, prayer, food, lounge, restroom, pharmacy, shopping, charging, help, security, baggage
    case arrivals, parking, transport, atm, checkin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gate: "Gates"
        case .prayer: "Prayer rooms"
        case .food: "Food & drink"
        case .lounge: "Lounges"
        case .restroom: "Restrooms"
        case .pharmacy: "Pharmacy"
        case .shopping: "Shopping"
        case .charging: "Charging"
        case .help: "Help"
        case .security: "Security"
        case .baggage: "Baggage"
        case .arrivals: "Arrivals"
        case .parking: "Parking"
        case .transport: "Transport"
        case .atm: "Cash & banking"
        case .checkin: "Check-in"
        }
    }

    var symbol: String {
        switch self {
        case .gate: "airplane.departure"
        case .prayer: "moon.stars"
        case .food: "cup.and.saucer"
        case .lounge: "sofa"
        case .restroom: "figure.dress.line.vertical.figure"
        case .pharmacy: "cross.case"
        case .shopping: "bag"
        case .charging: "bolt.batteryblock"
        case .help: "questionmark.circle"
        case .security: "shield.lefthalf.filled"
        case .baggage: "suitcase.rolling"
        case .arrivals: "figure.walk.arrival"
        case .parking: "parkingsign"
        case .transport: "bus"
        case .atm: "banknote"
        case .checkin: "person.text.rectangle"
        }
    }

    /// Categories a passenger browses in Explore. Gates/security are wayfinding, not destinations to browse.
    static var browsable: [POICategory] { [.food, .prayer, .lounge, .restroom, .pharmacy, .shopping, .charging, .help] }
    /// What a visitor landside actually comes for.
    static var landsideBrowsable: [POICategory] { [.arrivals, .food, .shopping, .atm, .parking, .transport, .pharmacy, .help, .prayer, .restroom] }
}

struct POI: Identifiable, Equatable {
    let id: String            // matches a MapNode id
    let name: String
    let category: POICategory
    let detail: String
    /// Typical time spent here — the thing that actually makes a detour cost time.
    let dwellMinutes: Int
    let openNow: Bool
    var zone: Zone = .airside
}

// MARK: - Routable graph
//
// §16 of the PDF: the POC needs a simple routing graph over known POIs, not a
// production indoor-positioning stack. Edge distances are authored in metres so
// the journey maths stays exact; node coordinates exist only for drawing.

struct MapNode: Identifiable, Equatable {
    let id: String
    let name: String
    /// Where the node sits on the walkable network — in a 0…1000 design space.
    let point: CGPoint
    let floor: Int
    /// Which side of security this sits on. Defaults to airside because the
    /// original POC map was entirely post-security.
    var zone: Zone = .airside
    /// The unit's physical footprint on the floor plan. A real terminal is made
    /// of rooms and tenancies, not dots; POIs that occupy space carry a rect and
    /// are drawn as architecture. Junctions have none.
    var footprint: CGRect? = nil
}

/// A wall/boundary segment of the terminal envelope, drawn beneath everything.
struct FloorPlate: Equatable {
    /// Outline of the walkable floor, in design space, as a closed polygon.
    let outline: [CGPoint]
    /// Corridor centre-lines, drawn as wide light bands to read as walkable space.
    let corridors: [[CGPoint]]
}

struct MapEdge: Equatable {
    let a: String
    let b: String
    let metres: Double
    /// A step-free edge is usable by an accessible route; a stair/escalator is not.
    let stepFree: Bool
}

struct AirportMap {
    let name: String
    let terminal: String
    var timeZoneID: String = "Asia/Riyadh"
    let nodes: [MapNode]
    let edges: [MapEdge]
    let pois: [POI]
    /// The building itself. Without it the map is a graph diagram, not a floor plan.
    var plate: FloorPlate = FloorPlate(outline: [], corridors: [])
    /// The landside hall. Kept separate because the two levels never connect in
    /// a way a visitor may walk — security is a one-way door they cannot use.
    var landsidePlate: FloorPlate = FloorPlate(outline: [], corridors: [])

    func plate(for zone: Zone) -> FloorPlate { zone == .airside ? plate : landsidePlate }

    /// The terminal label depends on which side you're on — telling a visitor in
    /// the arrivals hall that they're "Airside" is simply wrong.
    func terminalLabel(for zone: Zone) -> String {
        zone == .airside ? terminal : "Terminal 1 · Arrivals"
    }

    func floor(for zone: Zone) -> Int { zone == .airside ? 2 : 1 }
    func nodes(in zone: Zone) -> [MapNode] { nodes.filter { $0.zone == zone } }
    func pois(in zone: Zone) -> [POI] { pois.filter { $0.zone == zone } }

    /// Average walking pace, metres per minute. Deliberately conservative —
    /// the passenger may be carrying baggage (§4).
    static let paceMetresPerMinute: Double = 75

    func node(_ id: String) -> MapNode? { nodes.first { $0.id == id } }
    func poi(_ id: String) -> POI? { pois.first { $0.id == id } }

    static func minutes(forMetres m: Double) -> Int {
        max(1, Int((m / paceMetresPerMinute).rounded()))
    }
}

// MARK: - The POC airport: JED Terminal 1, airside level
//
// Distances are tuned so the brief's own numbers fall out of the router rather
// than being printed as copy: Gate 32 is 8 min from security exit, the prayer
// room 2 min, coffee 3 min, the lounge 5 min — and the prayer room sits exactly
// on the gate route, which is what makes the hero interaction work.

extension AirportMap {
    static let jeddah = AirportMap(
        name: "King Abdulaziz International",
        terminal: "Terminal 1 · Airside",
        nodes: [
            // — Concourse spine
            MapNode(id: "security_exit", name: "Security Exit",  point: CGPoint(x: 120, y: 570), floor: 2,
                    footprint: CGRect(x: 88, y: 520, width: 78, height: 100)),
            MapNode(id: "hall_a",        name: "Central Hall",   point: CGPoint(x: 300, y: 570), floor: 2),
            MapNode(id: "hall_b",        name: "Duty Free Hall", point: CGPoint(x: 520, y: 570), floor: 2),
            MapNode(id: "corridor",      name: "Pier Junction",  point: CGPoint(x: 700, y: 570), floor: 2),
            MapNode(id: "pier",          name: "Gate Hall",      point: CGPoint(x: 830, y: 570), floor: 2),

            // — Tenancies north of the concourse
            MapNode(id: "prayer",   name: "Prayer Room",     point: CGPoint(x: 300, y: 440), floor: 2,
                    footprint: CGRect(x: 240, y: 392, width: 122, height: 96)),
            MapNode(id: "lounge",   name: "Alfursan Lounge", point: CGPoint(x: 520, y: 440), floor: 2,
                    footprint: CGRect(x: 452, y: 392, width: 146, height: 96)),
            MapNode(id: "shop",     name: "Duty Free",       point: CGPoint(x: 630, y: 452), floor: 2,
                    footprint: CGRect(x: 606, y: 392, width: 78, height: 96)),
            MapNode(id: "charging", name: "Charging Point",  point: CGPoint(x: 762, y: 492), floor: 2,
                    footprint: CGRect(x: 730, y: 452, width: 68, height: 58)),

            // — Tenancies south of the concourse
            MapNode(id: "cafe",     name: "Qahwa House",     point: CGPoint(x: 300, y: 700), floor: 2,
                    footprint: CGRect(x: 244, y: 656, width: 114, height: 92)),
            MapNode(id: "restroom", name: "Restrooms",       point: CGPoint(x: 412, y: 700), floor: 2,
                    footprint: CGRect(x: 374, y: 656, width: 84, height: 92)),
            MapNode(id: "pharmacy", name: "Pharmacy",        point: CGPoint(x: 520, y: 700), floor: 2,
                    footprint: CGRect(x: 472, y: 656, width: 104, height: 92)),
            MapNode(id: "help",     name: "Information",     point: CGPoint(x: 762, y: 652), floor: 2,
                    footprint: CGRect(x: 730, y: 624, width: 68, height: 58)),

            // — Gates, arranged along the pier
            MapNode(id: "gate30", name: "Gate 30", point: CGPoint(x: 830, y: 400), floor: 2,
                    footprint: CGRect(x: 772, y: 344, width: 120, height: 78)),
            MapNode(id: "gate31", name: "Gate 31", point: CGPoint(x: 940, y: 570), floor: 2,
                    footprint: CGRect(x: 886, y: 532, width: 84, height: 78)),
            MapNode(id: "gate32", name: "Gate 32", point: CGPoint(x: 830, y: 740), floor: 2,
                    footprint: CGRect(x: 772, y: 716, width: 120, height: 78)),

            // — Landside: the arrivals hall and forecourt, where visitors are.
            MapNode(id: "entrance",   name: "Main Entrance",  point: CGPoint(x: 140, y: 570), floor: 1, zone: .landside,
                    footprint: CGRect(x: 96, y: 520, width: 92, height: 100)),
            MapNode(id: "hall_l1",    name: "Arrivals Hall",  point: CGPoint(x: 320, y: 570), floor: 1, zone: .landside),
            MapNode(id: "hall_l2",    name: "Central Hall",   point: CGPoint(x: 540, y: 570), floor: 1, zone: .landside),
            MapNode(id: "hall_l3",    name: "East Hall",      point: CGPoint(x: 720, y: 570), floor: 1, zone: .landside),

            MapNode(id: "arrivals_a", name: "Arrivals A",     point: CGPoint(x: 320, y: 430), floor: 1, zone: .landside,
                    footprint: CGRect(x: 256, y: 384, width: 128, height: 92)),
            MapNode(id: "meeting",    name: "Meeting Point",  point: CGPoint(x: 540, y: 430), floor: 1, zone: .landside,
                    footprint: CGRect(x: 480, y: 384, width: 120, height: 92)),
            MapNode(id: "arrivals_b", name: "Arrivals B",     point: CGPoint(x: 720, y: 430), floor: 1, zone: .landside,
                    footprint: CGRect(x: 656, y: 384, width: 128, height: 92)),

            MapNode(id: "cafe_l",     name: "Costa Coffee",   point: CGPoint(x: 320, y: 700), floor: 1, zone: .landside,
                    footprint: CGRect(x: 262, y: 656, width: 116, height: 92)),
            MapNode(id: "atm",        name: "ATM",            point: CGPoint(x: 448, y: 700), floor: 1, zone: .landside,
                    footprint: CGRect(x: 414, y: 656, width: 68, height: 92)),
            MapNode(id: "info_l",     name: "Information",    point: CGPoint(x: 540, y: 700), floor: 1, zone: .landside,
                    footprint: CGRect(x: 504, y: 656, width: 72, height: 92)),
            MapNode(id: "shop_l",     name: "Airport Shop",   point: CGPoint(x: 636, y: 700), floor: 1, zone: .landside,
                    footprint: CGRect(x: 598, y: 656, width: 76, height: 92)),
            MapNode(id: "pharmacy_l", name: "Pharmacy",       point: CGPoint(x: 720, y: 700), floor: 1, zone: .landside,
                    footprint: CGRect(x: 690, y: 656, width: 64, height: 92)),

            MapNode(id: "carpark",    name: "Short-stay P1",  point: CGPoint(x: 890, y: 470), floor: 1, zone: .landside,
                    footprint: CGRect(x: 836, y: 410, width: 110, height: 104)),
            MapNode(id: "taxi",       name: "Taxi Rank",      point: CGPoint(x: 890, y: 670), floor: 1, zone: .landside,
                    footprint: CGRect(x: 836, y: 616, width: 110, height: 104)),
        ],
        edges: [
            // Spine: security → hall_a → hall_b → corridor → pier → gate 32 = 600 m = 8 min
            MapEdge(a: "security_exit", b: "hall_a",   metres: 150, stepFree: true),
            MapEdge(a: "hall_a",        b: "hall_b",   metres: 225, stepFree: true),
            MapEdge(a: "hall_b",        b: "corridor", metres: 110, stepFree: true),
            MapEdge(a: "corridor",      b: "pier",     metres:  40, stepFree: true),
            MapEdge(a: "pier",          b: "gate32",   metres:  75, stepFree: true),
            // Prayer room opens straight off the concourse → 2 min from security.
            MapEdge(a: "hall_a",        b: "prayer",   metres:   8, stepFree: true),
            // Coffee: 3 min.
            MapEdge(a: "hall_a",        b: "cafe",     metres:  75, stepFree: true),
            MapEdge(a: "cafe",          b: "restroom", metres:  60, stepFree: true),
            MapEdge(a: "restroom",      b: "hall_b",   metres: 110, stepFree: true),
            // Lounge: 5 min.
            MapEdge(a: "hall_b",        b: "lounge",   metres:  30, stepFree: true),
            MapEdge(a: "hall_b",        b: "pharmacy", metres:  45, stepFree: true),
            MapEdge(a: "hall_b",        b: "shop",     metres:  90, stepFree: false),  // escalator
            MapEdge(a: "shop",          b: "corridor", metres:  80, stepFree: true),
            MapEdge(a: "corridor",      b: "help",     metres:  25, stepFree: true),
            MapEdge(a: "corridor",      b: "charging", metres:  70, stepFree: true),
            MapEdge(a: "pier",          b: "gate31",   metres: 110, stepFree: true),
            MapEdge(a: "pier",          b: "gate30",   metres: 150, stepFree: true),

            // — Landside. Deliberately no edge crosses into the airside set:
            //   a visitor cannot walk through security, and the router must not
            //   be able to pretend otherwise.
            MapEdge(a: "entrance",   b: "hall_l1",    metres: 120, stepFree: true),
            MapEdge(a: "hall_l1",    b: "hall_l2",    metres: 150, stepFree: true),
            MapEdge(a: "hall_l2",    b: "hall_l3",    metres: 130, stepFree: true),
            MapEdge(a: "hall_l1",    b: "arrivals_a", metres:  60, stepFree: true),
            MapEdge(a: "hall_l2",    b: "meeting",    metres:  50, stepFree: true),
            MapEdge(a: "hall_l3",    b: "arrivals_b", metres:  60, stepFree: true),
            MapEdge(a: "hall_l1",    b: "cafe_l",     metres:  45, stepFree: true),
            MapEdge(a: "hall_l2",    b: "atm",        metres:  55, stepFree: true),
            MapEdge(a: "hall_l2",    b: "info_l",     metres:  40, stepFree: true),
            MapEdge(a: "hall_l3",    b: "shop_l",     metres:  60, stepFree: true),
            MapEdge(a: "hall_l3",    b: "pharmacy_l", metres:  50, stepFree: true),
            MapEdge(a: "hall_l3",    b: "carpark",    metres: 140, stepFree: false),
            MapEdge(a: "hall_l3",    b: "taxi",       metres: 130, stepFree: true),
        ],
        pois: [
            POI(id: "prayer",   name: "Prayer Room",     category: .prayer,   detail: "Men's & women's, ablution facilities", dwellMinutes: 10, openNow: true),
            POI(id: "cafe",     name: "Qahwa House",     category: .food,     detail: "Saudi coffee, pastries",               dwellMinutes:  8, openNow: true),
            POI(id: "lounge",   name: "Alfursan Lounge", category: .lounge,   detail: "SAUDIA lounge · hot food, showers",    dwellMinutes: 35, openNow: true),
            POI(id: "restroom", name: "Restrooms",       category: .restroom, detail: "Step-free access",                     dwellMinutes:  5, openNow: true),
            POI(id: "pharmacy", name: "Pharmacy",        category: .pharmacy, detail: "Travel essentials, prescriptions",     dwellMinutes:  7, openNow: true),
            POI(id: "shop",     name: "Duty Free",       category: .shopping, detail: "Perfume, gifts, electronics",          dwellMinutes: 15, openNow: true),
            POI(id: "charging", name: "Charging Point",  category: .charging, detail: "USB-C & wireless",                     dwellMinutes: 12, openNow: true),
            POI(id: "help",     name: "Information Desk",category: .help,     detail: "Airport staff, lost property",         dwellMinutes:  6, openNow: true),
            POI(id: "gate32",   name: "Gate 32",         category: .gate,     detail: "SV117 to London Heathrow",             dwellMinutes:  0, openNow: true),
            POI(id: "gate31",   name: "Gate 31",         category: .gate,     detail: "",                                     dwellMinutes:  0, openNow: true),
            POI(id: "gate30",   name: "Gate 30",         category: .gate,     detail: "",                                     dwellMinutes:  0, openNow: true),

            // — Landside
            POI(id: "arrivals_a", name: "Arrivals A",    category: .arrivals,  detail: "International arrivals exit",          dwellMinutes:  0, openNow: true, zone: .landside),
            POI(id: "arrivals_b", name: "Arrivals B",    category: .arrivals,  detail: "International arrivals exit",          dwellMinutes:  0, openNow: true, zone: .landside),
            POI(id: "meeting",    name: "Meeting Point", category: .help,      detail: "Seating, screens, staffed desk",       dwellMinutes:  0, openNow: true, zone: .landside),
            POI(id: "cafe_l",     name: "Costa Coffee",  category: .food,      detail: "Coffee, sandwiches",                   dwellMinutes:  8, openNow: true, zone: .landside),
            POI(id: "atm",        name: "ATM",           category: .atm,       detail: "Cash & currency exchange",             dwellMinutes:  4, openNow: true, zone: .landside),
            POI(id: "info_l",     name: "Information",   category: .help,      detail: "Airport staff, lost property",         dwellMinutes:  6, openNow: true, zone: .landside),
            POI(id: "shop_l",     name: "Airport Shop",  category: .shopping,  detail: "Gifts, travel essentials",             dwellMinutes: 12, openNow: true, zone: .landside),
            POI(id: "pharmacy_l", name: "Pharmacy",      category: .pharmacy,  detail: "Travel essentials, prescriptions",     dwellMinutes:  7, openNow: true, zone: .landside),
            POI(id: "carpark",    name: "Short-stay P1", category: .parking,   detail: "First 30 min free",                    dwellMinutes:  0, openNow: true, zone: .landside),
            POI(id: "taxi",       name: "Taxi Rank",     category: .transport, detail: "Metered taxis & ride-hail pickup",     dwellMinutes:  0, openNow: true, zone: .landside),
        ],
        // The building envelope: a concourse with a gate pier off its eastern end.
        plate: FloorPlate(
            outline: [
                CGPoint(x:  80, y: 372), CGPoint(x: 700, y: 372),
                CGPoint(x: 700, y: 300), CGPoint(x: 980, y: 300),
                CGPoint(x: 980, y: 840), CGPoint(x: 700, y: 840),
                CGPoint(x: 700, y: 768), CGPoint(x:  80, y: 768),
            ],
            corridors: [
                [CGPoint(x: 120, y: 570), CGPoint(x: 830, y: 570)],   // concourse + pier spine
                [CGPoint(x: 830, y: 400), CGPoint(x: 830, y: 740)],   // gate hall
                [CGPoint(x: 940, y: 570), CGPoint(x: 830, y: 570)],
            ]
        ),
        // Arrivals level: one long hall between the entrance and the forecourt.
        landsidePlate: FloorPlate(
            outline: [
                CGPoint(x:  80, y: 356), CGPoint(x: 800, y: 356),
                CGPoint(x: 800, y: 380), CGPoint(x: 966, y: 380),
                CGPoint(x: 966, y: 752), CGPoint(x: 800, y: 752),
                CGPoint(x: 800, y: 776), CGPoint(x:  80, y: 776),
            ],
            corridors: [
                [CGPoint(x: 140, y: 570), CGPoint(x: 890, y: 570)],
                [CGPoint(x: 890, y: 470), CGPoint(x: 890, y: 670)],
            ]
        )
    )
}
