import SwiftUI

// MARK: - Ticket shape
//
// A rounded card with a semicircular notch punched out of the top and bottom
// edges at the perforation, so it reads as a torn boarding-pass stub rather
// than a rectangle with a line drawn on it.

struct TicketShape: Shape {
    /// Which way the tear runs — a stub torn off the side, or off the bottom.
    enum Tear { case vertical, horizontal }

    var tear: Tear = .vertical
    /// Where the perforation sits, 0…1 along the relevant axis.
    var perforation: CGFloat = 0.76
    var corner: CGFloat = 18
    var notch: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        tear == .vertical ? verticalPath(in: rect) : horizontalPath(in: rect)
    }

    /// Notches on the left and right edges; the tear runs across the card.
    private func horizontalPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let ny = h * perforation
        let r = min(corner, min(w, h) / 2)

        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // Right edge → notch → right edge
        p.addLine(to: CGPoint(x: w, y: ny - notch))
        p.addArc(center: CGPoint(x: w, y: ny), radius: notch,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addArc(center: CGPoint(x: w - r, y: h - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        p.addLine(to: CGPoint(x: r, y: h))
        p.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // Left edge → notch → left edge
        p.addLine(to: CGPoint(x: 0, y: ny + notch))
        p.addArc(center: CGPoint(x: 0, y: ny), radius: notch,
                 startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }

    private func verticalPath(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let nx = w * perforation
        let r = min(corner, min(w, h) / 2)

        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))

        // Top edge → notch → top edge
        p.addLine(to: CGPoint(x: nx - notch, y: 0))
        p.addArc(center: CGPoint(x: nx, y: 0), radius: notch,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addLine(to: CGPoint(x: w - r, y: 0))
        p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // Right edge
        p.addLine(to: CGPoint(x: w, y: h - r))
        p.addArc(center: CGPoint(x: w - r, y: h - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        // Bottom edge → notch → bottom edge
        p.addLine(to: CGPoint(x: nx + notch, y: h))
        p.addArc(center: CGPoint(x: nx, y: h), radius: notch,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: r, y: h))
        p.addArc(center: CGPoint(x: r, y: h - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // Left edge
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Scan boarding pass
//
// §7 of the brief names "Scan boarding pass" as the entry method that should
// eventually replace typing a flight number. Giving it the form of an actual
// boarding pass makes what it wants obvious without a line of instruction.
//
// Every tint derives from `tenant.palette.primary`, so this re-themes with the
// deployment like everything else — it is not a pinned-blue illustration.

struct BoardingPassScanCard: View {
    @Environment(\.tenant) private var tenant
    let action: () -> Void

    private let perforation: CGFloat = 0.76
    private var blue: Color { tenant.palette.primary }

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let splitX = w * perforation

                ZStack(alignment: .topLeading) {
                    // Stub tint, clipped to the ticket so it stops at the notch.
                    HStack(spacing: 0) {
                        blue.opacity(0.045)
                            .frame(width: splitX)
                        blue.opacity(0.10)
                    }

                    decoration(width: splitX, height: h)

                    // Perforation
                    Path { p in
                        p.move(to: CGPoint(x: splitX, y: 11))
                        p.addLine(to: CGPoint(x: splitX, y: h - 11))
                    }
                    .stroke(blue.opacity(0.30),
                            style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))

                    // Main section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan boarding pass")
                            .font(Type.system(16, .bold))
                            .foregroundStyle(blue)
                        Text("Add your flight in a snap")
                            .font(Type.font(12))
                            .foregroundStyle(tenant.palette.inkMuted)
                    }
                    .padding(.leading, 15)
                    .frame(width: splitX, height: h, alignment: .leading)

                    // Stub
                    VStack(spacing: 3) {
                        ZStack {
                            ScanBrackets()
                                .stroke(blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 26, height: 26)
                            Image(systemName: "barcode")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(blue)
                        }
                        Text("SCAN")
                            .font(Type.font(8, .bold))
                            .tracking(1.1)
                            .foregroundStyle(blue)
                    }
                    .frame(width: w - splitX, height: h)
                    .offset(x: splitX)
                }
                .clipShape(TicketShape(perforation: perforation, corner: 13, notch: 9))
                .overlay(
                    TicketShape(perforation: perforation, corner: 15, notch: 11)
                        .stroke(blue.opacity(0.28), lineWidth: 1.3)
                )
            }
            .frame(height: 76)
        }
        .buttonStyle(.plain)
    }

    // MARK: Background illustration — flight arc, plane, clouds

    private func decoration(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: width * 0.52, y: height * 0.84))
                p.addQuadCurve(to: CGPoint(x: width * 0.86, y: height * 0.22),
                               control: CGPoint(x: width * 0.60, y: height * 0.28))
            }
            .stroke(blue.opacity(0.20),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 5]))

            Image(systemName: "airplane")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(blue.opacity(0.22))
                .rotationEffect(.degrees(-32))
                .position(x: width * 0.845, y: height * 0.21)

            Image(systemName: "cloud.fill")
                .font(.system(size: 20))
                .foregroundStyle(blue.opacity(0.10))
                .position(x: width * 0.93, y: height * 0.40)

            Image(systemName: "cloud.fill")
                .font(.system(size: 16))
                .foregroundStyle(blue.opacity(0.10))
                .position(x: width * 0.73, y: height * 0.80)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

/// Four corner brackets — the viewfinder mark around the barcode.
private struct ScanBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let arm = min(w, h) * 0.32
        var p = Path()
        // top-left
        p.move(to: CGPoint(x: 0, y: arm)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: arm, y: 0))
        // top-right
        p.move(to: CGPoint(x: w - arm, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: arm))
        // bottom-right
        p.move(to: CGPoint(x: w, y: h - arm)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - arm, y: h))
        // bottom-left
        p.move(to: CGPoint(x: arm, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - arm))
        return p
    }
}
