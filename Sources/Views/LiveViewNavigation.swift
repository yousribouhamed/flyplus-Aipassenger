import AVFoundation
import SwiftUI

// MARK: - Live View (AR walking navigation)
//
// Built to the Google Maps Indoor Live View pattern, which is the established
// idiom for this and the one passengers will recognise:
//
//   · camera feed as the backdrop
//   · a floating instruction banner in brand colour, set in AR space
//   · large stacked chevrons cascading in the direction of travel
//   · a light top bar naming the building, not the app
//   · a bottom card: the current step with its distance, then the destination
//
// Scope honesty: the brief puts true AR navigation in "Later / integration
// dependent" (§22) because it needs real indoor positioning. What is real here
// is the camera and the interaction design; the heading comes from the route
// geometry rather than from a positioning provider. That is the same division
// the rest of the POC makes — the experience layer is final, the provider is not.

struct LiveViewNavigation: View {
    @Environment(\.tenant) private var tenant
    @Environment(JourneyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let instruction: TurnInstruction?
    let route: Route?

    @State private var cascade: Double = 0

    private var destination: String { route?.destination?.name ?? store.destinationName }

    var body: some View {
        ZStack {
            CameraBackdrop()
                .ignoresSafeArea()

            // Keeps white type legible whatever the terminal looks like.
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.08), .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                banner
                chevrons
                Spacer()
                bottomCard
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { cascade = 1 }
        }
    }

    // MARK: Top bar — names the building, per the reference

    private var topBar: some View {
        HStack {
            circleButton("chevron.left") { dismiss() }
            Spacer()
            VStack(spacing: 1) {
                Text(store.map.terminalLabel(for: store.context.zone).components(separatedBy: " · ").first ?? "Terminal")
                    .font(Type.font(17, .semibold))
                    .foregroundStyle(.white)
                Text(store.map.name)
                    .font(Type.font(12))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            circleButton("map") { dismiss() }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 6)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.black.opacity(0.42), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Floating instruction

    private var banner: some View {
        Text(instruction?.text ?? "Continue ahead")
            .font(Type.font(24, .bold))
            .foregroundStyle(tenant.palette.onPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(tenant.palette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .rotation3DEffect(.degrees(9), axis: (x: 1, y: 0, z: 0))   // sits in the scene
            .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 26)
    }

    // MARK: Cascading chevrons

    private var chevrons: some View {
        VStack(spacing: -14) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 96, weight: .heavy))
                    .foregroundStyle(tenant.palette.onPrimary)
                    .shadow(color: tenant.palette.primary.opacity(0.9), radius: 3)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                    .opacity(opacity(for: i))
            }
        }
        .rotationEffect(.degrees(rotation))
        .rotation3DEffect(.degrees(52), axis: (x: 1, y: 0, z: 0))      // lies on the floor
        .padding(.bottom, 30)
    }

    /// Each chevron brightens in turn, so the group reads as movement forward.
    private func opacity(for index: Int) -> Double {
        let phase = (cascade * 3).truncatingRemainder(dividingBy: 3)
        let distance = abs(phase - Double(index))
        return 0.42 + 0.58 * max(0, 1 - distance)
    }

    /// Point the arrows the way the next instruction turns.
    private var rotation: Double {
        switch instruction?.symbol {
        case "arrow.turn.up.left": -42
        case "arrow.turn.up.right": 42
        default: 0
        }
    }

    // MARK: Bottom card — step, then destination

    private var bottomCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: instruction?.symbol ?? "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tenant.palette.ink)
                Text(instruction?.text ?? "Continue ahead")
                    .font(Type.font(15, .medium))
                    .foregroundStyle(tenant.palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(distanceText)
                    .font(Type.mono(15, .semibold))
                    .foregroundStyle(tenant.palette.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Hairline()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination)
                        .font(Type.font(20, .semibold))
                        .foregroundStyle(tenant.palette.ink)
                    Text(store.hasDeadline
                         ? "\(store.map.terminalLabel(for: store.context.zone)) · \(store.deadlineLabel) \(store.deadlineClock ?? "")"
                         : store.map.terminalLabel(for: store.context.zone))
                        .font(Type.font(13))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(route?.minutes ?? store.walkMinutesToGate) min")
                        .font(Type.mono(20, .semibold))
                        .foregroundStyle(tenant.palette.primary)
                    Text(TimingEngine.durationPhrase(store.minutesToDeadline) + " left")
                        .font(Type.font(12))
                        .foregroundStyle(tenant.palette.inkMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, 18)
        }
        .background(tenant.palette.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous))
        .ignoresSafeArea(edges: .bottom)
    }

    private var distanceText: String {
        guard let m = instruction.map({ inst -> Double in
            guard let route else { return 0 }
            var travelled: Double = 0
            for leg in route.legs {
                if travelled >= inst.atMetres { return leg.metres }
                travelled += leg.metres
            }
            return route.legs.last?.metres ?? 0
        }), m > 0 else { return "—" }
        return "\(Int(m)) m"
    }
}

// MARK: - Camera backdrop
//
// A real capture session. On a device without a camera (the simulator) the
// session simply never starts, and the placeholder below says so rather than
// dressing up a stock photo as a live feed.

struct CameraBackdrop: View {
    @State private var authorised = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        ZStack {
            if hasCamera && authorised {
                CameraPreview()
            } else {
                unavailable
            }
        }
        .task {
            guard hasCamera, !authorised else { return }
            authorised = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    private var unavailable: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A3340), Color(hex: 0x10161F)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 26, weight: .light))
                Text(hasCamera ? "Camera access needed for Live View"
                               : "Live View needs a device camera")
                    .font(Type.font(14, .medium))
                Text("The guidance layer above is unchanged")
                    .font(Type.font(12))
                    .opacity(0.7)
            }
            .foregroundStyle(.white.opacity(0.8))
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.start()
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        /// AVCaptureSession is not Sendable, and start/stop must stay off the main
        /// thread — so it is confined to one private queue instead.
        nonisolated(unsafe) private let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "passenger.camera.session")

        func start() {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            session.addInput(input)
            session.commitConfiguration()
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
            queue.async { [session] in session.startRunning() }
        }

        /// Released when the view leaves the hierarchy rather than in deinit,
        /// which cannot touch non-Sendable state under Swift 6.
        override func willMove(toWindow newWindow: UIWindow?) {
            super.willMove(toWindow: newWindow)
            if newWindow == nil { queue.async { [session] in session.stopRunning() } }
        }
    }
}
