import Foundation
import Observation
import SwiftUI

// MARK: - Voice states (§11)

enum VoiceState: Equatable {
    case idle, listening, processing, speaking, failed
}

// MARK: - Proactive alert (§9)

struct JourneyAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let actionLabel: String
    let kind: Kind

    enum Kind: Equatable { case boarding, gateChange, recommendation }
}

// MARK: - A booked service

struct ServiceBooking: Identifiable, Equatable {
    let id = UUID()
    let kind: ServiceKind
    let reference: String
    let summary: String
    let bookedAt: Date
}

// MARK: - Store

@Observable
final class JourneyStore {

    // MARK: Configuration
    var tenant: Tenant = .flyPlus

    // MARK: Journey
    let map = AirportMap.jeddah
    private(set) var context: PassengerContext
    /// Simulated clock. A demo cannot depend on the wall clock and still open on
    /// "Boarding in 47 min" — so the journey has its own anchored, ticking time.
    private(set) var now: Date

    // MARK: Session
    var hasJourney = false
    var transcript: [AssistantTurn] = []
    var voiceState: VoiceState = .idle
    var liveTranscription = ""
    var assistantPresented = false
    var alert: JourneyAlert?
    var bookings: [ServiceBooking] = []
    var pendingConfirmation: ConfirmationRequest?

    // MARK: Navigation
    var activeRoute: Route?
    var isNavigating = false
    var accessibleRouteOnly = false
    var selectedTab: AppTab = .home
    var exploreCategory: POICategory?
    var flightCardExpanded = false

    // MARK: Derived

    /// The router is pinned to the zone the person can actually walk in.
    var router: RoutingEngine { RoutingEngine(map: map, zone: context.zone) }
    var assistant: Assistant { Assistant(map: map, router: router, tenant: tenant) }

    var flight: Flight? { context.flight }
    var mode: VisitMode { context.mode }

    /// Where this person is heading by default: their gate, or the arrivals hall
    /// they're meeting someone at. A visitor has no default — and shouldn't.
    var destinationNodeID: String? {
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

    var destinationName: String {
        switch context.mode {
        case .departing: context.flight?.gate ?? "your gate"
        case .meeting:   context.flight?.arrivalsExit ?? "Arrivals"
        case .visiting:  "the terminal"
        }
    }

    var walkMinutesToGate: Int {
        guard let dest = destinationNodeID else { return 0 }
        return router.minutes(from: context.locationNodeID, to: dest) ?? 6
    }

    /// Nil for a visitor: with no deadline there is no budget, and inventing one
    /// would make the app assert things it cannot know.
    var budget: TimingEngine.Budget? {
        guard let flight = context.flight else { return nil }
        switch context.mode {
        case .departing:
            return TimingEngine.budget(now: now, boarding: flight.boarding,
                                       walkMinutesToGate: walkMinutesToGate)
        case .meeting:
            guard let landing = flight.landing else { return nil }
            return TimingEngine.meetingBudget(now: now, landing: landing,
                                              walkMinutesToArrivals: walkMinutesToGate)
        case .visiting:
            return nil
        }
    }

    var nearby: [ExploreResult] {
        Assistant.rank(category: exploreCategory, context: context, now: now,
                       map: map, router: router, directWalkMinutes: walkMinutesToGate)
    }

    // MARK: Display accessors
    //
    // Every mode can answer these, so views don't each have to re-derive
    // "what if there is no flight" and get it subtly wrong.

    var hasDeadline: Bool { budget != nil }
    var minutesToDeadline: Int { budget?.minutesToBoarding ?? 0 }
    var isBehindSchedule: Bool { budget?.isBehindSchedule ?? false }
    var availableMinutes: Int { budget?.availableMinutes ?? 0 }

    /// What the countdown is counting towards.
    var deadlineLabel: String {
        switch context.mode {
        case .departing: minutesToDeadline <= 0 ? "Boarding now" : "Boarding in"
        case .meeting:   minutesToDeadline <= 0 ? "They're through" : "They'll be out in"
        case .visiting:  ""
        }
    }

    /// The clock time that matters: boarding, or when an arrival actually emerges.
    var deadlineClock: String? {
        guard let flight = context.flight else { return nil }
        switch context.mode {
        case .departing: return TimingEngine.clock(flight.boarding)
        case .meeting:   return flight.landing.map { TimingEngine.clock(TimingEngine.emergenceTime(landing: $0)) }
        case .visiting:  return nil
        }
    }

    /// One line of context for the assistant's header.
    var contextLine: String {
        switch context.mode {
        case .departing:
            guard let f = context.flight else { return map.terminal }
            return "\(f.number) · \(f.gate) · \(TimingEngine.durationPhrase(minutesToDeadline)) to boarding"
        case .meeting:
            guard let f = context.flight else { return map.terminalLabel(for: context.zone) }
            return "\(f.number) · \(f.arrivalsExit) · out in \(TimingEngine.durationPhrase(minutesToDeadline))"
        case .visiting:
            return map.name
        }
    }

    /// Categories worth offering, which differ entirely by side of security.
    var browsableCategories: [POICategory] {
        context.zone == .airside ? POICategory.browsable : POICategory.landsideBrowsable
    }

    // MARK: Init

    init() {
        // The POC journey, exactly as the brief specifies it (§6).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 28
        comps.hour = 17; comps.minute = 8
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Riyadh") ?? .current
        let start = cal.date(from: comps) ?? Date()

        func at(_ h: Int, _ m: Int) -> Date {
            var c = comps; c.hour = h; c.minute = m
            return cal.date(from: c) ?? start
        }

        let flight = Flight(
            number: "SV117",
            airlineName: "SAUDIA",
            originCode: "JED", originCity: "Jeddah",
            destinationCode: "LHR", destinationCity: "London",
            status: .onTime,
            boarding: at(17, 55),        // → "Boarding in 47 min" at 17:08
            departure: at(18, 40),
            gate: "Gate 32",
            terminal: "Terminal 1",
            baggageBelt: "Belt 7"
        )

        // Clock display follows the airport, not the device.
        TimingEngine.displayTimeZone = TimeZone(identifier: AirportMap.jeddah.timeZoneID) ?? cal.timeZone

        self.now = start
        self.demoFlight = flight
        self.demoArrival = Flight(
            number: "MS673", airlineName: "EgyptAir",
            originCode: "CAI", originCity: "Cairo",
            destinationCode: "JED", destinationCity: "Jeddah",
            status: .onTime,
            boarding: at(14, 10), departure: at(14, 45),
            gate: "Gate 12", terminal: "Terminal 1", baggageBelt: "Belt 3",
            landing: at(17, 30),                 // → emerges ~18:10
            arrivalsExit: "Arrivals B"
        )
        self.context = PassengerContext(
            mode: .departing,
            flight: flight,
            stage: .airside,             // POC starts after security
            locationNodeID: "security_exit",
            hasCheckedBags: true,
            homeAddress: "Al Olaya, Riyadh",
            meetingName: nil
        )
    }

    /// Kept so the setup screen can switch between contexts without re-deriving them.
    private let demoFlight: Flight
    let demoArrival: Flight

    // MARK: Clock

    func tick() {
        now = now.addingTimeInterval(1)
        refreshStage()
        maybeRaiseBoardingAlert()
    }

    /// Fast-forward, so a 3–5 minute demo can reach boarding without waiting.
    func advance(minutes: Int) {
        now = now.addingTimeInterval(Double(minutes) * 60)
        refreshStage()
        maybeRaiseBoardingAlert()
    }

    private func refreshStage() {
        guard context.mode == .departing, context.stage != .arrival, let b = budget else { return }
        if b.minutesToBoarding <= 20 && context.stage == .airside {
            context.stage = .boardingSoon
        }
    }

    private var boardingAlertRaised = false
    private func maybeRaiseBoardingAlert() {
        guard tenant.has(.proactiveAlerts), !boardingAlertRaised, alert == nil,
              context.mode == .departing, let b = budget, let flight = context.flight else { return }
        guard b.minutesToBoarding <= 20 else { return }
        boardingAlertRaised = true
        alert = JourneyAlert(
            title: "Boarding starts in \(b.minutesToBoarding) minutes",
            body: "You're about \(walkMinutesToGate) minutes from \(flight.gate).",
            actionLabel: "Go to gate",
            kind: .boarding
        )
    }

    // MARK: Demo events (§9 — the pattern must exist even if live feeds don't)

    func simulateGateChange() {
        guard context.mode == .departing, context.flight != nil else { return }
        context.flight?.gate = "Gate 31"
        context.flight?.status = .gateChanged
        if isNavigating || activeRoute != nil { routeToGate() }
        alert = JourneyAlert(
            title: "Your gate has changed",
            body: "\(context.flight?.number ?? "Your flight") now departs from Gate 31. Your route has been updated.",
            actionLabel: "Update route",
            kind: .gateChange
        )
    }

    func dismissAlert() { alert = nil }

    // MARK: Journey setup

    func startJourney() {
        context.mode = .departing
        context.flight = demoFlight
        context.stage = .airside
        context.locationNodeID = "security_exit"
        hasJourney = true
    }

    /// A visitor: no flight, no deadline, landside. Everything downstream has to
    /// cope with the absence rather than inventing a placeholder journey.
    func startVisit() {
        context.mode = .visiting
        context.flight = nil
        context.meetingName = nil
        context.stage = .atAirport
        context.locationNodeID = "entrance"
        exploreCategory = nil
        activeRoute = nil
        isNavigating = false
        hasJourney = true
    }

    /// Meeting an arrival re-anchors the app: a deadline, a destination and a
    /// status come back, so the journey machinery works again unchanged.
    func startMeeting(name: String? = nil) {
        context.mode = .meeting
        context.flight = demoArrival
        context.meetingName = name
        context.stage = .atAirport
        context.locationNodeID = "entrance"
        exploreCategory = nil
        activeRoute = nil
        isNavigating = false
        hasJourney = true
    }

    // MARK: Assistant

    /// Single entry point for both text and Voice — §10 requires one assistant,
    /// one conversation, whichever modality the passenger used.
    @MainActor
    func ask(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        voiceState = .processing
        let response = assistant.resolve(trimmed, context: context, now: now)
        transcript.append(AssistantTurn(question: trimmed, response: response))
        liveTranscription = ""

        // A brief processing beat, then "speaking" — §11 forbids a frozen state.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            voiceState = .speaking
            apply(response.command)
            try? await Task.sleep(for: .milliseconds(max(1400, Int(Double(response.speech.count) * 22))))
            if voiceState == .speaking { voiceState = .idle }
        }
    }

    /// Conversation changes the interface (§5) — this is where that happens.
    @MainActor
    private func apply(_ command: AssistantCommand) {
        switch command {
        case .none:
            break
        case .openNavigation(let route):
            activeRoute = route
        case .openExplore(let category):
            exploreCategory = category
        case .openServiceFlow:
            break   // presented from the card, so the passenger stays in control
        case .expandFlight:
            flightCardExpanded = true
            selectedTab = .home
        }
    }

    @MainActor
    func beginListening() {
        assistantPresented = true
        voiceState = .listening
        liveTranscription = ""
    }

    func cancelVoice() {
        voiceState = .idle
        liveTranscription = ""
    }

    func clearConversation() {
        transcript.removeAll()
        voiceState = .idle
    }

    // MARK: Navigation

    func routeToGate() {
        guard let dest = destinationNodeID else { return }
        activeRoute = router.route(from: context.locationNodeID, to: dest,
                                   stepFreeOnly: accessibleRouteOnly)
    }

    /// With a destination this is a multi-stop route; without one (a visitor)
    /// the place *is* the destination.
    func route(via poiID: String) {
        if let dest = destinationNodeID, dest != poiID {
            activeRoute = router.route(from: context.locationNodeID, via: poiID, to: dest,
                                       stepFreeOnly: accessibleRouteOnly)
        } else {
            activeRoute = router.route(from: context.locationNodeID, to: poiID,
                                       stepFreeOnly: accessibleRouteOnly)
        }
    }

    func routeTo(_ nodeID: String) {
        activeRoute = router.route(from: context.locationNodeID, to: nodeID,
                                   stepFreeOnly: accessibleRouteOnly)
    }

    func startNavigating() {
        if activeRoute == nil { routeToGate() }
        isNavigating = true
        selectedTab = .navigate
    }

    func stopNavigating() { isNavigating = false }

    /// Simulates the passenger walking to the next node on the active route.
    func advanceAlongRoute() {
        guard let route = activeRoute,
              let idx = route.nodes.firstIndex(where: { $0.id == context.locationNodeID }),
              idx + 1 < route.nodes.count
        else { return }
        let next = route.nodes[idx + 1]
        let legMinutes = route.legs[idx].minutes
        context.locationNodeID = next.id
        advance(minutes: legMinutes)

        if next.id == destinationNodeID {
            isNavigating = false
            activeRoute = nil
        } else if let stop = route.stopNodeID, next.id == stop,
                  let poi = map.poi(stop) {
            // Arrived at the intermediate stop — spend the dwell, then carry on.
            advance(minutes: poi.dwellMinutes)
            activeRoute = destinationNodeID.flatMap {
                router.route(from: next.id, to: $0, stepFreeOnly: accessibleRouteOnly)
            }
        }
    }

    // MARK: Services

    func confirm(_ request: ConfirmationRequest) {
        if let kind = request.service {
            bookings.append(ServiceBooking(
                kind: kind,
                reference: Self.reference(),
                summary: kind == .baggageDelivery
                    ? "2 bags to \(context.homeAddress)"
                    : kind.blurb,
                bookedAt: now
            ))
        }
        pendingConfirmation = nil
    }

    private static func reference() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let a = String((0..<2).map { _ in letters.randomElement()! })
        return "\(a)\(Int.random(in: 10000...99999))"
    }
}

// MARK: - Tabs (§8 of the PDF: Home · Navigate · Explore · More, Voice never a tab)

enum AppTab: String, CaseIterable, Identifiable {
    case home, navigate, explore, more
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .navigate: "Navigate"
        case .explore: "Explore"
        case .more: "More"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .navigate: "location.north.line"
        case .explore: "square.grid.2x2"
        case .more: "ellipsis"
        }
    }

    var capability: Tenant.Capabilities? {
        switch self {
        case .home: nil
        case .navigate: .navigate
        case .explore: .explore
        case .more: nil
        }
    }
}
