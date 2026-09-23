import SwiftUI

// MARK: - First screen: a conversation, not a form
//
// §5 of the brief: the assistant is an interaction layer across the product, not
// a destination inside it. So the app opens *already talking*, and adding a
// flight is one of the things you can do in that conversation rather than a gate
// in front of it.
//
// The important restraint: the assistant asks, but a **real control answers**.
// Typing "SV117" into a chat box is worse than a labelled field — so the entry
// card is embedded in the conversation as structured UI (§21), not as a prompt.
// Everything from the old form is still here; it just sits inside the dialogue.
//
// Asking anything at all starts a visit (§29's QR case: no ticket, no account,
// just a question), so the passenger can engage before the app knows anything.

struct JourneySetupView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store

    @State private var flightNumber = ""
    @State private var date = "Today"
    @State private var typed = ""
    @State private var working = false
    @FocusState private var inputFocused: Bool

    private var canContinue: Bool { flightNumber.trimmingCharacters(in: .whitespaces).count >= 4 }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    greeting
                    entryCard
                    BoardingPassScanCard { flightNumber = "SV117" }
                    chips
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 28)
            }
            .scrollDismissesKeyboard(.interactively)

            composer
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    // MARK: The assistant speaks first

    private var greeting: some View {
        VStack(spacing: 12) {
            if tenant.has(.voice) {
                AssistantOrb(state: .idle, size: 92)
                    .padding(.bottom, -12)
            }

            Text("Your journey,\nmade simple")
                .font(Type.system(30, .bold))
                .foregroundStyle(tenant.palette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(-4)

            Text("From check-in to your gate, get help at every step. Add your flight, or just ask me something.")
                .font(Type.font(16))
                .foregroundStyle(tenant.palette.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    // MARK: Structured answer, inside the conversation

    private var entryCard: some View {
        Card(padding: 15) {
            VStack(alignment: .leading, spacing: 14) {
                field("Flight number") {
                    TextField("e.g. SV117", text: $flightNumber)
                        .font(Type.font(17, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { if canContinue { start() } }
                }
                Hairline()
                field("Travel date") {
                    HStack {
                        Text(date)
                            .font(Type.font(17, .semibold))
                            .foregroundStyle(tenant.palette.ink)
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(tenant.palette.inkMuted)
                    }
                }

                PrimaryButton(title: working ? "Finding your flight\u{2026}" : "Continue",
                              enabled: canContinue && !working) { start() }
                    .padding(.top, 2)
            }
        }
    }

    private var chips: some View {
        FlowChips(prompts: ["I'm not flying today",
                            "What can you do?",
                            "Where can I park?"]) { prompt in
            if prompt == "I'm not flying today" {
                store.startVisit()
            } else {
                ask(prompt)
            }
        }
    }

    // MARK: Composer — the passenger can skip all of the above

    private var composer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Ask anything\u{2026}", text: $typed)
                    .font(Type.font(16))
                    .foregroundStyle(tenant.palette.ink)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { ask(typed) }
                if !typed.isEmpty {
                    Button { ask(typed) } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(tenant.palette.primary)
                    }
                }
            }
            .padding(.horizontal, 15)
            .frame(height: Metric.controlHeight)
            .background(tenant.palette.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tenant.palette.hairline, lineWidth: 1))

            if tenant.has(.voice) {
                Button { askByVoice() } label: {
                    AssistantOrb(state: .idle, size: 44, haloSpread: 1.18)
                        .frame(width: 52, height: 52)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start speaking")
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 10)
    }

    // MARK: Actions

    private func start() {
        working = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            store.startJourney()
        }
    }

    /// A question is enough to begin. The person becomes a visitor — no ticket,
    /// no account — and the answer is waiting when the app opens.
    private func ask(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        typed = ""
        inputFocused = false
        store.startVisit()
        store.assistantPresented = true
        store.ask(trimmed)
    }

    private func askByVoice() {
        store.startVisit()
        store.beginListening()
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
