import SwiftUI

/// 06 — Contextual flight response.
///
/// The easy version of this screen is a flight tracker. The version worth
/// building adds the one sentence a flight tracker cannot: a promise. "Gate
/// numbers can change… we'll tell you if it does" converts a static data dump
/// into a relationship, and it is what licenses the passenger to stop checking.
struct FlightDetailView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("\(store.flight.number) is on time. Boarding at \(store.translator.clock(store.flight.boardingTime)), Gate \(store.flight.gate).",
                        "\(store.flight.number) في موعدها. الصعود \(store.translator.clock(store.flight.boardingTime))، البوابة \(store.flight.gate)."))
                    .verdictStyle()

                FlightCardView(flight: store.flight, density: .full)

                PrimaryButton(title: tr("Guide me to Gate \(store.flight.gate)", "أرشدني إلى البوابة \(store.flight.gate)"),
                              symbol: "figure.walk") {
                    store.go(to: .routeOverview(store.activeGateRoute))
                }

                HStack(spacing: 8) {
                    ShortcutChip(title: tr("Add to Wallet", "أضف إلى Wallet"), symbol: "wallet.bifold") {}
                    ShortcutChip(title: tr("Share arrival", "شارك وقت الوصول"), symbol: "square.and.arrow.up") {}
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(store.flight.number)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 13 — Change and disruption.
///
/// Everything else is the happy path. This screen proves the premise, because
/// it is the only moment where knowing the passenger's journey produces
/// something no map, no flight tracker and no chatbot could have produced: a
/// re-plan of a decision they had already made, delivered before they
/// discovered the problem.
struct DisruptionView: View {
    let alert: ChangeAlert

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AlertCardView(alert: alert) {
                    store.acceptRevisedRoute(alert)
                } onOverrule: {
                    store.keepOldRoute()
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(tr("Gate changed", "تغيّرت البوابة"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    let topic: HelpTopic

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCardView(topic: topic) {}

                SecondaryButton(title: tr("Fastest route to Gate \(store.flight.gate)",
                                          "أسرع مسار إلى البوابة \(store.flight.gate)"),
                                symbol: "figure.walk") {
                    store.go(to: .turnByTurn(store.activeGateRoute))
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(tr("Help", "المساعدة"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Explore, filtered by route and time — or it is a worse version of the
/// airport's own website. `searchable` is the platform's own search
/// affordance, so the passenger does not have to learn ours.
struct ExploreView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    @State private var query = ""

    private var places: [PointOfInterest] {
        let all = PointOfInterest.demo
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("You have about \(max(store.slackMinutes, 0)) minutes free.",
                        "لديك نحو \(max(store.slackMinutes, 0)) دقيقة حرة."))
                    .verdictStyle()

                if places.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    NearbyRecommendationView(heading: tr("Fits your time", "يناسب وقتك"),
                                             places: places.filter { $0.detourMinutes <= max(store.slackMinutes, 0) }) { place in
                        if place.category == .prayerRoom {
                            store.go(to: .multiStop(.viaPrayerRoom))
                        } else {
                            store.go(to: .routeOverview(store.activeGateRoute))
                        }
                    }

                    let tooLong = places.filter { $0.detourMinutes > max(store.slackMinutes, 0) }
                    if !tooLong.isEmpty {
                        NearbyRecommendationView(heading: tr("Would cut into your gate buffer",
                                                            "قد يقتطع من مهلتك عند البوابة"),
                                                 places: tooLong) { _ in }
                    }
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .background(Theme.canvas.ignoresSafeArea())
        .searchable(text: $query, prompt: Text(tr("Search the terminal", "ابحث في الصالة")))
        .navigationTitle(tr("Explore", "استكشف"))
    }
}

/// More: bookings, profile, language, accessibility — plus the demo controls,
/// because a POC that cannot be reset or driven into a state is a POC that can
/// only be demonstrated once.
struct MoreView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        @Bindable var store = store

        // A `Form` is the platform's settings surface. Using it means every
        // row, every control and every grouping already behaves the way the
        // passenger expects from the rest of iOS.
        Form {
            Section {
                Picker(tr("Language", "اللغة"), selection: $store.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.endonym).tag(language)
                    }
                }
                // Accessible routing is a product feature, not a setting to be
                // found in options — so it is asked once, here, and then
                // stated on every route.
                Toggle(tr("Step-free routes only", "مسارات خالية من الدرج فقط"), isOn: $store.prefersStepFree)
                Toggle(tr("Reduce motion", "تقليل الحركة"), isOn: $store.reduceMotion)
            } header: {
                Text(tr("Journey preferences", "تفضيلات الرحلة"))
            } footer: {
                Text(tr("Arabic is fully translated on Home and the shared chrome; deeper screens still fall back to English in this build.",
                        "العربية مترجمة بالكامل في الشاشة الرئيسية والعناصر المشتركة؛ أما الشاشات الأعمق فما زالت تعرض الإنجليزية في هذه النسخة."))
            }

            Section {
                settingRow(tr("Flight", "الرحلة"), store.flight.number)
                settingRow(tr("Gate", "البوابة"), store.flight.gate)
                settingRow(tr("Boarding", "الصعود"), store.translator.clock(store.flight.boardingTime))
                settingRow(tr("Safety buffer", "مهلة الأمان"), "\(TimingEngine.safetyBufferMinutes) min")
            } header: {
                Text(tr("Your flight", "رحلتك"))
            }

            Section {
                Picker(tr("Journey state", "حالة الرحلة"), selection: $store.stage) {
                    ForEach(JourneyStage.allCases) { stage in
                        Text(stage.label).tag(stage)
                    }
                }
                Toggle(tr("Uncertain position", "موقع غير مؤكد"), isOn: Binding(
                    get: { store.positionConfidence == .uncertain },
                    set: { store.positionConfidence = $0 ? .uncertain : .good }
                ))
                Button(tr("Fire a gate change", "أطلق تغيير البوابة")) {
                    store.applyGateChange()
                }
                Button(tr("Reset the walkthrough", "إعادة ضبط العرض"), role: .destructive) {
                    store.resetDemo()
                }
            } header: {
                Text(tr("Demo controls", "أدوات العرض"))
            } footer: {
                Text(tr("The clock starts at 17:08 and runs in real time, so states advance on their own during a walkthrough.",
                        "تبدأ الساعة عند ١٧:٠٨ وتسير في الزمن الحقيقي، فتتقدم الحالات من تلقاء نفسها أثناء العرض."))
            }
        }
        .tint(Theme.brand)
        .navigationTitle(tr("More", "المزيد"))
    }

    private func settingRow(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).monospacedDigit()
        } label: {
            Text(label)
        }
    }
}
