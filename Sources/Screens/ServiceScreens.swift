import SwiftUI

/// 11 — From conversation into a service.
///
/// This is where the product stops being an assistant and becomes a business,
/// and the risk is a hand-off that feels like being dumped into a different
/// app. Three things stop that: the conversation stays on screen, the step
/// counter promises an end, and the journey context never disappears.
struct ServiceFlowView: View {
    let offer: ServiceOffer

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    @State private var step = 1
    @State private var draft: ServiceDraft
    @FocusState private var addressFocused: Bool

    private let totalSteps = 3

    init(offer: ServiceOffer) {
        self.offer = offer
        _draft = State(initialValue: ServiceDraft(offer: offer))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                transcript

                ServiceCardView(offer: offer)

                if offer.availability.isAvailable {
                    // One decision per step. The passenger is walking; a
                    // five-field form is a wall.
                    switch step {
                    case 1: quantityStep
                    case 2: addressStep
                    default: reviewStep
                    }
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
        .navigationTitle(offer.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(tr("Step \(step) of \(totalSteps)", "الخطوة \(step) من \(totalSteps)"))
                    .font(Theme.font(.footnote, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var transcript: some View {
        Text("“\(tr("Can you deliver my bags home?", "هل يمكنكم توصيل حقائبي إلى المنزل؟"))”")
            .font(Theme.font(.footnote, weight: .semibold))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface2, in: Capsule())
    }

    private var quantityStep: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(offer.firstQuestion)
                    .font(Theme.font(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)

                // A segmented picker is the right control for a small, bounded
                // set: one tap, no keyboard, and it reads at a glance while
                // walking. A Stepper would need two.
                Picker(offer.firstQuestion, selection: $draft.quantity) {
                    ForEach(1...4, id: \.self) { count in
                        Text(count == 4 ? "4+" : "\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(tr("You'll confirm the address and pay before anything is booked.",
                        "ستؤكد العنوان وتدفع قبل تأكيد أي حجز."))
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .groupBoxStyle(FlyCardStyle())
    }

    private var addressStep: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Where should we deliver?", "إلى أين نوصلها؟"))
                    .font(Theme.font(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)

                TextField(tr("Street address", "العنوان"), text: $draft.deliveryAddress)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.streetAddressLine1)
                    .focused($addressFocused)
                TextField(tr("City and postcode", "المدينة والرمز البريدي"), text: $draft.deliveryCity)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.postalCode)

                Text(tr("Nothing is booked yet.", "لم يتم الحجز بعد."))
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .groupBoxStyle(FlyCardStyle())
    }

    private var reviewStep: some View {
        ConfirmationCardView(draft: draft) {
            store.path.append(.confirmation(draft))
        } onBack: {
            withAnimation { step = 2 }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if offer.availability.isAvailable && step < totalSteps {
                PrimaryButton(title: tr("Continue", "متابعة")) {
                    withAnimation(.smooth(duration: 0.25)) { step += 1 }
                }
            }

            // The product has just asked a walking passenger under time
            // pressure to complete a form. It owes them permission to stop.
            Text(tr("Boarding in \(TimingEngine.countdown(minutes: store.minutesToBoarding)) · you can finish this at the gate",
                    "الصعود خلال \(TimingEngine.countdown(minutes: store.minutesToBoarding)) · يمكنك إكمال هذا عند البوابة"))
                .font(Theme.font(.caption).monospacedDigit())
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .responsiveContentWidth()
        .background(.bar)
    }
}

/// 12 — Action confirmation.
///
/// Voice may start an action; nothing consequential completes without explicit
/// visual confirmation. If the passenger says "yes" aloud while this screen is
/// open, that does not count — the tap is the consent.
struct ConfirmationView: View {
    let draft: ServiceDraft

    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    @State private var stage: Stage = .ready
    @State private var otp = ""

    private enum Stage { case ready, awaitingOTP, confirmed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch stage {
                case .ready:
                    ConfirmationCardView(draft: draft) {
                        withAnimation { stage = .awaitingOTP }
                    } onBack: {
                        store.path.removeLast()
                    }

                case .awaitingOTP:
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(tr("Enter the code we sent to \(draft.maskedPhone)",
                                    "أدخل الرمز الذي أرسلناه إلى \(draft.maskedPhone)"))
                                .font(Theme.font(.headline, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            TextField("000000", text: $otp)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(Theme.font(.title2, weight: .bold).monospacedDigit())

                            // Existing Fly+ authentication and OTP rules apply
                            // unchanged; sign-in appears at the payment step,
                            // never earlier.
                            Text(tr("Demo code: 000000", "رمز العرض التجريبي: ٠٠٠٠٠٠"))
                                .font(Theme.font(.caption))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .groupBoxStyle(FlyCardStyle())

                    PrimaryButton(title: tr("Authorise \(draft.totalLabel)", "أكّد \(draft.totalLabel)"),
                                  symbol: "checkmark.shield.fill",
                                  isEnabled: otp.count >= 6) {
                        withAnimation { stage = .confirmed }
                    }

                case .confirmed:
                    ContentUnavailableView {
                        Label(tr("Booked", "تم الحجز"), systemImage: "checkmark.circle.fill")
                    } description: {
                        Text(tr("\(draft.offer.name) for \(draft.quantity) · \(draft.offer.window). We'll message you when your bags are collected.",
                                "\(draft.offer.name) لعدد \(draft.quantity) · \(draft.offer.window). سنراسلك عند استلام حقائبك."))
                    }
                    .tint(Theme.onSchedule)

                    Text(draft.reversibility)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(title: tr("Back to my journey", "العودة إلى رحلتي"), symbol: "house.fill") {
                        store.go(to: .home)
                    }
                }
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle(tr("Confirm", "التأكيد"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
