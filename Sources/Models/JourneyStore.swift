import Foundation
import Observation
import SwiftUI

/// What the assistant is doing right now.
enum VoiceState: Sendable, Equatable {
    case closed
    /// Visible microphone with a context-specific suggested prompt.
    case idle
    /// Input-reactive waveform and a live partial transcript.
    case listening(partial: String)
    /// Names the reasoning in progress, and shows the final transcript so a
    /// mishearing is catchable before anything happens.
    case processing(transcript: String, reasoning: String)
    /// Rendered visually and spoken at the same time, in the same words.
    case speaking(AssistantResponse)
    case finished(AssistantResponse)
    case failed(VoiceFailure)

    var isOpen: Bool {
        if case .closed = self { return false }
        return true
    }

    var response: AssistantResponse? {
        switch self {
        case .speaking(let r), .finished(let r): r
        default: nil
        }
    }
}

/// Where the app has been sent, by tap or by voice.
enum Route: Hashable {
    case flightDetail
    case routeOverview(RoutePlan)
    case turnByTurn(RoutePlan)
    case multiStop(RoutePlan)
    case serviceFlow(ServiceOffer)
    case confirmation(ServiceDraft)
    case help(HelpTopic)
    case disruption(ChangeAlert)
}

/// Single source of truth for the demo journey.
///
/// There is no networking anywhere in this app: every value is hardcoded demo
/// data, in the same spirit as the rest of the Fly+ family. What is *not*
/// faked is the arithmetic — countdowns, leave-by times and slack all come
/// from `TimingEngine`, so the screens stay consistent with each other as the
/// demo clock runs.
@MainActor
@Observable
final class JourneyStore {
    // MARK: Journey

    var flight: Flight = .demo
    var stage: JourneyStage = .demoDefault
    var positionConfidence: PositionConfidence = .good
    var hasJourney = false

    /// The demo clock: anchored at 17:08 and then ticking in real time, so a
    /// walkthrough shows live countdowns rather than a frozen mock.
    private(set) var now: Date = DemoClock.anchor
    private var tickTask: Task<Void, Never>?

    // MARK: Assistant

    var voice: VoiceState = .closed
    var path: [Route] = []
    var selectedTab: AppTab = .home
    var activeRoute: RoutePlan?
    var acknowledgedGateChange = false

    // MARK: Settings

    var language: AppLanguage = .english
    var prefersStepFree = false
    var reduceMotion = false

    var translator: Translator { Translator(language: language) }

    // MARK: Derived timing

    /// Walking minutes from the passenger's current position to the gate.
    var walkToGateMinutes: Int { activeGateRoute.totalWalkMinutes }

    var activeGateRoute: RoutePlan {
        if stage == .changed || flight.gate == Flight.demoAfterGateChange.gate { return .toNewGate }
        return activeRoute?.hasStop == true ? .viaPrayerRoom : .toGate
    }

    var minutesToBoarding: Int {
        TimingEngine.minutes(from: now, to: flight.boardingTime)
    }

    var leaveBy: Date {
        TimingEngine.leaveBy(boarding: flight.boardingTime, walkMinutes: walkToGateMinutes)
    }

    var slackMinutes: Int {
        TimingEngine.slackMinutes(now: now, boarding: flight.boardingTime, walkMinutes: walkToGateMinutes)
    }

    var pressure: TimingEngine.Pressure {
        TimingEngine.pressure(slackMinutes: slackMinutes)
    }

    // MARK: Lifecycle

    func start() {
        guard tickTask == nil else { return }
        let anchor = DemoClock.anchor
        let startedAt = Date()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.now = anchor.addingTimeInterval(Date().timeIntervalSince(startedAt))
                self.advanceStageIfNeeded()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Reset the walkthrough. A demo that has drifted past boarding is no use
    /// to the next person in the room.
    func resetDemo() {
        stop()
        flight = .demo
        stage = .demoDefault
        voice = .closed
        path = []
        activeRoute = nil
        acknowledgedGateChange = false
        positionConfidence = .good
        selectedTab = .home
        now = DemoClock.anchor
        start()
    }

    /// The state machine advances on time, not on taps — the passenger never
    /// navigates to their own status.
    private func advanceStageIfNeeded() {
        guard stage != .changed, stage != .runningLate else { return }
        switch pressure {
        case .plenty, .enough:
            if minutesToBoarding <= 0 { stage = .boarding }
            else if stage == .airside && slackMinutes < 20 { stage = .boardingSoon }
        case .leaveNow:
            if stage != .boarding { stage = .boardingSoon }
        case .late:
            stage = minutesToBoarding <= 0 ? .boarding : .runningLate
        }
    }

    // MARK: The gate change, fired by hand for the demo

    func applyGateChange() {
        flight = .demoAfterGateChange
        stage = .changed
        acknowledgedGateChange = false
        path.append(.disruption(.gateChange))
    }

    func acceptRevisedRoute(_ alert: ChangeAlert) {
        activeRoute = alert.revisedRoute
        acknowledgedGateChange = true
        stage = .boardingSoon
        path = [.turnByTurn(alert.revisedRoute)]
    }

    func keepOldRoute() {
        acknowledgedGateChange = true
        stage = .airside
        path.removeAll()
    }

    // MARK: Navigation

    func go(to destination: AssistantDestination) {
        switch destination {
        case .stay:
            break
        case .home:
            selectedTab = .home
            path.removeAll()
        case .explore:
            selectedTab = .explore
            path.removeAll()
        case .flightDetail:
            path.append(.flightDetail)
        case .routeOverview(let plan):
            activeRoute = plan
            selectedTab = .navigate
            path = [.routeOverview(plan)]
        case .turnByTurn(let plan):
            activeRoute = plan
            selectedTab = .navigate
            path = [.turnByTurn(plan)]
        case .multiStop(let plan):
            activeRoute = plan
            selectedTab = .navigate
            path = [.multiStop(plan)]
        case .serviceFlow(let offer):
            path.append(.serviceFlow(offer))
        case .help(let topic):
            path.append(.help(topic))
        case .disruption(let alert):
            path.append(.disruption(alert))
        }
        voice = .closed
    }
}
