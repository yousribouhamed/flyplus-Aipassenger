import SwiftUI

/// The static floor map the POC routes against.
///
/// True turn-by-turn indoor navigation is production-dependent: it needs
/// indoor positioning, a routable network and airport data that do not exist
/// yet. So the POC uses a known start point, a static floor plan, curated POIs
/// and a drawn route — while the interface stays the production one, because
/// the UX should not change when a real provider is swapped in.
///
/// Drawn with `Canvas`, the platform's own immediate-mode drawing surface,
/// rather than a stack of shapes: one pass, no view explosion, and it scales
/// to whatever the container gives it.
struct AirportMapView: View {
    let plan: RoutePlan
    var confidence: PositionConfidence = .good
    /// 0...1 along the route; drives the walking dot in turn-by-turn.
    var progress: Double = 0

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .background(Theme.surface2)
        .overlay(alignment: .top) {
            if confidence == .uncertain, let message = confidence.message {
                // Honesty beats a confident blue dot in the wrong concourse:
                // a map that shows visitors in the wrong place erodes trust
                // immediately, and often permanently.
                Label(message, systemImage: "location.slash")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.timeSensitive)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(12)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Floor plan of Concourse \(plan.floor), route to \(plan.destination)")
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        drawGrid(&context, size)
        drawRooms(&context, size)

        let points = routePoints(in: size)
        var path = Path()
        path.addLines(points)
        context.stroke(
            path,
            with: .color(Theme.brand),
            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        )

        if let start = points.first {
            drawPositionDot(&context, at: start)
        }
        if plan.hasStop, points.count > 2 {
            drawPin(&context, at: points[points.count / 2], color: Theme.timeSensitive)
        }
        if let end = points.last {
            drawPin(&context, at: end, color: Theme.ink)
        }
        if progress > 0, let walker = point(along: points, at: progress) {
            drawPositionDot(&context, at: walker)
        }
    }

    private func drawGrid(_ context: inout GraphicsContext, _ size: CGSize) {
        var grid = Path()
        let step: CGFloat = 26
        stride(from: 0, through: size.width, by: step).forEach {
            grid.move(to: CGPoint(x: $0, y: 0)); grid.addLine(to: CGPoint(x: $0, y: size.height))
        }
        stride(from: 0, through: size.height, by: step).forEach {
            grid.move(to: CGPoint(x: 0, y: $0)); grid.addLine(to: CGPoint(x: size.width, y: $0))
        }
        context.stroke(grid, with: .color(Theme.hairline.opacity(0.7)), lineWidth: 1)
    }

    private func drawRooms(_ context: inout GraphicsContext, _ size: CGSize) {
        // Gate piers and retail blocks, enough to make the route legible as a
        // building rather than a line on graph paper.
        let blocks: [CGRect] = [
            CGRect(x: 0.06, y: 0.10, width: 0.22, height: 0.16),
            CGRect(x: 0.36, y: 0.08, width: 0.28, height: 0.12),
            CGRect(x: 0.72, y: 0.14, width: 0.20, height: 0.22),
            CGRect(x: 0.10, y: 0.58, width: 0.26, height: 0.18),
            CGRect(x: 0.46, y: 0.62, width: 0.18, height: 0.14),
            CGRect(x: 0.70, y: 0.60, width: 0.22, height: 0.26)
        ]
        for block in blocks {
            let rect = CGRect(
                x: block.minX * size.width,
                y: block.minY * size.height,
                width: block.width * size.width,
                height: block.height * size.height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 6),
                with: .color(Theme.hairline)
            )
        }
    }

    private func routePoints(in size: CGSize) -> [CGPoint] {
        let normalised: [CGPoint] = plan.hasStop
            ? [CGPoint(x: 0.16, y: 0.86), CGPoint(x: 0.16, y: 0.46),
               CGPoint(x: 0.42, y: 0.46), CGPoint(x: 0.42, y: 0.30),
               CGPoint(x: 0.82, y: 0.30), CGPoint(x: 0.82, y: 0.46)]
            : [CGPoint(x: 0.16, y: 0.86), CGPoint(x: 0.16, y: 0.42),
               CGPoint(x: 0.52, y: 0.42), CGPoint(x: 0.52, y: 0.30),
               CGPoint(x: 0.84, y: 0.30)]
        return normalised.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    private func point(along points: [CGPoint], at fraction: Double) -> CGPoint? {
        guard points.count > 1 else { return points.first }
        let clamped = min(max(fraction, 0), 1)
        let scaled = clamped * Double(points.count - 1)
        let index = min(Int(scaled), points.count - 2)
        let t = scaled - Double(index)
        let a = points[index], b = points[index + 1]
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func drawPositionDot(_ context: inout GraphicsContext, at point: CGPoint) {
        let halo = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
        context.fill(Path(ellipseIn: halo), with: .color(Theme.brand.opacity(0.22)))
        let dot = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: dot.insetBy(dx: -2.5, dy: -2.5)), with: .color(.white))
        context.fill(Path(ellipseIn: dot), with: .color(Theme.brand))
    }

    private func drawPin(_ context: inout GraphicsContext, at point: CGPoint, color: Color) {
        let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        context.fill(Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)), with: .color(.white))
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

/// Floor switcher, as a vertical stack on the trailing edge — within thumb
/// reach but out of the route. Grab ships exactly this shape (3MF / 3F / 2F /
/// 1F / GF) on its indoor maps.
struct FloorSwitcher: View {
    let floors: [String]
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 4) {
            ForEach(floors, id: \.self) { floor in
                Button {
                    selection = floor
                } label: {
                    Text(floor)
                        .font(Theme.font(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 9))
                .tint(selection == floor ? Theme.brand : Theme.ink3)
                .accessibilityLabel("Level \(floor)")
                .accessibilityAddTraits(selection == floor ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
