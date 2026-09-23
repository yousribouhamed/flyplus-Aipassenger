import SwiftUI

// MARK: - Assistant surface
//
// §12: "Voice should overlay or coexist with the current journey rather than
//  always opening a blank full-screen Voice interface." So this is a sheet over
//  whatever the passenger was doing, and the journey context rides along at the top.
//
// Text and Voice share one transcript (§10) — switching modality loses nothing.

struct AssistantOverlay: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var typed = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            grabber
            contextStrip
            Hairline()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if store.transcript.isEmpty { intro }

                        ForEach(store.transcript) { turn in
                            TurnView(turn: turn)
                                .id(turn.id)
                        }

                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 16)
                }
                .onChange(of: store.transcript.count) { _, _ in
                    withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            composer
        }
        .background(tenant.palette.canvas.ignoresSafeArea())
    }

    private var grabber: some View {
        Capsule().fill(tenant.palette.hairline)
            .frame(width: 38, height: 5)
            .padding(.top, 9)
            .padding(.bottom, 12)
    }

    /// The passenger keeps seeing their journey while talking (§12).
    private var contextStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tenant.palette.primary)
            Text(tenant.assistantName)
                .font(Type.font(15, .semibold))
                .foregroundStyle(tenant.palette.ink)
            Spacer()
            Text(store.contextLine)
                .font(Type.font(12))
                .foregroundStyle(tenant.palette.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 12)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tenant.has(.voice) {
                AssistantOrb(state: .idle, size: 104)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, -18)
            }
            Text(introMessage)
                .font(Type.font(19, .medium))
                .foregroundStyle(tenant.palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

            FlowChips(prompts: introPrompts) { ask($0) }
        }
    }

    /// The assistant must not claim to know a flight when there isn't one.
    private var introMessage: String {
        switch store.mode {
        case .departing:
            "I know your flight, your gate and how long you have. Ask me anything."
        case .meeting:
            "I'm tracking their flight and I'll tell you when they'll actually come through. Ask me anything."
        case .visiting:
            "I know this airport — where things are, how to get there and what's open. Ask me anything."
        }
    }

    private var introPrompts: [String] {
        switch store.mode {
        case .departing:
            ["What should I do next?", "I want to pray first", "How long do I have?", "Can you deliver my bags home?"]
        case .meeting:
            ["When will they be out?", "Where do I wait?", "Where can I get coffee?"]
        case .visiting:
            ["Where can I get a taxi?", "Where can I park?", "I'm meeting someone", "Where's the nearest coffee?"]
        }
    }

    // MARK: Composer — Voice and text in one control

    private var composer: some View {
        VStack(spacing: 12) {
            if store.voiceState != .idle { orbPanel }

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

                if tenant.has(.voice) { micButton }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 10)
        }
    }

    private var micButton: some View {
        Button {
            switch store.voiceState {
            case .listening, .speaking, .processing: store.cancelVoice()
            default: store.beginListening(); inputFocused = false
            }
        } label: {
            AssistantOrb(state: store.voiceState, size: 44, haloSpread: 1.18)
                .frame(width: Metric.controlHeight, height: Metric.controlHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.voiceState == .idle ? "Start speaking" : "Stop")
    }

    /// The orb carries every non-idle state (§11), with cancel always reachable.
    private var orbPanel: some View {
        VStack(spacing: 10) {
            AssistantOrbStage(state: store.voiceState, size: 112) {
                store.cancelVoice()
            }
            .padding(.top, -16)

            // The simulator has no microphone. Rather than fake a transcription,
            // the POC offers the phrases out loud — tapping one is the spoken turn.
            if store.voiceState == .listening {
                FlowChips(prompts: ["What should I do next?",
                                    "I want to pray first",
                                    "Take me to my gate",
                                    "Can you deliver my bags home?"]) { ask($0) }
            }
        }
        .padding(.bottom, 4)
        .padding(.horizontal, Metric.gutter)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private func ask(_ text: String) {
        typed = ""
        inputFocused = false
        store.ask(text)
    }
}

// MARK: - One conversational turn

struct TurnView: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    let turn: AssistantTurn

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Passenger
            Text(turn.question)
                .font(Type.font(16, .medium))
                .foregroundStyle(tenant.palette.onPrimary)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(tenant.palette.primary)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .trailing)

            // Assistant speech
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tenant.palette.primary)
                    .padding(.top, 3)
                Text(turn.response.speech)
                    .font(Type.font(16))
                    .foregroundStyle(tenant.palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Structured UI — the part that makes this more than a chatbot
            ForEach(turn.response.cards) { card in
                AssistantCardView(card: card)
            }

            if !turn.response.followUps.isEmpty {
                FlowChips(prompts: turn.response.followUps) { store.ask($0) }
            }
        }
    }
}

// MARK: - Chip layout

struct FlowChips: View {
    let prompts: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { p in
                    PromptChip(text: p) { onTap(p) }
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
        }
    }
}

// MARK: - Listening waveform

struct Waveform: View {
    @Environment(\.tenant) private var tenant
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(tenant.palette.primary)
                    .frame(width: 3, height: height(for: i))
            }
        }
        .frame(width: 26, height: 22)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let base: [CGFloat] = [8, 16, 22, 14, 9]
        let peak: [CGFloat] = [18, 8, 12, 22, 16]
        return base[index] + (peak[index] - base[index]) * phase
    }
}
