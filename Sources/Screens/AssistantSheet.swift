import SwiftUI

/// 03, 04, 05 — the assistant, as a sheet over the journey.
///
/// Voice must not open a blank full-screen interface. The journey behind the
/// sheet is exactly what the passenger is talking about: "Where should I go?"
/// only works as a question if the system can see the flight behind it. That
/// is the minority choice in the category — Character AI, DeepSeek and Manus
/// all clear the screen — but CVS and State Farm ship the sheet, and here
/// there is something behind it worth keeping.
///
/// `presentationBackgroundInteraction` is what makes that literal rather than
/// decorative: the journey stays live behind the sheet, not a screenshot.
struct AssistantSheet: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var detent: PresentationDetent = .medium
    @State private var typed = ""
    @State private var isTyping = false
    @FocusState private var textFocused: Bool

    private var reduceMotion: Bool { systemReduceMotion || store.reduceMotion }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(20)
                .responsiveContentWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { controls }
            .navigationTitle(tr("Ask Fly+", "اسأل Fly+"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Context is never re-asked, so the sheet carries the journey
                // facts the passenger is asking about rather than making them
                // dismiss it to check.
                ToolbarItem(placement: .topBarLeading) {
                    Text(tr("Gate \(store.flight.gate) · \(TimingEngine.countdown(minutes: store.minutesToBoarding))",
                            "البوابة \(store.flight.gate) · \(TimingEngine.countdown(minutes: store.minutesToBoarding))"))
                        .font(Theme.font(.footnote, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink3)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Cancel", "إلغاء")) { store.voice = .closed }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .onChange(of: store.voice) { _, new in
            // A response with components needs the room; listening does not.
            detent = new.response == nil ? .medium : .large
        }
    }

    // MARK: State machine

    @ViewBuilder
    private var content: some View {
        switch store.voice {
        case .closed, .idle:
            idleState
        case .listening(let partial):
            listeningState(partial: partial)
        case .processing(let transcript, let reasoning):
            processingState(transcript: transcript, reasoning: reasoning)
        case .speaking(let response), .finished(let response):
            responseState(response)
        case .failed(let failure):
            failureState(failure)
        }
    }

    private var idleState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("What can I help you find?", "بماذا يمكنني مساعدتك؟"))
                .font(Theme.font(.title2, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(tr("Try saying", "جرّب أن تقول")).kickerStyle()

            // Suggested utterances, greyed in. They change with journey state,
            // so the examples are always questions worth asking right now.
            FlowChips(items: suggestions) { ask($0) }
        }
    }

    private func listeningState(partial: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(tr("Listening…", "أستمع…"), systemImage: "waveform")
                .font(Theme.font(.title3, weight: .bold))
                .foregroundStyle(Theme.ink)

            // Live transcription does two jobs: it proves the microphone is
            // working, and it lets the passenger catch a misheard word before
            // the system acts on it.
            Text(partial.isEmpty ? tr("Go ahead.", "تفضّل.") : "“\(partial)”")
                .font(Theme.font(.title3))
                .foregroundStyle(partial.isEmpty ? Theme.ink3 : Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            WaveformView(isAnimating: !reduceMotion)
        }
    }

    private func processingState(transcript: String, reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("“\(transcript)”")
                .font(Theme.font(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Name the reasoning, not the process. "Checking your time and
            // what's on your route" tells the passenger the system understood
            // the question, and justifies the wait by naming work worth
            // waiting for. Never "Thinking…", never a bare spinner.
            HStack(spacing: 10) {
                ProgressView()
                Text(reasoning)
                    .font(Theme.font(.callout))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func responseState(_ response: AssistantResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("“\(response.transcript)”")
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.surface2, in: Capsule())

            // The spoken answer and the written answer are the same words. If
            // voice says something the screen does not, the passenger has to
            // choose which to trust.
            Text(response.answer)
                .font(Theme.font(.title3, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(response.components) { component in
                ResponseComponentView(component: component)
            }

            if let primary = response.primary {
                PrimaryButton(title: primary.label, symbol: "arrow.forward") {
                    store.go(to: primary.destination)
                }
            }
            if let alternative = response.alternative {
                SecondaryButton(title: alternative.label) {
                    store.go(to: alternative.destination)
                }
            }
        }
    }

    private func failureState(_ failure: VoiceFailure) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentUnavailableView {
                Label(failure.message, systemImage: failure.symbol)
            } description: {
                Text(tr("Each of these has its own way back — speaking again isn't always the answer.",
                        "لكل حالة طريقة خروج خاصة — إعادة الكلام ليست دائماً الحل."))
            }

            ForEach(failure.recovery, id: \.self) { option in
                SecondaryButton(title: option) { recover(option, from: failure) }
            }
        }
    }

    // MARK: Controls

    /// Cancel and "Type instead" are present in every voice state. Parity with
    /// text is an accessibility requirement, not a fallback — and in a
    /// terminal full of strangers it is often the only usable path.
    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 10) {
            if isTyping {
                HStack(spacing: 8) {
                    TextField(tr("Ask about your journey", "اسأل عن رحلتك"), text: $typed)
                        .textFieldStyle(.roundedBorder)
                        .focused($textFocused)
                        .submitLabel(.send)
                        .onSubmit { ask(typed) }
                    Button {
                        ask(typed)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                    }
                    .buttonStyle(.plain)
                    .tint(Theme.brand)
                    .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                HStack(spacing: 14) {
                    if let response = store.voice.response {
                        // Speaking shows Stop; finished shows Replay.
                        if case .speaking = store.voice {
                            SecondaryButton(title: tr("Stop", "إيقاف"), symbol: "stop.fill") {
                                store.voice = .finished(response)
                            }
                        } else {
                            SecondaryButton(title: tr("Replay", "إعادة"), symbol: "arrow.clockwise") {
                                store.voice = .speaking(response)
                            }
                        }
                    } else {
                        micButton
                    }
                }
            }

            Button(isTyping ? tr("Use voice", "استخدم الصوت") : tr("Type instead", "اكتب بدلاً من ذلك")) {
                isTyping.toggle()
                textFocused = isTyping
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .tint(Theme.brand)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .responsiveContentWidth()
        .background(.bar)
    }

    /// Tap for hands-free, press and hold for push-to-talk.
    ///
    /// Holding a button is quieter, more private and more precise in noise,
    /// and it makes the microphone's state unambiguous — which matters when
    /// the alternative is an app that may or may not be listening in a room
    /// full of strangers.
    private var micButton: some View {
        Button {
            beginListening()
        } label: {
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .tint(Theme.ink)
        .accessibilityLabel(tr("Ask Fly+ by voice", "اسأل Fly+ صوتياً"))
        .accessibilityHint(tr("Hold to talk, or tap and speak", "اضغط مطولاً للتحدث، أو اضغط ثم تحدث"))
        .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
            if pressing { beginListening() }
        }, perform: {})
    }

    private var isListening: Bool {
        if case .listening = store.voice { return true }
        return false
    }

    private var suggestions: [String] {
        [store.suggestedUtterance,
         tr("I want to pray before boarding", "أريد الصلاة قبل الصعود"),
         tr("Show my flight", "اعرض رحلتي"),
         tr("Can you deliver my bags home?", "هل يمكنكم توصيل حقائبي إلى المنزل؟")]
    }

    // MARK: Behaviour

    private func beginListening() {
        guard !isListening else { return }
        let utterance = store.suggestedUtterance
        store.voice = .listening(partial: "")
        Task {
            // The POC streams a partial transcript rather than running speech
            // recognition: the state machine, the timings and the escape
            // hatches are what need to be right at this stage.
            var built = ""
            for word in utterance.split(separator: " ") {
                try? await Task.sleep(for: .milliseconds(160))
                guard isListening else { return }
                built += built.isEmpty ? String(word) : " \(word)"
                store.voice = .listening(partial: built)
            }
            try? await Task.sleep(for: .milliseconds(350))
            guard isListening else { return }
            ask(built)
        }
    }

    private func ask(_ utterance: String) {
        let text = utterance.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            store.voice = .failed(.noSpeech)
            return
        }
        typed = ""
        isTyping = false
        textFocused = false

        let response = store.respond(to: text)
        store.voice = .processing(transcript: text, reasoning: response.reasoning)

        Task {
            try? await Task.sleep(for: .milliseconds(900))
            store.voice = .speaking(response)
            try? await Task.sleep(for: .milliseconds(1400))
            if case .speaking = store.voice {
                store.voice = .finished(response)
            }
        }
    }

    private func recover(_ option: String, from failure: VoiceFailure) {
        switch option {
        case tr("Try again", "حاول مجدداً"), tr("Retry", "أعد المحاولة"):
            beginListening()
        case tr("Type instead", "اكتب بدلاً من ذلك"):
            isTyping = true
            textFocused = true
        case tr("Explore nearby", "استكشف ما حولي"):
            store.go(to: .explore)
        case tr("Help", "المساعدة"):
            store.go(to: .help(.missedConnection))
        default:
            store.voice = .idle
        }
    }
}

/// Input-reactive waveform. A looping animation that ignores the microphone
/// teaches people the app is lying, so the bars are driven by a level source —
/// in the POC, a simulated one — and they stop entirely under Reduce Motion,
/// where a static bar row stands in.
struct WaveformView: View {
    var isAnimating: Bool
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 24)

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.brand)
                    .frame(width: 3, height: max(4, levels[index] * 34))
            }
        }
        .frame(height: 38, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
        .task(id: isAnimating) {
            guard isAnimating else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.easeOut(duration: 0.12)) {
                    levels = levels.map { _ in CGFloat.random(in: 0.15...1.0) }
                }
            }
        }
    }
}
