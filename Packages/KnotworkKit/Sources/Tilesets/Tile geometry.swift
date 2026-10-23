import Core
import CoreGraphics

// Geometry every tileset shares, in a unit tile: (0, 0) at the top left, y
// running down, as in SwiftUI.
//
// A strand leaves a tile only in one of two ways: diagonally through a
// corner, or square through the middle of an edge. So tiles meet whatever
// their neighbours are, and every bend is one of two shapes:
//
// * An eighth turn, from a diagonal to square, is a single arc that ends
//   exactly at the middle of the edge. Its mirror image in the tile beyond
//   continues it, so the two make one unbroken curve, with no straight run
//   between them.
// * A quarter turn, at a corner of the knot, starts and ends as sharply
//   curved as that arc, so that it carries on from its neighbours without a
//   change in curvature, and tightens to a point in the middle. With
//   pointed corners, its outer edge comes to a sharper point still.
//
// Where a strand passes over another at a corner, its band spills into the
// corners of the two tiles beside it. Those tiles know nothing of it; the
// tile the strand belongs to draws the spill itself, after every tile has
// been drawn (`spill(at:)`), so the band is the same shape on both sides of
// the edge however it bends.

enum TileGeometry {
    /// Half the width of a strand's band, about that of the original images.
    static let halfWidth: CGFloat = 0.3

    /// How far beyond its tile a strand's centre line is drawn, so that a
    /// stroke clipped to the tile has no end caps showing.
    static let overrun: CGFloat = 0.6

    /// How sharp that point is: the higher, the more of the turn is packed
    /// into the middle of the bend.
    static let cornerSharpness: CGFloat = 48

    /// The two edges of `tile`'s band, each run on past both ends like its
    /// centre line and running the same way: first the edge on the side the
    /// centre line's normals point to (`Polyline.normal(at:)`), then the
    /// other. None for the empty tile.
    ///
    /// With `pointedCorners`, the outer edge of a knot's corner comes to a
    /// sharper point than an even band allows, as in the original images:
    /// the inner edge stays where it is, and the band widens towards the
    /// point.
    ///
    /// Worked out once for every tile, not on every redraw.
    static func edges(of tile: Tile, pointedCorners: Bool) -> [Polyline] {
        (pointedCorners ? pointedEdges : evenEdges)[tile] ?? []
    }

    private static let pointedEdges = allEdges(pointedCorners: true)
    private static let evenEdges = allEdges(pointedCorners: false)

    private static func allEdges(pointedCorners: Bool) -> [Tile: [Polyline]] {
        Dictionary(
            uniqueKeysWithValues: Tile.allCases.compactMap { tile in
                tile.strand.map { (tile, edges(of: $0, pointedCorners: pointedCorners)) }
            })
    }

    private static func edges(of strand: Strand, pointedCorners: Bool) -> [Polyline] {
        let line = Polyline(centreline(of: strand), spacing: 0.01)
        var edges = [halfWidth, -halfWidth].map { offset in
            Polyline(points: line.offset { _ in offset })
        }
        let a = strand.start
        let b = strand.end
        if pointedCorners, !a.isCorner, !b.isCorner, abs(a.inward.dot(b.inward)) < 1e-6 {
            // The outside of the turn is the side the strand comes from
            // when it leaves.
            edges[line.normal(at: 0).dot(b.inward) > 0 ? 0 : 1] = outerEdge(from: a, to: b)
        }
        return edges
    }

    /// The area between a band's two edges.
    static func region(between edges: [Polyline]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: edges[0].points + edges[1].points.reversed())
        path.closeSubpath()
        return path
    }

    /// The outer edge of a quarter turn from `a` to `b`, with its own, sharper
    /// bend, which meets the edges of the bands either side as they are.
    private static func outerEdge(from a: Port, to b: Port) -> Polyline {
        let start = a.point + b.inward * halfWidth
        let path = CGMutablePath()
        path.move(to: start - a.inward * overrun)
        for local in QuarterTurn.outerEdge {
            path.addLine(to: start + a.inward * local.x - b.inward * local.y)
        }
        let end = b.point + a.inward * halfWidth
        path.addLine(to: end - b.inward * overrun)
        return Polyline(path, spacing: 0.01)
    }

    /// A strand's centre line, run on past both ends by `overrun`.
    static func centreline(of strand: Strand) -> CGPath {
        let a = strand.start
        let b = strand.end
        let path = CGMutablePath()
        path.move(to: a.point - a.inward * overrun)
        // No segment may have zero length: stroked, it gets an end cap
        // across the band.
        if let bend = intersection(a.point, a.inward, b.point, b.inward) {
            if a.isCorner || b.isCorner {
                // The arc touches both lines as far from the bend as the
                // middle of the edge is; `addArc` draws the straight run up
                // to it, if there is one.
                let reach = min((bend - a.point).length, (bend - b.point).length)
                path.addArc(tangent1End: bend, tangent2End: b.point, radius: reach / tan(.pi / 8))
            } else {
                path.addLine(to: a.point)
                for local in QuarterTurn.centreline.dropFirst() {
                    path.addLine(to: a.point + a.inward * local.x - b.inward * local.y)
                }
            }
        }
        if (path.currentPoint - b.point).length > 1e-6 { path.addLine(to: b.point) }
        path.addLine(to: b.point - b.inward * overrun)
        return path
    }

    /// The straight band of a strand crossing over this tile's strand at
    /// `corner`, square to this tile's diagonal: where this tile's strand
    /// stops short, to leave a gap.
    static func overStrand(at corner: Corner) -> CGPath {
        let across = corner.inward.perpendicular
        let path = CGMutablePath()
        path.move(to: corner.point - across * 2)
        path.addLine(to: corner.point + across * 2)
        return path
    }

    /// The corners at which a strand passes under another.
    static func underCorners(of strand: Strand) -> [Corner] {
        [strand.start, strand.end].compactMap { port in
            if case .corner(let corner, isOver: false) = port { corner } else { nil }
        }
    }

    /// The corners at which a strand passes over another.
    static func overCorners(of strand: Strand) -> [Corner] {
        [strand.start, strand.end].compactMap { port in
            if case .corner(let corner, isOver: true) = port { corner } else { nil }
        }
    }

    /// Clips `context` to where a tile's band spills over `corner` into the
    /// two tiles beside it: outside the tile, and on this side of the corner
    /// (the band beyond it is the next tile's). Each edge is pushed out by
    /// `overlap`, so that the spill overlaps what it meets.
    ///
    /// Three clips, which intersect, rather than one path: a path that is
    /// the union of the pieces leaves hairlines along their edges.
    static func clip(_ context: CGContext, toSpillAt corner: Corner, overlap: CGFloat) {
        let reach: CGFloat = 0.6
        let c = corner.point
        context.clip(
            to: CGRect(x: c.x - reach, y: c.y - reach, width: 2 * reach, height: 2 * reach))
        // This side of the line across the corner.
        let back = c - corner.inward * overlap
        let across = corner.inward.perpendicular * 2
        let side = CGMutablePath()
        side.addLines(between: [
            back - across, back + across, back + across + corner.inward * 2,
            back - across + corner.inward * 2,
        ])
        side.closeSubpath()
        context.addPath(side)
        context.clip()
        // Outside the tile.
        context.addRect(CGRect(x: -2, y: -2, width: 5, height: 5))
        context.addRect(CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: overlap, dy: overlap))
        context.clip(using: .evenOdd)
    }

    /// Where the lines from `p` along `d` and from `q` along `e` meet, if
    /// they are not parallel.
    private static func intersection(
        _ p: CGPoint, _ d: CGVector, _ q: CGPoint, _ e: CGVector
    ) -> CGPoint? {
        let determinant = e.dx * d.dy - d.dx * e.dy
        guard abs(determinant) > 1e-9 else { return nil }
        let r = q - p
        let t = (e.dx * r.dy - r.dx * e.dy) / determinant
        return p + d * t
    }
}

/// The bend at a corner of the knot, from the middle of one edge to the
/// middle of the next: of its centre line, and of its outer edge.
///
/// Given by its curvature along its length, which at both ends is that of
/// the eighth-turn arc (at the same distance from the centre line), so that
/// it carries on from its neighbours without a change. In between, the
/// curvature of the ends can fade away (over `taper` of the length at each
/// end), straightening the flanks, and a bump in the middle (sinᵖ, sharper the
/// higher p) turns as much as is left of the quarter turn. Its length is
/// whatever brings it out where it should, found by bisection.
private enum QuarterTurn {
    /// The radius of the eighth-turn arc's centre line, which ends half a
    /// tile from its bend.
    private static let arcRadius = 0.5 / tan(CGFloat.pi / 8)

    /// The centre line, from the origin heading along x to (0.5, 0.5)
    /// heading along y: x is along the way in, y along the way out.
    static let centreline = solve(reach: 0.5, endCurvature: 1 / arcRadius, sharpness: 2, taper: 0)

    /// The outer edge, from the origin to (0.5 + w, 0.5 + w), w being the
    /// band's half width, in the same frame moved out by w. Straight flanks
    /// and a sharp point, as in the original images.
    static let outerEdge = solve(
        reach: 0.5 + TileGeometry.halfWidth, endCurvature: 1 / (arcRadius + TileGeometry.halfWidth),
        sharpness: TileGeometry.cornerSharpness, taper: 0.1)

    private static func solve(
        reach: CGFloat, endCurvature: CGFloat, sharpness: CGFloat, taper: CGFloat
    ) -> [CGPoint] {
        let bend = { (length: CGFloat) in
            trace(length: length, endCurvature: endCurvature, sharpness: sharpness, taper: taper)
        }
        var low = reach
        var high = 4 * reach
        for _ in 0..<50 {
            let length = (low + high) / 2
            if bend(length).last!.x > reach { high = length } else { low = length }
        }
        return bend((low + high) / 2)
    }

    private static func trace(
        length: CGFloat, endCurvature: CGFloat, sharpness: CGFloat, taper: CGFloat, steps: Int = 240
    ) -> [CGPoint] {
        let u = (0..<steps).map { (CGFloat($0) + 0.5) / CGFloat(steps) }
        let ends = u.map { u -> CGFloat in
            guard taper > 0 else { return 1 }
            let t = max(0, 1 - min(u, 1 - u) / taper)
            return t * t * (3 - 2 * t)
        }
        let bump = u.map { pow(sin(.pi * $0), sharpness) }
        let mean = { (values: [CGFloat]) in values.reduce(0, +) / CGFloat(steps) }
        let peak = (.pi / 2 - endCurvature * length * mean(ends)) / (length * mean(bump))
        let ds = length / CGFloat(steps)
        var point = CGPoint.zero
        var heading: CGFloat = 0
        var points = [point]
        for step in 0..<steps {
            let curvature = endCurvature * ends[step] + peak * bump[step]
            let middle = heading + curvature * ds / 2
            point = point + CGVector(dx: cos(middle), dy: sin(middle)) * ds
            heading += curvature * ds
            points.append(point)
        }
        return points
    }
}

extension Corner {
    var point: CGPoint {
        switch self {
        case .nw: CGPoint(x: 0, y: 0)
        case .ne: CGPoint(x: 1, y: 0)
        case .sw: CGPoint(x: 0, y: 1)
        case .se: CGPoint(x: 1, y: 1)
        }
    }

    /// The unit vector from this corner across the tile.
    var inward: CGVector {
        let r = 0.5 * 2.0.squareRoot()
        return switch self {
        case .nw: CGVector(dx: r, dy: r)
        case .ne: CGVector(dx: -r, dy: r)
        case .sw: CGVector(dx: r, dy: -r)
        case .se: CGVector(dx: -r, dy: -r)
        }
    }
}

extension Edge {
    var midpoint: CGPoint {
        switch self {
        case .n: CGPoint(x: 0.5, y: 0)
        case .s: CGPoint(x: 0.5, y: 1)
        case .w: CGPoint(x: 0, y: 0.5)
        case .e: CGPoint(x: 1, y: 0.5)
        }
    }

    var inward: CGVector {
        switch self {
        case .n: CGVector(dx: 0, dy: 1)
        case .s: CGVector(dx: 0, dy: -1)
        case .w: CGVector(dx: 1, dy: 0)
        case .e: CGVector(dx: -1, dy: 0)
        }
    }
}

extension Port {
    var point: CGPoint {
        switch self {
        case .corner(let corner, _): corner.point
        case .middle(let edge): edge.midpoint
        }
    }

    /// The unit vector along which the strand enters the tile here.
    var inward: CGVector {
        switch self {
        case .corner(let corner, _): corner.inward
        case .middle(let edge): edge.inward
        }
    }

    var isCorner: Bool { if case .corner = self { true } else { false } }
}

// MARK: - Vector arithmetic

extension CGVector {
    static func * (v: CGVector, k: CGFloat) -> CGVector { CGVector(dx: v.dx * k, dy: v.dy * k) }
    static func + (a: CGVector, b: CGVector) -> CGVector {
        CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy)
    }
    func dot(_ other: CGVector) -> CGFloat { dx * other.dx + dy * other.dy }
    var length: CGFloat { (dx * dx + dy * dy).squareRoot() }
    var normalized: CGVector { length > 0 ? self * (1 / length) : self }
    /// Turned a quarter turn: clockwise on screen, with y running down.
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }
}

extension CGPoint {
    static func + (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }
    static func - (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x - v.dx, y: p.y - v.dy) }
    static func - (p: CGPoint, q: CGPoint) -> CGVector { CGVector(dx: p.x - q.x, dy: p.y - q.y) }
}
