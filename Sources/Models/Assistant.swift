import Foundation

// MARK: - The response kit

/// The closed set of things the assistant is allowed to draw.
///
/// This enum is the contract between design and the model. Whatever generates
/// responses can emit only these components, with these fields — which is what
/// makes an AI-driven interface predictable, translatable, themeable and safe.
/// A model that can only return a confirmation card cannot accidentally spend
/// someone's money in a sentence.
///
/// Adding a case here is a design decision, not an implementation detail.
enum ResponseComponent: Identifiable, Hashable, Sendable {
    /// The journey itself, at two densities.
    case flightCard(Flight, FlightDensity)
    /// The gate as a destination: where it is, how far, how long you have.
    case gateCard(Flight, walkMinutes: Int)
    /// "What matters now" — the block that changes with every journey state.
    case journeyStatus
    /// A route offered or in progress.
    case navigation(RoutePlan)
    /// The hero interaction: a route with an intermediate waypoint and a
    /// deadline guard. The brief's own example had no component for it.
    case multiStop(RoutePlan)
    /// A single place, framed by route and time rather than category.
    case poi(PointOfInterest)
    /// A short ranked set, ordered by time cost — never by alphabet or by rent.
    case nearby(heading: String, places: [PointOfInterest])
    /// The one thing the system actually recommends doing next.
    case recommendation(Recommendation)
    /// Something the platform can do, with price and window stated up front.
    case service(ServiceOffer)
    /// The trust gate before anything irreversible.
    case confirmation(ServiceDraft)
    /// Something changed and it affects the plan.
    case alert(ChangeAlert)
    /// Recovery when the journey has gone wrong.
    case help(HelpTopic)
    /// A guess with a correction path, for low-confidence understanding.
    case clarification(Clarification)

    enum FlightDensity: Sendable { case compact, full }

    var id: String {
        switch self {
        case .flightCard(let f, let d):  "flight-\(f.number)-\(d)"
        case .gateCard(let f, _):        "gate-\(f.gate)"
        case .journeyStatus:             "journey-status"
        case .navigation(let r):         "nav-\(r.id)"
        case .multiStop(let r):          "multistop-\(r.id)"
        case .poi(let p):                "poi-\(p.id)"
        case .nearby(let h, _):          "nearby-\(h)"
        case .recommendation(let r):     "rec-\(r.id)"
        case .service(let s):            "service-\(s.id)"
        case .confirmation(let d):       "confirm-\(d.offer.id)"
        case .alert(let a):              "alert-\(a.id)"
        case .help(let h):               "help-\(h.id)"
        case .clarification(let c):      "clarify-\(c.id)"
        }
    }
}

/// The single recommendation on "what should I do next?".
struct Recommendation: Sendable, Identifiable, Hashable {
    let id: String
    let headline: String
    let rationale: String
    let actionLabel: String
    let destination: AssistantDestination
}

/// Something changed and it affects the plan.
///
/// Structured as the inverse of an alert: the fact, then the *personal*
/// consequence, then the fix. An alert that states a fact and leaves the
/// arithmetic to a stressed passenger has done the easy half of the job.
struct ChangeAlert: Sendable, Identifiable, Hashable {
    let id: String
    let what: String
    let from: String
    let minutesAgo: Int
    /// What it means for this passenger, not what it means in general.
    let consequence: String
    let revisedRoute: RoutePlan
    let acceptLabel: String
    /// "Keep the old route" matters more than it looks. Gate feeds are wrong
    /// often enough that the passenger must be able to overrule the system.
    let overruleLabel: String
    /// The cheapest trust device available: where the change came from, and
    /// when. When the airport's own screens disagree, the passenger can work
    /// out which one is stale.
    let provenance: String

    static let gateChange = ChangeAlert(
        id: "gate-32-to-41",
        what: "Now Gate 41",
        from: "Moved from Gate 32",
        minutesAgo: 4,
        consequence: "It's 11 minutes away from the prayer room instead of 6. You still have time, but leave by 17:29 rather than 17:34.",
        revisedRoute: .toNewGate,
        acceptLabel: "Update my route",
        overruleLabel: "Keep the old route",
        provenance: "Source: Jeddah airport operations, 17:15"
    )
}

/// Recovery when the journey has gone wrong. Help is a destination the
/// assistant can open, not a settings row you find after the app has failed you.
struct HelpTopic: Sendable, Identifiable, Hashable {
    let id: String
    let problem: String
    let whatFlyPlusCanDo: [String]
    let whatNeedsAHuman: String
    let escalateLabel: String
    let reference: String

    static let missedConnection = HelpTopic(
        id: "running-late",
        problem: "You think you're going to miss SV117",
        whatFlyPlusCanDo: [
            "Show the fastest step-free route to Gate 32",
            "Tell the gate you're on your way",
            "Hold your baggage delivery booking"
        ],
        whatNeedsAHuman: "Rebooking onto a later flight has to go through Saudia.",
        escalateLabel: "Call a Fly+ agent",
        reference: "FP-4417-SV117"
    )
}

/// A guess stated as a guess, with one-tap correction. Faster and usually
/// kinder than a blank re-ask.
struct Clarification: Sendable, Identifiable, Hashable {
    let id: String
    let interpretation: String
    let alternatives: [String]
}

// MARK: - Where a response can send the interface

/// The assistant changes the interface rather than describing it. "Take me to
/// my gate" opens navigation; it does not reply "Sure, tap Navigate".
enum AssistantDestination: Hashable, Sendable {
    case stay
    case home
    case explore
    case flightDetail
    case routeOverview(RoutePlan)
    case turnByTurn(RoutePlan)
    case multiStop(RoutePlan)
    case serviceFlow(ServiceOffer)
    case help(HelpTopic)
    case disruption(ChangeAlert)
}

struct AssistantAction: Sendable, Hashable {
    let label: String
    let destination: AssistantDestination
}

/// One assembled answer. The spoken answer and the written answer are the same
/// words — if voice says something the screen does not, the passenger has to
/// choose which to trust.
struct AssistantResponse: Sendable, Identifiable, Hashable {
    var id: String { transcript }

    let transcript: String
    /// What the system is reasoning about, named rather than a spinner.
    let reasoning: String
    let answer: String
    let components: [ResponseComponent]
    let primary: AssistantAction?
    /// Always offer the plain alternative. This is how the passenger disagrees
    /// with the AI without arguing with it.
    let alternative: AssistantAction?
    let isLowConfidence: Bool

    init(
        transcript: String,
        reasoning: String,
        answer: String,
        components: [ResponseComponent] = [],
        primary: AssistantAction? = nil,
        alternative: AssistantAction? = nil,
        isLowConfidence: Bool = false
    ) {
        self.transcript = transcript
        self.reasoning = reasoning
        self.answer = answer
        self.components = components
        self.primary = primary
        self.alternative = alternative
        self.isLowConfidence = isLowConfidence
    }
}

/// How a voice interaction can fail. Each failure has a different recovery —
/// "sorry, I didn't get that" for all five is how assistants lose people.
enum VoiceFailure: Sendable, Hashable, CaseIterable, Identifiable {
    case noSpeech
    case notUnderstood
    case outOfScope
    case noNetwork

    var id: String { message }

    var message: String {
        switch self {
        case .noSpeech:      "I didn't catch anything."
        case .notUnderstood: "I couldn't hear that clearly."
        case .outOfScope:    "I can't do that here, but I can find it in the terminal or get you to your gate."
        case .noNetwork:     "I can't check live info right now — here's what I last knew."
        }
    }

    var recovery: [String] {
        switch self {
        case .noSpeech:      ["Try again", "Type instead"]
        case .notUnderstood: ["Try again", "Type instead"]
        case .outOfScope:    ["Explore nearby", "Help"]
        case .noNetwork:     ["Retry", "Show cached flight"]
        }
    }

    var symbol: String {
        switch self {
        case .noSpeech:      "mic.slash"
        case .notUnderstood: "waveform.badge.exclamationmark"
        case .outOfScope:    "questionmark.circle"
        case .noNetwork:     "wifi.slash"
        }
    }
}
