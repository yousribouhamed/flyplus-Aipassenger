import SwiftUI

// MARK: - Indoor floor plan
//
// Modelled on how real indoor maps are drawn — Woolworths' store map, Walmart's
// department plan, Fly Delta's terminal view: a building envelope, tenancies as
// labelled rectangles, corridors as walkable bands, and a route that turns at
// right angles because corridors do. A node-and-line graph reads as a diagram;
// this reads as a place.
//
// Provider-agnostic: it renders whatever `AirportMap` + `Route` it is handed, so
// swapping the POC graph for a production indoor provider changes nothing here.

struct AirportMapView: View {
    @Environment(\.tenant) private var tenant

    let map: AirportMap
    let route: Route?
    let currentNodeID: String
    /// Which level to draw. Security is never crossed, so only one is ever shown.
    var zone: Zone = .airside
    /// Progress along the current leg, 0…1 — used to animate the walking dot.
    var legProgress: Double = 0
    var showsAllPOIs: Bool = true
    /// Label the dot when browsing rather than following a route — on a plan of a
    /// whole terminal, an unlabelled dot is just a dot.
    var showsYouAreHere: Bool = false
    var onSelect: ((POI) -> Void)?

    private var routeIDs: Set<String> { Set(route?.nodes.map(\.id) ?? []) }

    // MARK: Projection

    /// Fit the building, not the nominal design square.
    private var bounds: CGRect {
        let plate = map.plate(for: zone)
        let pts = plate.outline.isEmpty ? map.nodes(in: zone).map(\.point) : plate.outline
        let xs = pts.map(\.x), ys = pts.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let pad: CGFloat = 26
        return CGRect(x: minX - pad, y: minY - pad,
                      width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2)
    }

    private func scale(in size: CGSize) -> CGFloat {
        min(size.width / bounds.width, size.height / bounds.height)
    }

    private func project(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let b = bounds, s = scale(in: size)
        return CGPoint(x: (p.x - b.minX) * s + (size.width - b.width * s) / 2,
                       y: (p.y - b.minY) * s + (size.height - b.height * s) / 2)
    }

    private func project(_ r: CGRect, in size: CGSize) -> CGRect {
        let o = project(CGPoint(x: r.minX, y: r.minY), in: size)
        let s = scale(in: size)
        return CGRect(x: o.x, y: o.y, width: r.width * s, height: r.height * s)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                plate(size)
                corridors(size)
                units(size)
                if let route { routeLine(route, size) }
                labels(size)
                endpoints(size)
                walker(size)
            }
            .frame(width: size.width, height: size.height)
        }
        .background(tenant.palette.canvasTop)
    }

    // MARK: Building

    /// The floor itself — a filled polygon with a hairline wall.
    private func plate(_ size: CGSize) -> some View {
        let path = Path { p in
            let outline = map.plate(for: zone).outline
            guard let first = outline.first else { return }
            p.move(to: project(first, in: size))
            outline.dropFirst().forEach { p.addLine(to: project($0, in: size)) }
            p.closeSubpath()
        }
        return ZStack {
            path.fill(tenant.palette.surface)
            path.stroke(tenant.palette.inkMuted.opacity(0.30), lineWidth: 1.4)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }

    /// Walkable bands. Slightly darker than the tenancies so circulation reads.
    private func corridors(_ size: CGSize) -> some View {
        let w = max(10, 34 * scale(in: size))
        return Path { p in
            for line in map.plate(for: zone).corridors {
                guard let first = line.first else { continue }
                p.move(to: project(first, in: size))
                line.dropFirst().forEach { p.addLine(to: project($0, in: size)) }
            }
        }
        .stroke(tenant.palette.canvasTop.opacity(0.9),
                style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    /// Tenancies and gates as rooms on the plan.
    @ViewBuilder
    private func units(_ size: CGSize) -> some View {
        ForEach(map.nodes(in: zone)) { node in
            if let rect = node.footprint {
                let r = project(rect, in: size)
                let onRoute = routeIDs.contains(node.id)
                let isGate = map.poi(node.id)?.category == .gate
                let isDestination = route?.destination?.id == node.id
                let isStop = route?.stopNodeID == node.id

                RoundedRectangle(cornerRadius: max(3, 7 * scale(in: size)), style: .continuous)
                    .fill(fill(isDestination: isDestination, isStop: isStop, onRoute: onRoute, isGate: isGate))
                    .overlay(
                        RoundedRectangle(cornerRadius: max(3, 7 * scale(in: size)), style: .continuous)
                            .stroke(stroke(isDestination: isDestination, isStop: isStop, onRoute: onRoute),
                                    lineWidth: (isDestination || isStop) ? 2 : 1)
                    )
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
                    .onTapGesture { if let poi = map.poi(node.id) { onSelect?(poi) } }
            }
        }
    }

    private func fill(isDestination: Bool, isStop: Bool, onRoute: Bool, isGate: Bool) -> Color {
        if isDestination { return tenant.palette.primary }
        if isStop { return tenant.palette.success }
        if onRoute { return tenant.palette.primarySoft }
        return isGate ? tenant.palette.primarySoft.opacity(0.55) : tenant.palette.canvasTop.opacity(0.75)
    }

    private func stroke(isDestination: Bool, isStop: Bool, onRoute: Bool) -> Color {
        if isDestination { return tenant.palette.primary }
        if isStop { return tenant.palette.success }
        if onRoute { return tenant.palette.primary.opacity(0.45) }
        return tenant.palette.hairline
    }

    // MARK: Route

    private func routeLine(_ route: Route, _ size: CGSize) -> some View {
        let pts = route.nodes.map { project($0.point, in: size) }
        let w = max(4, 13 * scale(in: size))
        return ZStack {
            Path { p in
                guard let f = pts.first else { return }
                p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
            }
            .stroke(tenant.palette.surface,
                    style: StrokeStyle(lineWidth: w * 1.55, lineCap: .round, lineJoin: .round))

            Path { p in
                guard let f = pts.first else { return }
                p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
            }
            .stroke(tenant.palette.primary,
                    style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Labels

    @ViewBuilder
    private func labels(_ size: CGSize) -> some View {
        let s = scale(in: size)
        ForEach(map.nodes(in: zone)) { node in
            if let rect = node.footprint, s > 0.18 {
                let r = project(rect, in: size)
                let onRoute = routeIDs.contains(node.id)
                let isFilled = route?.destination?.id == node.id || route?.stopNodeID == node.id
                if showsAllPOIs || onRoute {
                    VStack(spacing: 1) {
                        if let poi = map.poi(node.id) {
                            Image(systemName: poi.category.symbol)
                                .font(.system(size: max(7, 12 * s), weight: .semibold))
                        }
                        Text(node.name)
                            .font(Type.font(max(6, 10 * s), .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isFilled ? tenant.palette.onPrimary : tenant.palette.inkMuted)
                    .frame(width: r.width - 6)
                    .position(x: r.midX, y: r.midY)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: Endpoints

    @ViewBuilder
    private func endpoints(_ size: CGSize) -> some View {
        if let dest = route?.destination {
            pin(at: project(dest.point, in: size), tint: tenant.palette.primary, symbol: "flag.fill")
        }
        if let stopID = route?.stopNodeID, let stop = map.node(stopID) {
            pin(at: project(stop.point, in: size), tint: tenant.palette.success, symbol: "mappin")
        }
    }

    private func pin(at p: CGPoint, tint: Color, symbol: String) -> some View {
        ZStack {
            Circle().fill(tint)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        .position(x: p.x, y: p.y - 16)
    }

    // MARK: Passenger position

    private func walker(_ size: CGSize) -> some View {
        let p = project(walkerPoint(), in: size)
        return VStack(spacing: 4) {
            ZStack {
                Circle().fill(tenant.palette.primary.opacity(0.18)).frame(width: 38, height: 38)
                Circle().fill(tenant.palette.primary).frame(width: 17, height: 17)
                Circle().stroke(.white, lineWidth: 3.5).frame(width: 17, height: 17)
            }
            if showsYouAreHere {
                Text("You are here")
                    .font(Type.font(11, .semibold))
                    .foregroundStyle(tenant.palette.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tenant.palette.primary, in: Capsule())
                    .fixedSize()
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
        }
        .position(x: p.x, y: p.y + (showsYouAreHere ? 12 : 0))
    }

    private func walkerPoint() -> CGPoint {
        guard let here = map.node(currentNodeID) else { return .zero }
        guard legProgress > 0, let route,
              let idx = route.nodes.firstIndex(where: { $0.id == currentNodeID }),
              idx + 1 < route.nodes.count
        else { return here.point }
        let next = route.nodes[idx + 1].point
        return CGPoint(x: here.point.x + (next.x - here.point.x) * legProgress,
                       y: here.point.y + (next.y - here.point.y) * legProgress)
    }
}
