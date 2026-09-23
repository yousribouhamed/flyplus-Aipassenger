import SwiftUI

// MARK: - White-label deployment configuration
//
// The brief is explicit: "Avoid hard-coding Fly+ branding or Fly+-specific
// terminology into the UX." Everything brand-shaped — name, assistant identity,
// palette, enabled capabilities, service catalogue — arrives through this struct.
// No view below this file may reference a brand by name or a colour by literal.

struct Tenant: Identifiable, Equatable {

    // MARK: Identity
    let id: String
    /// Name shown in the UI chrome. Never "Fly+" at a call site — always `tenant.appName`.
    let appName: String
    /// Assistant identity: "Ask Fly+", "Ask JED", "Airport Assistant"…
    let assistantName: String
    /// Short wordmark drawn in the header lockup when no logo asset is supplied.
    let wordmark: String
    /// Asset-catalogue name of the tenant's logo. `nil` — or a missing asset —
    /// falls back to the text wordmark, so a deployment without artwork still ships.
    var logoAsset: String? = nil
    /// Sub-label under the wordmark, e.g. "Passenger".
    let wordmarkSuffix: String?

    // MARK: Configuration
    let palette: Palette
    let capabilities: Capabilities
    /// Configurable per deployment — a tenant without baggage delivery simply omits it.
    let serviceCatalogue: [ServiceKind]

    // MARK: - Palette
    struct Palette: Equatable {
        let primary: Color
        let onPrimary: Color
        let primarySoft: Color
        let canvasTop: Color
        let canvasBottom: Color
        let surface: Color
        let ink: Color
        let inkMuted: Color
        let hairline: Color
        let success: Color
        let warning: Color
        let danger: Color
        /// Conic stops for the assistant orb. The orb is brand expression, so a
        /// deployment supplies its own hues rather than inheriting an "AI" gradient.
        let orbTints: [Color]
        /// Optional rendered sphere texture shown inside the orb. A deployment
        /// without artwork gets the procedural orb, which looks deliberate rather
        /// than unfinished — so this stays optional.
        var orbTexture: String? = nil

        var canvas: LinearGradient {
            LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Capability flags
    // "Allow capabilities such as Navigation, Explore, Services and specific
    //  service types to be enabled or disabled depending on the deployment."
    struct Capabilities: OptionSet, Equatable {
        let rawValue: Int
        static let navigate         = Capabilities(rawValue: 1 << 0)
        static let explore          = Capabilities(rawValue: 1 << 1)
        static let services         = Capabilities(rawValue: 1 << 2)
        static let voice            = Capabilities(rawValue: 1 << 3)
        static let proactiveAlerts  = Capabilities(rawValue: 1 << 4)
        static let all: Capabilities = [.navigate, .explore, .services, .voice, .proactiveAlerts]
    }

    func has(_ capability: Capabilities) -> Bool { capabilities.contains(capability) }
    func offers(_ kind: ServiceKind) -> Bool { serviceCatalogue.contains(kind) }

    static func == (a: Tenant, b: Tenant) -> Bool { a.id == b.id }
}

// MARK: - Service catalogue

enum ServiceKind: String, CaseIterable, Identifiable {
    case baggageDelivery, meetAndAssist, porter, chauffeur, lounge, fastTrack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baggageDelivery: "Baggage delivery"
        case .meetAndAssist:   "Meet & Assist"
        case .porter:          "Porter"
        case .chauffeur:       "Chauffeur"
        case .lounge:          "Lounge access"
        case .fastTrack:       "Fast Track"
        }
    }

    var blurb: String {
        switch self {
        case .baggageDelivery: "Send your bags straight to your address"
        case .meetAndAssist:   "An agent meets you and walks you through"
        case .porter:          "Someone carries your bags through the terminal"
        case .chauffeur:       "A car waiting when you land"
        case .lounge:          "Rest before boarding"
        case .fastTrack:       "Skip the queue at security"
        }
    }

    var symbol: String {
        switch self {
        case .baggageDelivery: "suitcase"
        case .meetAndAssist:   "person.2"
        case .porter:          "figure.walk.motion"
        case .chauffeur:       "car"
        case .lounge:          "sofa"
        case .fastTrack:       "bolt"
        }
    }
}

// MARK: - The two demo deployments
//
// The white-label requirement asks for one screen proven in two brands using the
// *same component structure*. Home renders both of these unchanged.

extension Tenant {

    /// A. Platform-branded.
    static let flyPlus = Tenant(
        id: "flyplus",
        appName: "Fly+",
        assistantName: "Ask Fly+",
        wordmark: "FLY+",
        logoAsset: "TenantLogo",
        wordmarkSuffix: "Passenger",
        palette: Palette(
            primary:     Color(hex: 0x207CE1),
            onPrimary:   .white,
            primarySoft: Color(hex: 0xE7F1FE),
            canvasTop:   Color(hex: 0xF3F8FF),
            canvasBottom:Color(hex: 0xE9F1FF),
            surface:     .white,
            ink:         Color(hex: 0x0E1B2E),
            inkMuted:    Color(hex: 0x7A8699),
            hairline:    Color(hex: 0xE3EAF4),
            success:     Color(hex: 0x1BA97B),
            warning:     Color(hex: 0xF59E0B),
            danger:      Color(hex: 0xFF5038),
            orbTints:   [Color(hex: 0x207CE1), Color(hex: 0x29BFFF),
                         Color(hex: 0x7C6CF0), Color(hex: 0x4FA3F7)],
            orbTexture: "OrbTexture"
        ),
        capabilities: .all,
        serviceCatalogue: [.baggageDelivery, .meetAndAssist, .porter, .chauffeur]
    )

    /// B. Airport-branded — same framework, different deployment.
    /// Note it also *disables* a capability and carries a different catalogue,
    /// which is the part that proves configuration rather than re-skinning.
    static let jeddahAirport = Tenant(
        id: "jed",
        appName: "JED Assistant",
        assistantName: "Ask JED",
        wordmark: "JED",
        wordmarkSuffix: "Airport Assistant",
        palette: Palette(
            primary:     Color(hex: 0x0F7A5A),
            onPrimary:   .white,
            primarySoft: Color(hex: 0xE4F3ED),
            canvasTop:   Color(hex: 0xF6F8F4),
            canvasBottom:Color(hex: 0xEDF3EC),
            surface:     .white,
            ink:         Color(hex: 0x14241C),
            inkMuted:    Color(hex: 0x7C8A82),
            hairline:    Color(hex: 0xE2EAE4),
            success:     Color(hex: 0x1BA97B),
            warning:     Color(hex: 0xC98A15),
            danger:      Color(hex: 0xC7442E),
            orbTints:   [Color(hex: 0x0F7A5A), Color(hex: 0x34B88A),
                         Color(hex: 0xA8CF6B), Color(hex: 0x12987A)]
        ),
        capabilities: [.navigate, .explore, .services, .voice],   // no proactive alerts
        serviceCatalogue: [.meetAndAssist, .porter, .fastTrack, .lounge]
    )

    static let all: [Tenant] = [.flyPlus, .jeddahAirport]
}
