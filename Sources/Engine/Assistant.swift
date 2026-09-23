import Foundation

// MARK: - What the assistant can put on screen
//
// §21: "Create reusable design-system components that the assistant can trigger …
//  A response should be able to produce: Conversation + Voice + Structured UI + Action
//  rather than only text."
//
// So a response is never a string. It is: speech + cards + an interface command.

enum AssistantCard: Identifiable, Equatable {
    case flight                                   // the current flight, expanded
    case journeyStatus                            // now/next + schedule verdict
    case route(Route)                             // route overview, incl. multi-stop
    case poi([POI])                               // one or more places
    case nearby([ExploreResult])                  // ranked recommendations
    case service(ServiceKind)                     // a bookable service
    case confirmation(ConfirmationRequest)        // consequential action gate
    case help(String)                             // escalation to a human

    var id: String {
        switch self {
        case .flight: "flight"
        case .journeyStatus: "status"
        case .route(let r): "route-\(r.nodes.map(\.id).joined())"
        case .poi(let p): "poi-\(p.map(\.id).joined())"
        case .nearby(let n): "nearby-\(n.map(\.poi.id).joined())"
        case .service(let s): "service-\(s.rawValue)"
        case .confirmation(let c): "confirm-\(c.title)"
        case .help(let s): "help-\(s)"
        }
    }
}

/// §19: "Voice may initiate actions, but consequential actions must require
/// explicit confirmation. Do not execute consequential actions solely because
/// the AI interpreted a spoken request."
struct ConfirmationRequest: Equatable {
    let title: String
    let body: String
    let confirmLabel: String
    let cancelLabel: String
    let isDestructive: Bool
    let service: ServiceKind?
}

/// The interface command. This is what makes conversation drive the UI.
enum AssistantCommand: Equatable {
    case none
    case openNavigation(Route)
    case openExplore(POICategory?)
    case openServiceFlow(ServiceKind)
    case expandFlight
}

struct AssistantResponse: Identifiable, Equatable {
    let id = UUID()
    /// What is spoken aloud and shown as the assistant's line.
    let speech: String
    let cards: [AssistantCard]
    let command: AssistantCommand
    /// Follow-up chips — §11 "Ask another question".
    let followUps: [String]
}

struct AssistantTurn: Identifiable, Equatable {
    let id = UUID()
    let question: String
    let response: AssistantResponse
}

// MARK: - Explore ranking
//
// §16: "Prioritize: Nearby · Relevant · On my route · I have time for this"
// — deliberately not distance alone.

struct ExploreResult: Identifiable, Equatable {
    let poi: POI
    let walkMinutes: Int
    let feasibility: TimingEngine.Feasibility
    var id: String { poi.id }

    var subtitle: String {
        if feasibility.isUnbounded { return "\(walkMinutes) min away · \(poi.detail)" }
        if feasibility.isOnRoute { return "\(walkMinutes) min · On your route" }
        return "\(walkMinutes) min · Adds ~\(feasibility.addedWalkMinutes) min"
    }
}

// MARK: - The assistant
//
// Deterministic intent resolution over the real engines. The POC does not call a
// model: every number it says comes from TimingEngine or RoutingEngine, which is
// exactly the split the brief asks for. Swapping in an LLM later means replacing
// `resolve` — the response shape, cards and commands stay as they are.

struct Assistant {
    let map: AirportMap
    let router: RoutingEngine
    let tenant: Tenant

    func resolve(_ raw: String, context: PassengerContext, now: Date) -> AssistantResponse {
        let q = raw.lowercased()

        // A visitor has no gate, no boarding time and no budget. Rather than
        // faking one, the whole timing branch simply doesn't apply to them.
        let gateNode = Self.destinationNode(for: context)
        let direct = gateNode.flatMap { router.minutes(from: context.locationNodeID, to: $0) } ?? 0
        let budget = Self.budget(for: context, now: now, directWalk: direct)
        let destination = Self.destinationName(for: context)

        guard let flight = context.flight, let gateNode, let budget else {
            return resolveVisitor(q, context: context, now: now)
        }

        // — Hero interaction (§13): "I want to pray first."
        if matches(q, ["pray", "prayer", "salah", "masjid", "mosque"]) {
            return stopThenGate(poiID: "prayer", context: context, now: now, gateNode: gateNode, direct: direct)
        }

        // — Food, framed as a stop rather than a directory lookup.
        if matches(q, ["coffee", "eat", "food", "hungry", "drink", "cafe", "breakfast", "lunch"]) {
            if matches(q, ["where can i eat", "where to eat", "options", "what food"]) {
                return nearby(category: .food, context: context, now: now, direct: direct,
                              lead: "Here's what's close and still fits your time.")
            }
            return stopThenGate(poiID: "cafe", context: context, now: now, gateNode: gateNode, direct: direct)
        }

        if matches(q, ["lounge"]) {
            return stopThenGate(poiID: "lounge", context: context, now: now, gateNode: gateNode, direct: direct)
        }

        // — "Take me to my gate" / "Where should I go?" (§10: never ask which gate)
        if matches(q, ["my gate", "take me to my gate", "where should i go", "where do i go",
                       "what should i do next", "next", "guide me", "navigate"]) {
            guard let route = router.route(from: context.locationNodeID, to: gateNode) else {
                return fallback()
            }
            let verdict = TimingEngine.scheduleVerdict(budget)
            let speech: String
            if context.stage == .boardingSoon || budget.isBehindSchedule {
                speech = "Head to \(flight.gate) now — it's \(direct) minutes away and boarding starts at \(TimingEngine.clock(flight.boarding))."
            } else {
                speech = "\(flight.gate), \(direct) minutes from here. Boarding starts in \(budget.minutesToBoarding) minutes, so you have about \(budget.availableMinutes) minutes spare. \(verdict)"
            }
            return AssistantResponse(
                speech: speech,
                cards: [.journeyStatus, .route(route)],
                command: .openNavigation(route),
                followUps: ["I want to pray first", "Where can I get coffee?", "How long do I have?"]
            )
        }

        // — Time questions answer from the budget, never from the clock alone.
        if matches(q, ["how long", "how much time", "do i have time", "am i late", "time do i have"]) {
            let speech = budget.isBehindSchedule
                ? "You're tight. Boarding is in \(budget.minutesToBoarding) minutes and \(flight.gate) is \(direct) minutes away — go now."
                : "Boarding is in \(budget.minutesToBoarding) minutes. \(flight.gate) is \(direct) minutes away and I keep \(budget.safetyBufferMinutes) minutes in reserve, so you have about \(budget.availableMinutes) minutes to spare."
            return AssistantResponse(speech: speech, cards: [.journeyStatus], command: .none,
                                     followUps: ["What's nearby?", "Take me to my gate", "I want to pray first"])
        }

        // — Flight questions expand the flight card rather than reciting it.
        if matches(q, ["my flight", "flight status", "show my flight", "is my flight", "delayed", "on time", "gate change"]) {
            return AssistantResponse(
                speech: "\(flight.number) to \(flight.destinationCity) is \(flight.status.rawValue.lowercased()). Boarding at \(TimingEngine.clock(flight.boarding)) from \(flight.gate), departing \(TimingEngine.clock(flight.departure)).",
                cards: [.flight],
                command: .expandFlight,
                followUps: ["Take me to my gate", "How long do I have?"]
            )
        }

        // — Services: guidance becomes a transaction (§18).
        if matches(q, ["bag", "baggage", "luggage", "suitcase", "deliver"]) {
            if matches(q, ["can't find", "cannot find", "lost", "missing", "didn't arrive", "not arrived"]) {
                return AssistantResponse(
                    speech: "I'm sorry — let's sort that out. I can see you're on \(flight.number). The baggage desk is by \(map.node("help")?.name ?? "Information"), and I can raise a missing-bag report with the airport on your behalf.",
                    cards: [.help("Missing baggage"), .poi([map.poi("help")].compactMap { $0 })],
                    command: .none,
                    followUps: ["Take me to the desk", "Report a missing bag"]
                )
            }
            if tenant.offers(.baggageDelivery) {
                return AssistantResponse(
                    speech: "Yes — baggage delivery is available from this airport. I can send your bags to \(context.homeAddress) so you walk out with just your carry-on.",
                    cards: [.service(.baggageDelivery)],
                    command: .openServiceFlow(.baggageDelivery),
                    followUps: ["How much is it?", "Take me to my gate"]
                )
            }
            return AssistantResponse(
                speech: "Baggage delivery isn't offered at this airport yet, but the information desk can help with baggage questions.",
                cards: [.poi([map.poi("help")].compactMap { $0 })], command: .none,
                followUps: ["Take me to the desk"]
            )
        }

        if matches(q, ["meet", "assist", "porter", "chauffeur", "wheelchair", "help me with"]) {
            let kind: ServiceKind = matches(q, ["porter"]) ? .porter
                                  : matches(q, ["chauffeur", "car"]) ? .chauffeur : .meetAndAssist
            if tenant.offers(kind) {
                return AssistantResponse(
                    speech: "\(kind.title) is available here — \(kind.blurb.lowercased()).",
                    cards: [.service(kind)], command: .openServiceFlow(kind),
                    followUps: ["What else can you do?", "Take me to my gate"]
                )
            }
        }

        // — Airport knowledge (§17), always with an action rather than prose directions.
        for category in POICategory.browsable where matches(q, keywords(for: category)) {
            return nearby(category: category, context: context, now: now, direct: direct,
                          lead: "Here's what's closest.")
        }

        if matches(q, ["nearby", "around me", "what's near", "whats near", "explore", "relevant"]) {
            return nearby(category: nil, context: context, now: now, direct: direct,
                          lead: "You have about \(max(0, budget.availableMinutes)) minutes spare. These are close and on your way.")
        }

        if matches(q, ["help", "problem", "staff", "human", "agent", "support"]) {
            return AssistantResponse(
                speech: "I can point you to airport staff, or escalate this to a person if you'd rather talk to someone.",
                cards: [.help("Airport support"), .poi([map.poi("help")].compactMap { $0 })],
                command: .none,
                followUps: ["Take me to the desk", "Talk to a person"]
            )
        }

        return fallback()
    }

    // MARK: Context helpers — the three modes differ only here

    static func destinationNode(for context: PassengerContext) -> String? {
        switch context.mode {
        case .departing:
            guard let gate = context.flight?.gate else { return nil }
            return "gate\(gate.replacingOccurrences(of: "Gate ", with: ""))"
        case .meeting:
            return context.flight?.arrivalsExit == "Arrivals A" ? "arrivals_a" : "arrivals_b"
        case .visiting:
            return nil
        }
    }

    static func destinationName(for context: PassengerContext) -> String {
        switch context.mode {
        case .departing: context.flight?.gate ?? "your gate"
        case .meeting:   context.flight?.arrivalsExit ?? "Arrivals"
        case .visiting:  "the terminal"
        }
    }

    static func budget(for context: PassengerContext, now: Date, directWalk: Int) -> TimingEngine.Budget? {
        guard let flight = context.flight else { return nil }
        switch context.mode {
        case .departing:
            return TimingEngine.budget(now: now, boarding: flight.boarding, walkMinutesToGate: directWalk)
        case .meeting:
            guard let landing = flight.landing else { return nil }
            return TimingEngine.meetingBudget(now: now, landing: landing, walkMinutesToArrivals: directWalk)
        case .visiting:
            return nil
        }
    }

    // MARK: Visitor answers
    //
    // No flight, no deadline, landside only. The assistant stops talking about
    // time and starts talking about place — which is the whole difference.

    private func resolveVisitor(_ q: String, context: PassengerContext, now: Date) -> AssistantResponse {
        if matches(q, ["meet", "pick up", "picking up", "arriv", "landing", "collect someone"]) {
            return AssistantResponse(
                speech: "I can track their flight and tell you when they'll actually come through — landing time isn't the same as walking out. What's the flight number?",
                cards: [.poi([map.poi("meeting")].compactMap { $0 })],
                command: .none,
                followUps: ["Where is Arrivals B?", "Where can I wait?"]
            )
        }

        if matches(q, ["park", "car", "vehicle"]) {
            return nearbyVisitor(category: .parking, context: context, now: now,
                                 lead: "Short-stay is closest to the hall.")
        }
        if matches(q, ["taxi", "uber", "ride", "bus", "train", "transport", "get home", "get to the city"]) {
            return nearbyVisitor(category: .transport, context: context, now: now,
                                 lead: "Here's how to get away from the terminal.")
        }
        if matches(q, ["cash", "atm", "money", "exchange", "currency"]) {
            return nearbyVisitor(category: .atm, context: context, now: now, lead: "Cash is this way.")
        }
        if matches(q, ["coffee", "eat", "food", "drink", "hungry", "cafe"]) {
            return nearbyVisitor(category: .food, context: context, now: now, lead: "Closest place to sit down.")
        }
        if matches(q, ["buy", "shop", "gift", "present"]) {
            return nearbyVisitor(category: .shopping, context: context, now: now, lead: "There's a shop in the hall.")
        }
        if matches(q, ["pharmacy", "chemist", "medicine"]) {
            return nearbyVisitor(category: .pharmacy, context: context, now: now, lead: "Pharmacy is in the east hall.")
        }
        if matches(q, ["toilet", "restroom", "bathroom", "wc"]) {
            return nearbyVisitor(category: .restroom, context: context, now: now, lead: "Nearest facilities.")
        }
        if matches(q, ["pray", "prayer", "salah"]) {
            return nearbyVisitor(category: .prayer, context: context, now: now, lead: "Prayer facilities landside.")
        }
        if matches(q, ["help", "staff", "lost", "information", "someone"]) {
            return AssistantResponse(
                speech: "The information desk in the central hall is staffed — they can help with lost property, airport services and anything I can't.",
                cards: [.poi([map.poi("info_l")].compactMap { $0 })],
                command: .none,
                followUps: ["Take me there", "What else is here?"]
            )
        }

        return nearbyVisitor(category: nil, context: context, now: now,
                             lead: "I can help you find your way around, meet an arrival, or answer questions about the airport.")
    }

    private func nearbyVisitor(category: POICategory?, context: PassengerContext,
                               now: Date, lead: String) -> AssistantResponse {
        let results = Self.rank(category: category, context: context, now: now,
                                map: map, router: router, directWalkMinutes: 0)
        guard !results.isEmpty else { return fallbackVisitor() }
        let top = Array(results.prefix(4))
        let headline = top.first.map { " \($0.poi.name) is \($0.walkMinutes) minutes away." } ?? ""
        return AssistantResponse(
            speech: lead + headline,
            cards: [.nearby(top)],
            command: .openExplore(category),
            followUps: ["Take me there", "Where's the meeting point?", "What else is here?"]
        )
    }

    private func fallbackVisitor() -> AssistantResponse {
        AssistantResponse(
            speech: "I can help you find your way around the terminal, meet an arriving passenger, or answer questions about the airport.",
            cards: [],
            command: .none,
            followUps: ["I'm meeting someone", "Where can I park?", "Where's the nearest coffee?"]
        )
    }

    // MARK: Composite answers

    /// The hero shape: a stop that does not lose the gate (§13 + §15).
    private func stopThenGate(poiID: String, context: PassengerContext, now: Date,
                              gateNode: String, direct: Int) -> AssistantResponse {
        guard let poi = map.poi(poiID),
              let route = router.route(from: context.locationNodeID, via: poiID, to: gateNode),
              let deadline = Self.deadlineDate(for: context)
        else { return fallback() }

        let destination = Self.destinationName(for: context)
        let viaWalk = route.minutes
        let f = TimingEngine.evaluate(stop: poi, now: now, boarding: deadline,
                                      directWalkMinutes: direct, walkMinutesViaStop: viaWalk)

        let toStop = route.minutesToStop() ?? 0
        let fromStop = route.minutesFromStop() ?? direct

        let speech: String
        if f.isFeasible {
            let placement = f.isOnRoute
                ? "and it's along your route to \(destination)"
                : "— it adds about \(f.addedWalkMinutes) minutes to your route"
            speech = "There's a \(poi.name.lowercased()) about \(toStop) minutes away \(placement). It's another \(fromStop) minutes on to \(destination) from there, and you'd still arrive with around \(f.sparedMinutes) minutes to spare."
        } else {
            speech = "The \(poi.name.lowercased()) is \(toStop) minutes away, but it would leave you \(abs(f.sparedMinutes)) minutes short. I'd go straight to \(destination)."
        }

        return AssistantResponse(
            speech: speech,
            cards: [.route(route), .poi([poi])],
            command: f.isFeasible ? .openNavigation(route) : .none,
            followUps: f.isFeasible
                ? ["Take me there", "Go straight to my gate", "How long do I have?"]
                : ["Take me to my gate", "What else is nearby?"]
        )
    }

    private func nearby(category: POICategory?, context: PassengerContext, now: Date,
                        direct: Int, lead: String) -> AssistantResponse {
        let results = Self.rank(category: category, context: context, now: now,
                                map: map, router: router, directWalkMinutes: direct)
        guard !results.isEmpty else { return fallback() }
        let top = results.prefix(4).map { $0 }
        let headline = top.first.map { "\($0.poi.name) is \($0.walkMinutes) minutes away\($0.feasibility.isOnRoute ? ", on your route" : "")." } ?? ""
        return AssistantResponse(
            speech: "\(lead) \(headline)",
            cards: [.nearby(top)],
            command: .openExplore(category),
            followUps: ["Take me there", "Take me to my gate", "How long do I have?"]
        )
    }

    private func fallback() -> AssistantResponse {
        AssistantResponse(
            speech: "I can help with your flight, getting to your gate, finding something nearby, or arranging a service. What would you like?",
            cards: [.journeyStatus],
            command: .none,
            followUps: ["What should I do next?", "What's nearby?", "Show my flight"]
        )
    }

    // MARK: Ranking — shared by Explore and the assistant so both agree.

    static func rank(category: POICategory?, context: PassengerContext, now: Date,
                     map: AirportMap, router: RoutingEngine, directWalkMinutes: Int) -> [ExploreResult] {
        let destination = destinationNode(for: context)

        return map.pois(in: context.zone)          // never offer the other side of security
            .filter { $0.category != .gate && $0.category != .arrivals && $0.openNow }
            .filter { category == nil || $0.category == category }
            .compactMap { poi -> ExploreResult? in
                guard let walk = router.minutes(from: context.locationNodeID, to: poi.id) else { return nil }

                // With no destination there is no detour and no deadline — the
                // stop is simply somewhere to go.
                guard let destination,
                      let via = router.route(from: context.locationNodeID, via: poi.id, to: destination),
                      let deadline = deadlineDate(for: context)
                else {
                    return ExploreResult(poi: poi, walkMinutes: walk,
                                         feasibility: .unbounded(poi: poi, walkMinutes: walk))
                }

                let f = TimingEngine.evaluate(stop: poi, now: now, boarding: deadline,
                                              directWalkMinutes: directWalkMinutes,
                                              walkMinutesViaStop: via.minutes)
                return ExploreResult(poi: poi, walkMinutes: walk, feasibility: f)
            }
            // Nearby + Relevant + On my route + I have time — in that order of weight.
            .sorted { a, b in
                if a.feasibility.isFeasible != b.feasibility.isFeasible { return a.feasibility.isFeasible }
                if a.feasibility.isOnRoute != b.feasibility.isOnRoute { return a.feasibility.isOnRoute }
                return a.walkMinutes < b.walkMinutes
            }
    }

    /// The moment that ends the person's freedom to wander: boarding for a
    /// passenger, the arrival emerging for a meeter, never for a visitor.
    static func deadlineDate(for context: PassengerContext) -> Date? {
        guard let flight = context.flight else { return nil }
        switch context.mode {
        case .departing: return flight.boarding
        case .meeting:   return flight.landing.map(TimingEngine.emergenceTime)
        case .visiting:  return nil
        }
    }

    // MARK: Matching

    private func matches(_ q: String, _ needles: [String]) -> Bool {
        needles.contains { q.contains($0) }
    }

    private func keywords(for c: POICategory) -> [String] {
        switch c {
        case .prayer:   ["pray", "prayer", "salah"]
        case .food:     ["coffee", "food", "eat", "drink", "cafe"]
        case .lounge:   ["lounge"]
        case .restroom: ["restroom", "toilet", "bathroom", "wc"]
        case .pharmacy: ["pharmacy", "chemist", "medicine", "painkiller"]
        case .shopping: ["shop", "duty free", "gift", "buy"]
        case .charging: ["charge", "charging", "battery", "power", "plug"]
        case .help:     ["information desk", "info desk", "lost property"]
        default:        []
        }
    }
}
