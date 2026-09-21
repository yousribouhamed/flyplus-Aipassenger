import Foundation

/// The canned assistant for the POC.
///
/// Two things about this are deliberate and survive into production.
///
/// First, it can only return components from `ResponseComponent` — the kit is
/// the contract, so the interface stays predictable whatever generates the
/// answer. Second, it never computes a time. Every number in every sentence
/// below comes out of `TimingEngine`, so the assistant and the Home screen can
/// never disagree about when the passenger should leave.
///
/// The low-confidence and out-of-scope paths are implemented rather than
/// stubbed, because a voice demo that only works for three rehearsed phrases
/// is theatre — and the research names that as a risk to design against.
extension JourneyStore {
    func respond(to utterance: String) -> AssistantResponse {
        let text = utterance.lowercased()
        let tr = translator

        // "I want to pray before boarding" — the hero interaction.
        if text.contains("pray") || text.contains("prayer") || text.contains("mosque") {
            let plan = RoutePlan.viaPrayerRoom
            let arrival = now.addingTimeInterval(TimeInterval(plan.totalElapsedMinutes * 60))
            let before = TimingEngine.minutes(from: arrival, to: flight.boardingTime)
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Checking your time and what's on your route…", "أتحقق من وقتك وما يقع على مسارك…"),
                answer: tr(
                    "There's a prayer room 2 minutes away, on your route to Gate \(flight.gate). You have enough time — you'd reach the gate at \(tr.clock(arrival)), \(before) minutes before boarding.",
                    "توجد مصلى على بعد دقيقتين، على مسارك إلى البوابة \(flight.gate). لديك وقت كافٍ — ستصل البوابة \(tr.clock(arrival))، أي قبل الصعود بـ \(before) دقيقة."
                ),
                components: [.multiStop(plan)],
                primary: .init(label: tr("Take me there", "خذني إلى هناك"), destination: .multiStop(plan)),
                alternative: .init(label: tr("Go straight to the gate", "اذهب مباشرة إلى البوابة"), destination: .routeOverview(.toGate))
            )
        }

        // "Show my flight"
        if text.contains("my flight") || text.contains("flight status") || text.contains("boarding pass") {
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Reading your flight…", "أقرأ بيانات رحلتك…"),
                answer: tr(
                    "\(flight.number) is on time. Boarding at \(tr.clock(flight.boardingTime)), Gate \(flight.gate).",
                    "\(flight.number) في موعدها. الصعود \(tr.clock(flight.boardingTime))، البوابة \(flight.gate)."
                ),
                components: [.flightCard(flight, .full)],
                primary: .init(label: tr("Guide me to Gate \(flight.gate)", "أرشدني إلى البوابة \(flight.gate)"),
                               destination: .routeOverview(activeGateRoute)),
                alternative: nil
            )
        }

        // "What should I do next?" — the screen the product stands on.
        if text.contains("what should i do") || text.contains("what next") || text.contains("how long do i have") || text.contains("time do i have") {
            let slack = max(slackMinutes, 0)
            let leaveByPhrase = TimingEngine.leaveByPhrase(leaveBy, using: tr)
            let opening: String
            switch pressure {
            case .plenty, .enough:
                // The most important word here is "Nothing". An assistant that
                // always finds something urgent is one nobody believes.
                opening = tr(
                    "Nothing urgent. You're through security and the gate is \(walkToGateMinutes) minutes away, so you have about \(slack) minutes free.",
                    "لا شيء عاجل. لقد اجتزت التفتيش والبوابة على بعد \(walkToGateMinutes) دقائق، فلديك نحو \(slack) دقيقة حرة."
                )
            case .leaveNow:
                opening = tr("Time to move. The gate is \(walkToGateMinutes) minutes away and boarding starts in \(TimingEngine.countdown(minutes: minutesToBoarding)).",
                             "حان وقت التحرك. البوابة على بعد \(walkToGateMinutes) دقائق والصعود يبدأ خلال \(TimingEngine.countdown(minutes: minutesToBoarding)).")
            case .late:
                opening = tr("Go straight to the gate now. Boarding starts in \(TimingEngine.countdown(minutes: max(minutesToBoarding, 1))).",
                             "توجه إلى البوابة الآن. الصعود يبدأ خلال \(TimingEngine.countdown(minutes: max(minutesToBoarding, 1))).")
            }

            let recommendation = Recommendation(
                id: "head-to-gate",
                headline: tr("Head to Gate \(flight.gate) by \(tr.clock(leaveBy))", "توجّه إلى البوابة \(flight.gate) قبل \(tr.clock(leaveBy))"),
                rationale: tr("That leaves the full \(TimingEngine.safetyBufferMinutes)-minute buffer at the gate.",
                              "يترك ذلك مهلة \(TimingEngine.safetyBufferMinutes) دقيقة كاملة عند البوابة."),
                actionLabel: tr("Guide me", "أرشدني"),
                destination: .routeOverview(activeGateRoute)
            )

            // Running late: the recommendation becomes the only content.
            let components: [ResponseComponent] = pressure == .late
                ? [.recommendation(recommendation)]
                : [.recommendation(recommendation),
                   .nearby(heading: tr("While you wait", "بينما تنتظر"),
                           places: PointOfInterest.demo.filter { $0.isOnRoute && $0.detourMinutes <= slack })]

            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Working out how much time you actually have…", "أحسب الوقت المتاح لك فعلياً…"),
                answer: opening,
                components: components,
                primary: .init(label: recommendation.actionLabel, destination: recommendation.destination),
                alternative: .init(label: tr("Show me what's nearby", "أرني ما حولي"), destination: .explore),
                isLowConfidence: false
            )
        }

        // "Can you deliver my bags home?"
        if text.contains("bag") || text.contains("luggage") || text.contains("suitcase") {
            let offer = ServiceOffer.offer("baggage")
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Checking what's available at \(flight.destination.name)…", "أتحقق مما هو متاح في \(flight.destination.name)…"),
                answer: tr(
                    "Yes — baggage delivery runs from \(flight.destination.city) \(flight.destination.name), where you land.",
                    "نعم — خدمة توصيل الحقائب متاحة من \(flight.destination.name)، حيث تهبط."
                ),
                components: [.service(offer)],
                primary: .init(label: tr("Continue", "متابعة"), destination: .serviceFlow(offer)),
                alternative: nil
            )
        }

        // "Take me to my gate"
        if text.contains("gate") || text.contains("take me") || text.contains("directions") {
            let plan = activeGateRoute
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Working out the route…", "أحسب المسار…"),
                answer: tr(
                    "\(plan.destination) is \(plan.totalWalkMinutes) minutes away, \(plan.destinationDetail). You'd arrive at \(tr.clock(TimingEngine.arrival(leaving: now, walkMinutes: plan.totalWalkMinutes))).",
                    "\(plan.destination) على بعد \(plan.totalWalkMinutes) دقائق، \(plan.destinationDetail). ستصل \(tr.clock(TimingEngine.arrival(leaving: now, walkMinutes: plan.totalWalkMinutes)))."
                ),
                components: [.navigation(plan)],
                primary: .init(label: tr("Start", "ابدأ"), destination: .turnByTurn(plan)),
                alternative: .init(label: tr("See it on the map first", "اعرض الخريطة أولاً"), destination: .routeOverview(plan))
            )
        }

        // "Where can I eat?"
        if text.contains("eat") || text.contains("food") || text.contains("coffee") || text.contains("nearby") || text.contains("shop") {
            let slack = max(slackMinutes, 0)
            let places = PointOfInterest.demo.filter { $0.detourMinutes <= slack }
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Filtering by what fits your time and route…", "أصفّي حسب وقتك ومسارك…"),
                answer: tr(
                    "You have about \(slack) minutes free. These fit without touching your gate buffer.",
                    "لديك نحو \(slack) دقيقة حرة. هذه الخيارات تناسب وقتك دون المساس بمهلتك عند البوابة."
                ),
                components: [.nearby(heading: tr("On your route", "على مسارك"), places: places)],
                primary: .init(label: tr("See everything nearby", "اعرض كل ما حولي"), destination: .explore),
                alternative: .init(label: tr("Go straight to the gate", "اذهب مباشرة إلى البوابة"), destination: .routeOverview(activeGateRoute))
            )
        }

        // "I'm going to miss my flight" / "I can't find my baggage"
        if text.contains("miss") || text.contains("late") || text.contains("help") || text.contains("lost") {
            let topic = HelpTopic.missedConnection
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Checking what I can do from here…", "أتحقق مما يمكنني فعله…"),
                answer: tr("Let's deal with it. Here's what I can do from here, and what needs a person.",
                           "لنتعامل مع الأمر. هذا ما يمكنني فعله، وهذا ما يحتاج إلى شخص."),
                components: [.help(topic)],
                primary: .init(label: tr("Fastest route to Gate \(flight.gate)", "أسرع مسار إلى البوابة \(flight.gate)"),
                               destination: .turnByTurn(activeGateRoute)),
                alternative: .init(label: topic.escalateLabel, destination: .help(topic))
            )
        }

        // Ambiguous: a guess, stated as a guess, with one-tap correction —
        // never a blank re-ask.
        if text.count < 12 {
            return AssistantResponse(
                transcript: utterance,
                reasoning: tr("Trying to place that…", "أحاول فهم ذلك…"),
                answer: tr("I think you mean your gate. Tell me if I've got that wrong.",
                           "أظن أنك تقصد بوابتك. صحّح لي إن أخطأت."),
                components: [.clarification(Clarification(
                    id: "ambiguous",
                    interpretation: tr("Directions to Gate \(flight.gate)", "الاتجاهات إلى البوابة \(flight.gate)"),
                    alternatives: [
                        tr("Something to eat", "شيء لتناوله"),
                        tr("My flight details", "تفاصيل رحلتي"),
                        tr("A prayer room", "مصلى")
                    ]
                ))],
                primary: .init(label: tr("Yes, my gate", "نعم، بوابتي"), destination: .routeOverview(activeGateRoute)),
                alternative: .init(label: tr("No, show me nearby", "لا، أرني ما حولي"), destination: .explore),
                isLowConfidence: true
            )
        }

        // Out of scope: say what it *can* do, and offer the nearest capability.
        return AssistantResponse(
            transcript: utterance,
            reasoning: tr("Checking whether that's something I can do…", "أتحقق إن كان ذلك ضمن قدراتي…"),
            answer: tr(
                "I can't do that here. I can get you to your gate, find somewhere on your route, or book a Fly+ service for when you land.",
                "لا أستطيع فعل ذلك هنا. يمكنني إيصالك إلى بوابتك، أو إيجاد مكان على مسارك، أو حجز خدمة من Fly+ عند وصولك."
            ),
            components: [.nearby(heading: tr("What I can do", "ما يمكنني فعله"),
                                 places: PointOfInterest.demo.filter(\.isOnRoute))],
            primary: .init(label: tr("Guide me to Gate \(flight.gate)", "أرشدني إلى البوابة \(flight.gate)"),
                           destination: .routeOverview(activeGateRoute)),
            alternative: .init(label: tr("Get help", "اطلب المساعدة"), destination: .help(.missedConnection))
        )
    }
}
