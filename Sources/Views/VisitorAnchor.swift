import SwiftUI

// MARK: - Visitor anchor
//
// Home's anchor slot when there is no flight at all. A passenger's anchor is the
// journey card; a visitor's is the assistant, because the assistant is the only
// thing that works without a journey.
//
// Deliberately *not* a question. "What brings you to the airport?" would make
// the app interrogate someone who came here to ask it something — the intents
// below carry the same information as actions instead (§28: choose the direct
// action over the menu).

struct VisitorAnchor: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    @State private var meetSheet = false

    var body: some View {
        VStack(spacing: 18) {
            if tenant.has(.voice) {
                Button {
                    store.assistantPresented = true
                } label: {
                    VStack(spacing: 10) {
                        AssistantOrb(state: .idle, size: 104)
                        Text("Ask me anything about the airport")
                            .font(Type.font(17, .medium))
                            .foregroundStyle(tenant.palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.top, -14)
                    }
                }
                .buttonStyle(.plain)
            }

            intents
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .sheet(isPresented: $meetSheet) {
            MeetArrivalSheet()
                .environment(store)
                .environment(\.tenant, tenant)
                .presentationDetents([.height(440)])
        }
    }

    // MARK: The four things visitors actually come to do

    private var intents: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                intent("Meet someone", "figure.walk.arrival", prominent: true) { meetSheet = true }
                intent("Parking", "parkingsign") { go(.parking) }
            }
            HStack(spacing: 10) {
                intent("Eat & shop", "cup.and.saucer") { go(.food) }
                intent("Airport help", "questionmark.circle") { go(.help) }
            }
        }
    }

    private func go(_ category: POICategory) {
        store.exploreCategory = category
        store.selectedTab = .explore
    }

    private func intent(_ title: String, _ symbol: String,
                        prominent: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(Type.font(15, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .foregroundStyle(prominent ? tenant.palette.onPrimary : tenant.palette.ink)
            .padding(.horizontal, 14)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(prominent ? tenant.palette.primary : tenant.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Metric.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.controlRadius, style: .continuous)
                    .stroke(prominent ? .clear : tenant.palette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meet an arrival
//
// The one visitor intent that re-anchors the whole app: give it a flight and the
// countdown, destination and status all come back. The useful number is not the
// landing time — it's when they actually walk out.

struct MeetArrivalSheet: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var flightNumber = ""
    @State private var name = ""

    private var canContinue: Bool {
        flightNumber.trimmingCharacters(in: .whitespaces).count >= 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Meet an arrival")
                    .font(Type.system(22, .bold))
                    .foregroundStyle(tenant.palette.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
            }

            Text("I'll track the flight and tell you when they'll actually come through — landing time isn't the same as walking out.")
                .font(Type.font(15))
                .foregroundStyle(tenant.palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Card(padding: 15) {
                VStack(alignment: .leading, spacing: 14) {
                    field("Flight number") {
                        TextField("e.g. MS673", text: $flightNumber)
                            .font(Type.font(17, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    Hairline()
                    field("Who are you meeting? (optional)") {
                        TextField("Name", text: $name)
                            .font(Type.font(17, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                    }
                }
            }

            Button {
                flightNumber = store.demoArrival.number
            } label: {
                Text("Demo fills \(store.demoArrival.number) from \(store.demoArrival.originCity)")
                    .font(Type.font(13))
                    .foregroundStyle(tenant.palette.primary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            PrimaryButton(title: "Track this arrival", enabled: canContinue) {
                store.startMeeting(name: name.isEmpty ? nil : name)
                dismiss()
            }
        }
        .padding(Metric.gutter)
        .padding(.top, 8)
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(Type.font(10, .semibold)).tracking(0.6)
                .foregroundStyle(tenant.palette.inkMuted)
            content()
        }
    }
}
