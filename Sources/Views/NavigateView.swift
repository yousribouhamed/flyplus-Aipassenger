import SwiftUI

// MARK: - Navigate
//
// §14/§15. Google-Maps conventions, but the journey context stays on screen:
// the brief is explicit that "Gate 32 · 7 min" alone is weaker than
// "Boarding in 34 min / Gate 32 · 7 min walk".

struct NavigateView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    @State private var legProgress: Double = 0
    @State private var selectedPOI: POI?
    @State private var liveViewPresented = false

    private var route: Route? { store.activeRoute }

    private var instructions: [TurnInstruction] {
        guard let route else { return [] }
        return store.router.instructions(for: route)
    }

    /// The instruction that applies to the leg the passenger is currently on.
    private var currentInstruction: TurnInstruction? {
        guard let route,
              let idx = route.nodes.firstIndex(where: { $0.id == store.context.locationNodeID })
        else { return instructions.first }
        return idx < instructions.count ? instructions[idx] : instructions.last
    }

    var body: some View {
        VStack(spacing: 0) {
            AirportMapView(map: store.map,
                           route: route,
                           currentNodeID: store.context.locationNodeID,
                           zone: store.context.zone,
                           legProgress: legProgress,
                           showsAllPOIs: !store.isNavigating,
                           showsYouAreHere: route == nil,
                           onSelect: { selectedPOI = $0 })
                .padding(.top, store.isNavigating ? 128 : 78)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    Group {
                        if store.isNavigating, let instruction = currentInstruction {
                            turnCard(instruction)
                        } else {
                            contextStrip
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 6)
                }

            bottomPanel
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
        .sheet(item: $selectedPOI) { poi in
            POIDetailSheet(poi: poi)
                .environment(store)
                .presentationDetents([.height(320)])
        }
        .fullScreenCover(isPresented: $liveViewPresented) {
            LiveViewNavigation(instruction: currentInstruction, route: route)
                .environment(store)
                .environment(\.tenant, tenant)
        }
        .onChange(of: store.context.locationNodeID) { _, _ in
            legProgress = 0
        }
    }

    // MARK: Journey context — always visible

    /// With a route, name the destination. Without one, name where they are —
    /// a plan of a whole terminal is useless if you can't find yourself on it.
    private var headline: String {
        if let dest = store.activeRoute?.destination?.name { return dest }
        if store.destinationNodeID != nil { return store.destinationName }
        return store.map.node(store.context.locationNodeID)?.name ?? "You are here"
    }

    /// A visitor has no deadline, so the strip shows where they are instead of
    /// counting down to something that doesn't exist.
    private var contextStrip: some View {
        Card(padding: 13) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(Type.font(17, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    Text(store.hasDeadline ? "\(store.deadlineLabel) \(store.deadlineClock ?? "")"
                                           : store.map.terminalLabel(for: store.context.zone))
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
                Spacer()
                if store.hasDeadline {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimingEngine.durationPhrase(store.minutesToDeadline))
                            .font(Type.mono(17, .semibold))
                            .foregroundStyle(store.isBehindSchedule ? tenant.palette.warning : tenant.palette.ink)
                        Text(store.mode == .meeting ? "until they're out" : "until boarding")
                            .font(Type.font(12))
                            .foregroundStyle(tenant.palette.inkMuted)
                    }
                }
            }
        }
    }

    // MARK: Turn-by-turn instruction

    private func turnCard(_ instruction: TurnInstruction) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: instruction.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tenant.palette.onPrimary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(instruction.text)
                        .font(Type.font(18, .semibold))
                        .foregroundStyle(tenant.palette.onPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(instruction.detail)
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.onPrimary.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(tenant.palette.primary)

            // Journey context stays visible while navigating.
            if store.hasDeadline {
                HStack {
                    MetaPill(symbol: store.mode == .meeting ? "figure.walk.arrival" : "airplane.departure",
                             text: "\(store.deadlineLabel) \(store.deadlineClock ?? "")")
                    Spacer()
                    MetaPill(symbol: "clock", text: "\(TimingEngine.durationPhrase(store.minutesToDeadline)) left")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(tenant.palette.surface)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
    }

    // MARK: Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        if let route {
            VStack(spacing: 0) {
                Capsule().fill(tenant.palette.hairline)
                    .frame(width: 38, height: 5)
                    .padding(.top, 9)

                VStack(alignment: .leading, spacing: 14) {
                    routeSummary(route)

                    if route.stopNodeID != nil { multiStopTimeline(route) }

                    if store.isNavigating {
                        // Live View is offered only while actually walking a leg —
                        // it is meaningless from the overview.
                        Button {
                            liveViewPresented = true
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Live View")
                                    .font(Type.font(15, .semibold))
                                Spacer()
                                Text("Point your camera down the concourse")
                                    .font(Type.font(12))
                                    .foregroundStyle(tenant.palette.inkMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(tenant.palette.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(tenant.palette.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: Metric.controlRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 10) {
                            SecondaryButton(title: "End", symbol: "xmark") {
                                store.stopNavigating()
                            }
                            PrimaryButton(title: nextStepLabel(route), symbol: "figure.walk") {
                                withAnimation(.easeInOut(duration: 0.45)) { legProgress = 1 }
                                Task {
                                    try? await Task.sleep(for: .milliseconds(460))
                                    store.advanceAlongRoute()
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            SecondaryButton(title: "Overview", symbol: "map") {
                                store.stopNavigating()
                            }
                            PrimaryButton(title: "Start", symbol: "location.north.line.fill") {
                                store.startNavigating()
                            }
                        }
                    }

                    accessibilityToggle
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 14)
                .padding(.bottom, 150)
            }
            .background(tenant.palette.surface)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.09), radius: 18, y: -6)
        } else {
            VStack(spacing: 0) {
                if store.destinationNodeID != nil {
                    // Somewhere to be: one action, no question (§10).
                    PrimaryButton(title: "Take me to \(store.destinationName)",
                                  symbol: "location.north.fill") {
                        store.routeToGate()
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 18)
                    .padding(.bottom, 150)
                } else {
                    // A visitor genuinely has nowhere to be, so here the question
                    // is honest — and the plan above is the answer surface.
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Where to?")
                            .font(Type.font(17, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                        Text("Tap anywhere on the plan, or pick one of these.")
                            .font(Type.font(13))
                            .foregroundStyle(tenant.palette.inkMuted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickDestinations) { poi in
                                    Button {
                                        store.routeTo(poi.id)
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: poi.category.symbol)
                                                .font(.system(size: 13, weight: .semibold))
                                            Text(poi.name)
                                                .font(Type.font(14, .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(tenant.palette.ink)
                                        .padding(.horizontal, 13)
                                        .frame(height: 40)
                                        .background(tenant.palette.canvasTop)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(tenant.palette.hairline, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 150)
                }
            }
            .background(tenant.palette.surface)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.09), radius: 18, y: -6)
        }
    }

    /// The handful of places a visitor most often wants, in walking order.
    private var quickDestinations: [POI] {
        let priority: [POICategory] = [.arrivals, .help, .food, .transport, .parking, .atm, .shopping]
        return store.map.pois(in: store.context.zone)
            .filter { priority.contains($0.category) }
            .sorted { a, b in
                let ia = priority.firstIndex(of: a.category) ?? 99
                let ib = priority.firstIndex(of: b.category) ?? 99
                return ia == ib ? a.name < b.name : ia < ib
            }
    }

    private func nextStepLabel(_ route: Route) -> String {
        guard let idx = route.nodes.firstIndex(where: { $0.id == store.context.locationNodeID }),
              idx + 1 < route.nodes.count
        else { return "Arrived" }
        return "Walk to \(route.nodes[idx + 1].name)"
    }

    private func routeSummary(_ route: Route) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(route.destination?.name ?? "Destination")
                    .font(Type.font(21, .semibold))
                    .foregroundStyle(tenant.palette.ink)
                HStack(spacing: 8) {
                    Text("\(route.minutes) min")
                        .font(Type.mono(14, .semibold))
                        .foregroundStyle(tenant.palette.primary)
                    Text("· \(Int(route.metres)) m · Level \(store.map.floor(for: store.context.zone))")
                        .font(Type.font(14))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Arrive")
                    .font(Type.font(12))
                    .foregroundStyle(tenant.palette.inkMuted)
                Text(TimingEngine.clock(store.now.addingTimeInterval(Double(route.minutes) * 60)))
                    .font(Type.mono(17, .semibold))
                    .foregroundStyle(tenant.palette.ink)
            }
        }
    }

    /// §15 — the stop must never hide the final destination.
    private func multiStopTimeline(_ route: Route) -> some View {
        let stop = route.stopNodeID.flatMap { store.map.poi($0) }
        return VStack(alignment: .leading, spacing: 0) {
            timelineRow(symbol: "location.fill", title: "You", trailing: nil, tint: tenant.palette.inkMuted)
            timelineConnector(minutes: route.minutesToStop())
            timelineRow(symbol: stop?.category.symbol ?? "mappin",
                        title: stop?.name ?? "Stop",
                        trailing: stop.map { "~\($0.dwellMinutes) min stop" },
                        tint: tenant.palette.success)
            timelineConnector(minutes: route.minutesFromStop())
            timelineRow(symbol: "airplane.departure",
                        title: store.destinationName,
                        trailing: "Boarding \((store.deadlineClock ?? "—"))",
                        tint: tenant.palette.primary)
        }
        .padding(13)
        .background(tenant.palette.canvasTop)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func timelineRow(symbol: String, title: String, trailing: String?, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.14))
                .clipShape(Circle())
            Text(title)
                .font(Type.font(15, .semibold))
                .foregroundStyle(tenant.palette.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Type.font(12))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
        }
    }

    private func timelineConnector(minutes: Int?) -> some View {
        HStack(spacing: 11) {
            Rectangle()
                .fill(tenant.palette.hairline)
                .frame(width: 2, height: 18)
                .padding(.leading, 10)
            if let minutes {
                Text("\(minutes) min walk")
                    .font(Type.font(12))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
            Spacer()
        }
    }

    private var accessibilityToggle: some View {
        @Bindable var store = store
        return Toggle(isOn: $store.accessibleRouteOnly) {
            HStack(spacing: 7) {
                Image(systemName: "figure.roll")
                    .font(.system(size: 13, weight: .medium))
                Text("Step-free route")
                    .font(Type.font(14, .medium))
            }
            .foregroundStyle(tenant.palette.ink)
        }
        .tint(tenant.palette.primary)
        .onChange(of: store.accessibleRouteOnly) { _, _ in
            if let stop = store.activeRoute?.stopNodeID {
                store.route(via: stop)
            } else if store.activeRoute != nil {
                store.routeToGate()
            }
        }
    }
}

// MARK: - POI detail

struct POIDetailSheet: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let poi: POI

    private var result: ExploreResult? {
        Assistant.rank(category: nil, context: store.context, now: store.now,
                       map: store.map, router: store.router,
                       directWalkMinutes: store.walkMinutesToGate)
            .first { $0.poi.id == poi.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: poi.category.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tenant.palette.primary)
                    .frame(width: 44, height: 44)
                    .background(tenant.palette.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(poi.name)
                        .font(Type.font(19, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    Text(poi.detail)
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
                Spacer()
            }

            if let result {
                HStack(spacing: 18) {
                    stat("Walk", "\(result.walkMinutes) min")
                    stat("Typical stop", "\(poi.dwellMinutes) min")
                    stat(result.feasibility.isOnRoute ? "Detour" : "Adds",
                         result.feasibility.isOnRoute ? "On route" : "\(result.feasibility.addedWalkMinutes) min")
                }

                Text(result.feasibility.isFeasible
                     ? "You'd still reach \(store.destinationName) with about \(result.feasibility.sparedMinutes) minutes to spare."
                     : "This would leave you \(abs(result.feasibility.sparedMinutes)) minutes short for boarding.")
                    .font(Type.font(14))
                    .foregroundStyle(result.feasibility.isFeasible ? tenant.palette.success : tenant.palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                SecondaryButton(title: "Go to gate", symbol: "airplane.departure") {
                    store.routeToGate(); store.startNavigating(); dismiss()
                }
                PrimaryButton(title: "Take me there", symbol: "location.north.line.fill") {
                    store.route(via: poi.id); store.startNavigating(); dismiss()
                }
            }
        }
        .padding(Metric.gutter)
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Type.font(10, .semibold)).tracking(0.6)
                .foregroundStyle(tenant.palette.inkMuted)
            Text(value)
                .font(Type.font(16, .semibold))
                .foregroundStyle(tenant.palette.ink)
        }
    }
}
