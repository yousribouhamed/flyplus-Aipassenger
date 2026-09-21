import Foundation

/// The "what matters now" block, rendered from the journey state.
///
/// The copy rule is fixed: the verdict line is always a *judgement plus a
/// deadline*, never a restatement of the numbers above it. "Boarding in 47 min"
/// is data; "You're on schedule, leave by 17:32" is the product.
struct JourneySnapshot: Sendable {
    let headline: String
    let detail: String
    let verdict: String
    let primaryLabel: String
    let primaryDestination: AssistantDestination
    let tone: FlightStatus.Tone
}

extension JourneyStore {
    var snapshot: JourneySnapshot {
        let tr = translator
        let gate = flight.gate
        let walk = walkToGateMinutes
        let leaveByPhrase = TimingEngine.leaveByPhrase(leaveBy, using: tr)

        switch stage {
        case .preAirport:
            return JourneySnapshot(
                headline: tr("Flight in \(TimingEngine.countdown(minutes: TimingEngine.minutes(from: now, to: flight.scheduledDeparture)))",
                             "رحلتك بعد \(TimingEngine.countdown(minutes: TimingEngine.minutes(from: now, to: flight.scheduledDeparture)))"),
                detail: tr("\(flight.origin.code) · Terminal \(flight.terminal)", "\(flight.origin.code) · صالة \(flight.terminal)"),
                verdict: tr("Leave home by \(tr.clock(flight.scheduledDeparture.addingTimeInterval(-3.5 * 3600))) for a comfortable arrival.",
                            "غادر المنزل قبل \(tr.clock(flight.scheduledDeparture.addingTimeInterval(-3.5 * 3600))) للوصول براحة."),
                primaryLabel: tr("Plan my arrival", "خطط لوصولي"),
                primaryDestination: .stay,
                tone: .neutral
            )

        case .landside:
            return JourneySnapshot(
                headline: tr("Check-in closes in 55 min", "ينتهي تسجيل الوصول خلال ٥٥ دقيقة"),
                detail: tr("Terminal \(flight.terminal) · security is 12 min from here",
                           "صالة \(flight.terminal) · التفتيش على بعد ١٢ دقيقة"),
                verdict: tr("Check in first — security is 12 minutes from here.",
                            "سجّل وصولك أولاً — التفتيش على بعد ١٢ دقيقة من هنا."),
                primaryLabel: tr("Take me to check-in", "خذني إلى تسجيل الوصول"),
                primaryDestination: .routeOverview(.toGate),
                tone: .timeSensitive
            )

        case .checkedIn:
            return JourneySnapshot(
                headline: tr("Security next", "التفتيش تالياً"),
                detail: tr("Boarding in \(TimingEngine.countdown(minutes: minutesToBoarding))",
                           "الصعود خلال \(TimingEngine.countdown(minutes: minutesToBoarding))"),
                verdict: tr("You're on schedule.", "أنت ضمن الوقت المحدد."),
                primaryLabel: tr("Take me to security", "خذني إلى التفتيش"),
                primaryDestination: .routeOverview(.toGate),
                tone: .neutral
            )

        case .airside:
            return JourneySnapshot(
                headline: tr("Boarding in \(TimingEngine.countdown(minutes: minutesToBoarding))",
                             "الصعود خلال \(TimingEngine.countdown(minutes: minutesToBoarding))"),
                detail: tr("Gate \(gate) · \(walk) min walk", "البوابة \(gate) · \(walk) دقائق سيراً"),
                verdict: tr("You're on schedule. \(leaveByPhrase).", "أنت ضمن الوقت المحدد. \(leaveByPhrase)."),
                primaryLabel: tr("Guide me to Gate \(gate)", "أرشدني إلى البوابة \(gate)"),
                primaryDestination: .routeOverview(.toGate),
                tone: .neutral
            )

        case .boardingSoon:
            return JourneySnapshot(
                headline: tr("Head to Gate \(gate) now", "توجّه إلى البوابة \(gate) الآن"),
                detail: tr("\(walk) min walk · boarding in \(TimingEngine.countdown(minutes: minutesToBoarding))",
                           "\(walk) دقائق سيراً · الصعود خلال \(TimingEngine.countdown(minutes: minutesToBoarding))"),
                verdict: tr("Leave now to arrive before boarding.", "غادر الآن لتصل قبل بدء الصعود."),
                primaryLabel: tr("Start walking directions", "ابدأ الإرشاد خطوة بخطوة"),
                primaryDestination: .turnByTurn(activeGateRoute),
                tone: .timeSensitive
            )

        case .boarding:
            return JourneySnapshot(
                headline: tr("Boarding · Gate \(gate)", "الصعود · البوابة \(gate)"),
                detail: tr("Seat \(flight.seat) · Terminal \(flight.terminal)", "المقعد \(flight.seat) · صالة \(flight.terminal)"),
                verdict: tr("Boarding has started.", "بدأ الصعود إلى الطائرة."),
                primaryLabel: tr("Show boarding pass", "اعرض بطاقة الصعود"),
                primaryDestination: .flightDetail,
                tone: .timeSensitive
            )

        case .changed:
            return JourneySnapshot(
                headline: tr("Now Gate \(gate)", "البوابة الآن \(gate)"),
                detail: tr("Moved from Gate 32 · \(ChangeAlert.gateChange.minutesAgo) min ago",
                           "نُقلت من البوابة ٣٢ · قبل \(ChangeAlert.gateChange.minutesAgo) دقائق"),
                verdict: tr("11 minutes away instead of 6 — \(leaveByPhrase).",
                            "على بعد ١١ دقيقة بدلاً من ٦ — \(leaveByPhrase)."),
                primaryLabel: tr("Update my route", "حدّث مساري"),
                primaryDestination: .disruption(.gateChange),
                tone: .changed
            )

        case .runningLate:
            return JourneySnapshot(
                headline: tr("Gate closes in \(TimingEngine.countdown(minutes: max(minutesToBoarding, 1)))",
                             "تغلق البوابة خلال \(TimingEngine.countdown(minutes: max(minutesToBoarding, 1)))"),
                detail: tr("Gate \(gate) · \(walk) min walk", "البوابة \(gate) · \(walk) دقائق سيراً"),
                verdict: tr("Go straight there — the fastest route is step-free.",
                            "توجّه مباشرة — أسرع مسار خالٍ من الدرج."),
                primaryLabel: tr("Fastest route to gate", "أسرع مسار إلى البوابة"),
                primaryDestination: .turnByTurn(activeGateRoute),
                tone: .changed
            )

        case .inFlight:
            return JourneySnapshot(
                headline: tr("Landing in 2 h 40 min", "الهبوط خلال ٢ س ٤٠ د"),
                detail: tr("\(flight.destination.code) · Terminal 4", "\(flight.destination.code) · صالة ٤"),
                verdict: tr("Nothing to do until you land.", "لا شيء عليك فعله حتى الهبوط."),
                primaryLabel: tr("Plan my arrival", "خطط لوصولي"),
                primaryDestination: .stay,
                tone: .neutral
            )
        }
    }

    /// The suggested utterance in the idle voice state. State Farm greys one
    /// into its assistant panel — it is the cheapest way to teach people what
    /// they are allowed to say, and it changes with journey state so it is
    /// always a question worth asking *now*.
    var suggestedUtterance: String {
        switch stage {
        case .preAirport:   "When should I leave home?"
        case .landside:     "Where do I check in?"
        case .checkedIn:    "How long is security?"
        case .airside:      "What should I do next?"
        case .boardingSoon: "How far is my gate?"
        case .boarding:     "Show my boarding pass"
        case .changed:      "Where is Gate 41?"
        case .runningLate:  "Fastest way to my gate"
        case .inFlight:     "Can you deliver my bags home?"
        }
    }
}
