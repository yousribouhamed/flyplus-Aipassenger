import SwiftUI

/// Four tabs and one assistant.
///
/// Services is deliberately not a tab. A permanent Services tab turns a
/// journey product into a marketplace — the moment it has a home, someone
/// fills it, ranks it and puts a promotion in it, and the journey stops being
/// the interface. Services surface contextually instead, from Home, Explore,
/// the assistant and journey events. Help is a destination the assistant can
/// open, not a settings row.
///
/// The microphone takes the centre slot, which is where Walmart puts
/// "Ask Sparky" in its five-slot bar. It is the reachable position for a
/// walking passenger's thumb — and it is an assumption worth testing, not a
/// settled fact, because Delta ships the same assistant in the header instead.
enum AppTab: Hashable {
    case home, navigate, ask, explore, more
}

struct RootView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    var body: some View {
        @Bindable var store = store

        NavigationStack(path: $store.path) {
            TabView(selection: tabSelection) {
                Tab(value: AppTab.home) {
                    HomeView()
                } label: {
                    Label(tr("Home", "الرئيسية"), systemImage: "house.fill")
                }

                Tab(value: AppTab.navigate) {
                    NavigateTabView()
                } label: {
                    Label(tr("Navigate", "التنقل"), systemImage: "map.fill")
                }

                // Selecting this tab opens the assistant rather than switching
                // to a chat screen: the assistant is a layer over the product,
                // and the moment it becomes a place you visit it has turned
                // into a menu with extra steps.
                Tab(value: AppTab.ask) {
                    Color.clear
                } label: {
                    Label(tr("Ask", "اسأل"), systemImage: "mic.fill")
                }

                Tab(value: AppTab.explore) {
                    ExploreView()
                } label: {
                    Label(tr("Explore", "استكشف"), systemImage: "sparkle.magnifyingglass")
                }

                Tab(value: AppTab.more) {
                    MoreView()
                } label: {
                    Label(tr("More", "المزيد"), systemImage: "ellipsis")
                }
            }
            .tint(Theme.brand)
            .tabBarMinimizeBehavior(.onScrollDown)
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
        }
        .sheet(isPresented: voiceSheetBinding) {
            AssistantSheet()
        }
    }

    /// Intercepts the centre slot so tapping the microphone opens the
    /// assistant and leaves the passenger where they were.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { store.selectedTab },
            set: { newValue in
                if newValue == .ask {
                    store.voice = .idle
                } else {
                    store.selectedTab = newValue
                }
            }
        )
    }

    private var voiceSheetBinding: Binding<Bool> {
        Binding(
            get: { store.voice.isOpen },
            set: { isOpen in if !isOpen { store.voice = .closed } }
        )
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .flightDetail:
            FlightDetailView()
        case .routeOverview(let plan):
            RouteOverviewView(plan: plan)
        case .turnByTurn(let plan):
            TurnByTurnView(plan: plan)
        case .multiStop(let plan):
            MultiStopRouteView(plan: plan)
        case .serviceFlow(let offer):
            ServiceFlowView(offer: offer)
        case .confirmation(let draft):
            ConfirmationView(draft: draft)
        case .help(let topic):
            HelpView(topic: topic)
        case .disruption(let alert):
            DisruptionView(alert: alert)
        }
    }
}
