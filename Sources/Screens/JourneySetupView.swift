import SwiftUI

/// 01 — Journey setup.
///
/// The whole product is worthless until it knows which flight the passenger is
/// on, and this is the only screen allowed to ask. Two fields, one of them
/// pre-filled with today's date, and an escape hatch for people who would
/// rather point a camera at their boarding pass.
///
/// The line at the bottom is load-bearing: the brief forbids mandatory account
/// creation, so the screen has to say so, or people assume a sign-up wall is
/// coming and leave.
struct JourneySetupView: View {
    @Environment(JourneyStore.self) private var store
    @Environment(\.tr) private var tr

    @State private var flightNumber = ""
    @State private var date = Date()
    @State private var lookup: Lookup = .empty
    @FocusState private var numberFieldFocused: Bool

    private enum Lookup: Equatable {
        case empty
        case validating
        case found(Flight)
        case notFound
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                fields
                result
                Spacer(minLength: 8)
                alternatives
            }
            .padding(20)
            .responsiveContentWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
        .onChange(of: flightNumber) { _, _ in validate() }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image("FlyPlusLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 34)
                .accessibilityLabel("Fly+")
                .padding(.bottom, 12)

            Text(tr("Add your flight", "أضف رحلتك"))
                .font(Theme.font(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(tr("We'll follow it from here and tell you what matters, when it matters.",
                    "سنتابعها من هنا ونخبرك بما يهم، في وقته."))
                .font(Theme.font(.callout))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Flight number", "رقم الرحلة")).kickerStyle()
                    TextField(tr("SV117", "SV117"), text: $flightNumber)
                        .font(Theme.font(.title2, weight: .bold))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($numberFieldFocused)
                        // A flight number is letters then digits, so the plain
                        // keyboard is right — a number pad would block "SV".
                        .keyboardType(.asciiCapable)
                        .onSubmit(findFlight)
                }
            }
            .groupBoxStyle(FlyCardStyle())

            GroupBox {
                LabeledContent {
                    // The platform date picker, pre-filled with today, which
                    // is the answer for almost every passenger who opens this
                    // screen inside an airport.
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                } label: {
                    Text(tr("Date of travel", "تاريخ السفر")).kickerStyle()
                }
            }
            .groupBoxStyle(FlyCardStyle())
        }
    }

    @ViewBuilder
    private var result: some View {
        switch lookup {
        case .empty:
            EmptyView()

        case .validating:
            HStack(spacing: 10) {
                ProgressView()
                Text(tr("Looking up \(flightNumber)…", "جارٍ البحث عن \(flightNumber)…"))
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .found(let flight):
            // Tripsy shows the matched flight inline as you type, so the
            // passenger confirms a real flight rather than trusting that the
            // string they typed was understood.
            Button(action: confirm) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(flight.airline) \(flight.number)")
                            .font(Theme.font(.headline, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        StatusPill(status: flight.status)
                    }
                    RouteStrip(flight: flight, showsCityNames: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .cardSurface()

        case .notFound:
            // The platform's own empty state, so the recovery path looks like
            // every other "nothing here" the passenger has seen on iOS.
            ContentUnavailableView {
                Label(tr("No flight found", "لم يتم العثور على رحلة"), systemImage: "airplane.circle")
            } description: {
                Text(tr("Check the number and the date, or scan your boarding pass instead.",
                        "تحقق من الرقم والتاريخ، أو امسح بطاقة الصعود بدلاً من ذلك."))
            }
        }
    }

    private var alternatives: some View {
        VStack(spacing: 12) {
            Text(tr("or", "أو"))
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink3)

            // The POC entry point is a QR code on a poster in the terminal —
            // no app download. Design the row so a fourth method (PNR, Wallet
            // pass, airline account) can join it later.
            SecondaryButton(title: tr("Scan boarding pass", "امسح بطاقة الصعود"),
                            symbol: "qrcode.viewfinder",
                            action: confirm)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            // No icon: a magnifying glass next to "Find my flight" repeats the
            // verb in pictures and gives the eye a second thing to land on.
            PrimaryButton(title: tr("Find my flight", "ابحث عن رحلتي"),
                          isEnabled: !flightNumber.isEmpty,
                          action: findFlight)

            Text(tr("No account needed. You can sign in later if you book a service.",
                    "لا حاجة إلى حساب. يمكنك تسجيل الدخول لاحقاً إذا حجزت خدمة."))
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .responsiveContentWidth()
        .background(.bar)
    }

    // MARK: Behaviour

    private func validate() {
        let typed = flightNumber.trimmingCharacters(in: .whitespaces).uppercased()
        guard !typed.isEmpty else { lookup = .empty; return }
        lookup = .validating
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard typed == flightNumber.trimmingCharacters(in: .whitespaces).uppercased() else { return }
            lookup = typed == Flight.demo.number ? .found(.demo) : .notFound
        }
    }

    private func findFlight() {
        numberFieldFocused = false
        if case .found = lookup { confirm() } else { validate() }
    }

    private func confirm() {
        withAnimation(.smooth(duration: 0.3)) {
            store.hasJourney = true
        }
    }
}
