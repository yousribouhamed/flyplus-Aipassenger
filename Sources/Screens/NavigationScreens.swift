import SwiftUI

/// The Navigate tab. It does not open on a map: navigation is a capability,
/// not the product, and opening on a map when no navigation is needed is the
/// habit worth leaving behind from Google Maps.
struct NavigateTabView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavigationCardView(plan: store.activeGateRoute) {
                    store.go(to: .turnByTurn(store.activeGateRoute))
                }

                SecondaryButton(title: tr("See the route on the map", "اعرض المسار على الخريطة"),
                                symbol: "map") {
                    store.go(to: .routeOverview(store.activeGateRoute))
                }

                Text(tr("On your route", "على مسارك")).kickerStyle().padding(.top, 8)

                NearbyRecommendationView(heading: tr("Worth a stop", "يستحق التوقف"),
                                         places: PointOfInterest.demo.filter(\.isOnRoute)) { place in
                    if place.category == .prayerRoom {
                        store.go(to: .multiStop(.viaPrayerRoom))
                    } else {
                        store.selectedTab = .explore
                    }
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(tr("Navigate", "التنقل"))
    }
}

/// 08 — Indoor route overview.
///
/// Google Maps conventions do the heavy lifting and are copied almost exactly:
/// the whole route visible, time and distance as the largest element, a single
/// Start. Arguing with a pattern this well learned costs the passenger
/// attention they do not have.
///
/// The one line worth adding is the journey consequence. Maps tells you how
/// long the walk takes; only this product knows whether that is good news.
struct RouteOverviewView: View {
    let plan: RoutePlan

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr
    @State private var floor = "L2"

    var body: some View {
        AirportMapView(plan: plan, confidence: store.positionConfidence)
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    FloorSwitcher(floors: ["L3", "L2", "L1", "G"], selection: $floor)
                    Button {
                        // Re-centre, at the edge, out of the route — the Maps
                        // convention, in the Maps position.
                    } label: {
                        Image(systemName: "location.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(Theme.brand)
                    .accessibilityLabel(tr("Re-centre", "إعادة التمركز"))
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    NavigationCardView(plan: plan) {
                        store.go(to: .turnByTurn(plan))
                    }
                    SecondaryButton(title: tr("Steps", "الخطوات"), symbol: "list.bullet") {
                        store.go(to: .turnByTurn(plan))
                    }
                }
                .padding(16)
                .responsiveContentWidth()
                .background(.bar)
            }
            .navigationTitle(plan.destination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DeadlineChip(text: tr("Board \(store.translator.clock(store.flight.boardingTime))",
                                          "الصعود \(store.translator.clock(store.flight.boardingTime))"))
                }
            }
    }
}

/// 09 — Turn-by-turn.
///
/// Three things compete for this screen and the ranking is decided once: the
/// next instruction, the deadline, and the assistant. The instruction wins —
/// it is why the screen is open — so it takes the top slab in high contrast,
/// sized to be read at a glance while moving.
struct TurnByTurnView: View {
    let plan: RoutePlan

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    @State private var stepIndex = 0

    private var step: NavigationStep { plan.steps[min(stepIndex, plan.steps.count - 1)] }
    private var nextStep: NavigationStep? {
        stepIndex + 1 < plan.steps.count ? plan.steps[stepIndex + 1] : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            AirportMapView(
                plan: plan,
                confidence: store.positionConfidence,
                progress: Double(stepIndex) / Double(max(plan.steps.count - 1, 1))
            )
            .ignoresSafeArea()

            instructionSlab
        }
        .safeAreaInset(edge: .bottom) { summarySheet }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(tr("End", "إنهاء")) { store.path.removeAll() }
                    .tint(Theme.changed)
            }
        }
    }

    /// The instruction, with zero interpretation required. Every instruction
    /// names a visible landmark, because "80 m" is not verifiable by eye for
    /// most people, and "past the duty free" is.
    private var instructionSlab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: step.symbol)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.instruction)
                        .font(Theme.font(.title2, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("for \(step.distanceMetres) m, \(step.landmark)",
                            "لمسافة \(step.distanceMetres) م، \(step.landmark)"))
                        .font(Theme.font(.callout))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // The countdown persists as a chip rather than a card: removing it
            // would push the passenger back to Home to check, and giving it
            // equal weight would compete with the instruction.
            DeadlineChip(text: tr("Boarding in \(TimingEngine.countdown(minutes: store.minutesToBoarding))",
                                  "الصعود خلال \(TimingEngine.countdown(minutes: store.minutesToBoarding))"))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .responsiveContentWidth()
        .accessibilityElement(children: .combine)
    }

    private var summarySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent {
                Text(tr("\(plan.totalWalkMinutes) min · \(plan.distanceMetres) m · arrive \(store.translator.clock(TimingEngine.arrival(leaving: store.now, walkMinutes: plan.totalWalkMinutes)))",
                        "\(plan.totalWalkMinutes) د · \(plan.distanceMetres) م · الوصول \(store.translator.clock(TimingEngine.arrival(leaving: store.now, walkMinutes: plan.totalWalkMinutes)))"))
                    .font(Theme.font(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
            } label: {
                Text(plan.destination)
                    .font(Theme.font(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            if let nextStep {
                Label(tr("Then: \(nextStep.instruction) \(nextStep.landmark)",
                         "ثم: \(nextStep.instruction) \(nextStep.landmark)"),
                      systemImage: "arrow.turn.down.right")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                // Voice stays available during navigation. Asking "how much
                // further?" without losing the route is the interaction that
                // proves the assistant is a layer rather than a tab.
                Button {
                    store.voice = .idle
                } label: {
                    Image(systemName: "mic.fill")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(Theme.ink)
                .accessibilityLabel(tr("Ask Fly+", "اسأل Fly+"))

                PrimaryButton(title: nextStep == nil ? tr("I've arrived", "لقد وصلت") : tr("Next step", "الخطوة التالية"),
                              symbol: nextStep == nil ? "flag.checkered" : "arrow.forward") {
                    if nextStep == nil {
                        store.path.removeAll()
                    } else {
                        withAnimation(.smooth(duration: 0.25)) { stepIndex += 1 }
                    }
                }
            }
        }
        .padding(16)
        .responsiveContentWidth()
        .background(.bar)
    }
}

/// 10 — Multi-stop route: prayer room, then the gate, as one journey.
struct MultiStopRouteView: View {
    let plan: RoutePlan

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        AirportMapView(plan: plan, confidence: store.positionConfidence)
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                MultiStopRouteCardView(plan: plan) {
                    store.go(to: .turnByTurn(plan))
                } onRemoveStop: {
                    store.go(to: .routeOverview(.toGate))
                }
                .padding(16)
                .responsiveContentWidth()
                .background(.bar)
            }
            .navigationTitle(tr("Your route", "مسارك"))
            .navigationBarTitleDisplayMode(.inline)
    }
}
