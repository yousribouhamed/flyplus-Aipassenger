import SwiftUI

// MARK: - Explore
//
// §16: "Avoid a traditional airport directory as the primary experience.
//  Prioritize: Nearby · Relevant · On my route · I have time for this."
//
// The ranking is shared with the assistant, so both surfaces agree about what
// "relevant" means — a directory sorted by distance would not.

struct ExploreView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @State private var selectedPOI: POI?

    private var results: [ExploreResult] { store.nearby }
    /// What actually gets rendered. "On my route" only means something when there
    /// *is* a route — for a visitor with nowhere to be it would filter out the
    /// entire terminal, so the constraint simply doesn't apply to them.
    private var feasible: [ExploreResult] {
        results.filter {
            $0.feasibility.isFeasible && ($0.feasibility.isUnbounded || $0.feasibility.isOnRoute)
        }
    }

    private var groupTitle: String { store.hasDeadline ? "On your route" : "Nearby" }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if feasible.isEmpty {
                    emptyState
                } else {
                    group(title: groupTitle, items: feasible)
                }

                Color.clear.frame(height: 168)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
        .sheet(item: $selectedPOI) { poi in
            POIDetailSheet(poi: poi)
                .environment(store)
                .presentationDetents([.height(320)])
        }
    }

    @ViewBuilder
    private func group(title: String, items: [ExploreResult]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title)
                Card(padding: 14) {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            POIRow(result: item) { selectedPOI = item.poi }
                                .padding(.vertical, 9)
                            if index < items.count - 1 { Hairline() }
                        }
                    }
                }
            }
        }
    }

    /// Nothing to browse is not an error — it is usually the platform telling the
    /// passenger they are out of time. The assistant is the better answer than a
    /// magnifying glass, so the orb takes the space and invites the question.
    private var emptyState: some View {
        VStack(spacing: 16) {
            if tenant.has(.voice) {
                AssistantOrb(state: .idle, size: 108)
            }

            Text(emptyMessage)
                .font(Type.font(19, .medium))
                .foregroundStyle(tenant.palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.top, tenant.has(.voice) ? -14 : 0)

            if tenant.has(.voice) {
                FlowChips(prompts: emptyPrompts) { prompt in
                    store.assistantPresented = true
                    store.ask(prompt)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 96)
    }

    private var emptyMessage: String {
        // A visitor has no boarding time, so never say they're out of time for it.
        if !store.hasDeadline {
            if let category = store.exploreCategory {
                return "There's no \(category.title.lowercased()) in this part of the terminal. Ask me and I'll look wider."
            }
            return "I can help you find your way around the terminal. Ask me anything."
        }
        if store.isBehindSchedule || store.availableMinutes <= 0 {
            return "There's no time to stop before boarding. Ask me and I'll get you to \(store.destinationName)."
        }
        if let category = store.exploreCategory {
            return "Nothing in \(category.title.lowercased()) fits the time you have. Ask me and I'll look wider."
        }
        return "I know your flight, your gate and how long you have. Ask me anything."
    }

    private var emptyPrompts: [String] {
        if !store.hasDeadline {
            return ["Where can I get a taxi?", "Where's the meeting point?", "Where can I park?"]
        }
        if store.isBehindSchedule || store.availableMinutes <= 0 {
            return ["Take me to my gate", "How long do I have?"]
        }
        return ["What should I do next?", "Where can I get coffee?", "How long do I have?"]
    }
}
