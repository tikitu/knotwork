import Core
import CoreGraphics

/// Pencil lines over a watercolour wash, on paper: each edge of a band drawn
/// twice, a little apart and a little unsteady, the wash not quite inside the
/// lines, and hatching where a strand goes under another.
///
/// Everything that wanders is pinned where it leaves the tile, so that tiles
/// drawn differently still meet: a line's wobble and changing weight fade out
/// towards each port, and what is offset is offset by the same amount on
/// every tile. A tile's band is drawn twice, in the tile and where it spills
/// into its neighbours, from the same seed, so both come out the same.
enum SketchTiles {
    static let paper = CGColor.hex(0xF3ECDD)
    // Opaque, though they look like ink and watercolour over the paper:
    // tiles overlap their neighbours by a hair (`CGContext.overlap`), and
    // anything translucent would show darker there.
    static let ink = CGColor.hex(0x3A342E)
    static let wash = CGColor.hex(0xE3CDAC)
    /// How far short of the band above a strand stops where it passes
    /// under another. Less than nothing: it runs a little way under the
    /// band above, which is drawn over it, so no paper shows between them.
    static let gap: CGFloat = -0.01
    static let lineWidth: CGFloat = 0.024
    /// How far the wash sits off the lines, the same in every tile.
    static let washOffset = CGVector(dx: -0.014, dy: 0.012)
    /// Each edge is drawn in two passes: where the second is moved to, and
    /// how heavy it is.
    static let passes: [(offset: CGVector, weight: CGFloat)] = [
        (CGVector(dx: 0, dy: 0), 1), (CGVector(dx: 0.007, dy: -0.006), 0.5),
    ]
    /// How far an edge wanders, at most, from where it should be.
    static let wobble: CGFloat = 0.012

    static func draw(_ tile: Tile, in context: CGContext, seed: UInt64) {
        var random = SplitMix64(seed: bandSeed(tile, seed) ^ 0x5EED)
        context.setFillColor(paper)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        speckle(in: context, random: &random)
        guard let strand = tile.strand else { return }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        let edges = drawBand(of: tile, strand, in: context, seed: seed)
        for corner in TileGeometry.underCorners(of: strand) {
            hatch(
                at: corner, inside: TileGeometry.region(between: edges), in: context,
                random: &random)
            context.erase(
                along: TileGeometry.overStrand(at: corner),
                width: 2 * (TileGeometry.halfWidth + gap))
        }
        context.endTransparencyLayer()
    }

    /// Draws the band of `tile`'s strand, the same every time for the same
    /// seed, and returns its edges.
    @discardableResult
    static func drawBand(
        of tile: Tile, _ strand: Strand, in context: CGContext, seed: UInt64
    ) -> [Polyline] {
        var random = SplitMix64(seed: bandSeed(tile, seed))
        let edges = TileGeometry.edges(of: strand)
        band(edges, in: context, random: &random)
        return edges
    }

    private static func bandSeed(_ tile: Tile, _ seed: UInt64) -> UInt64 {
        seed &* 0x9E37_79B9 ^ UInt64(tile.rawValue.unicodeScalars.first!.value)
    }

    /// How much a line may wander at distance `s` along it from a port:
    /// none at the port, then more and more.
    private static func fade(_ s: CGFloat) -> CGFloat {
        let t = max(0, min(1, (s - 0.03) / 0.25))
        return t * t * (3 - 2 * t)
    }

    private static func band(_ edges: [Polyline], in context: CGContext, random: inout SplitMix64) {
        var shift = CGAffineTransform(translationX: washOffset.dx, y: washOffset.dy)
        let region = TileGeometry.region(between: edges)
        context.addPath(region.copy(using: &shift) ?? region)
        context.setFillColor(wash)
        context.fillPath()

        for edge in edges {
            // Still at the ports, which lie `overrun` in from either end.
            let start = TileGeometry.overrun
            let end = edge.length - TileGeometry.overrun
            let envelope = edge.distances.map { s in fade(s - start) * fade(end - s) }
            for pass in passes {
                let wander = Wave(random: &random)
                let weight = Wave(random: &random)
                let wandering = edge.offset { i in
                    envelope[i] * wobble * wander.value(at: edge.distances[i])
                }
                let widths = edge.points.indices.map { i in
                    lineWidth * pass.weight
                        * (1 + envelope[i] * 0.45 * weight.value(at: edge.distances[i]))
                }
                stroke(
                    Polyline(points: wandering.map { $0 + pass.offset }), widths: widths,
                    in: context)
            }
        }
    }

    /// Shading across the band where it goes under another strand at
    /// `corner`: darkest right at the cut, a tone under hatching, fading
    /// away from the crossing. Both start behind the cut, which the gap
    /// erases, so that no unshaded sliver is left at the cut edge.
    private static func hatch(
        at corner: Corner, inside band: CGPath, in context: CGContext, random: inout SplitMix64
    ) {
        let cut = TileGeometry.halfWidth + gap
        let reach: CGFloat = 0.3
        let along = corner.inward
        let slant: CGFloat = 0.35
        let across = (along.perpendicular + along * slant).normalized
        context.saveGState()
        context.addPath(band)
        context.clip()
        context.drawLinearGradient(
            CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: [ink.copy(alpha: 0.22) ?? ink, ink.copy(alpha: 0) ?? ink] as CFArray,
                locations: [0, 1])!, start: corner.point + along * cut,
            end: corner.point + along * (cut + reach), options: .drawsBeforeStartLocation)
        // A hatch line is slanted, so reaches this far back from its middle.
        var s = cut - TileGeometry.halfWidth * slant
        while s < cut + reach {
            let closeness = min(1, 1 - (s - cut) / reach)
            let centre = corner.point + along * s
            let jitter = along * CGFloat.random(in: -0.01...0.01, using: &random)
            let path = CGMutablePath()
            path.move(to: centre + across * 0.5 + jitter)
            path.addLine(to: centre - across * 0.5)
            context.stroke(
                path, width: lineWidth * 0.5, color: ink.copy(alpha: 0.7 * closeness) ?? ink)
            s += 0.026 + 0.03 * (1 - closeness)
        }
        context.restoreGState()
    }

    /// Fills a line of varying width, so that it reads as drawn by hand.
    private static func stroke(_ line: Polyline, widths: [CGFloat], in context: CGContext) {
        let left = line.offset { widths[$0] / 2 }
        let right = line.offset { -widths[$0] / 2 }
        let path = CGMutablePath()
        path.addLines(between: left + right.reversed())
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(ink)
        context.fillPath()
    }

    /// Faint flecks in the paper.
    private static func speckle(in context: CGContext, random: inout SplitMix64) {
        for _ in 0..<40 {
            let r = CGFloat.random(in: 0.002...0.006, using: &random)
            let x = CGFloat.random(in: 0...1, using: &random)
            let y = CGFloat.random(in: 0...1, using: &random)
            context.setFillColor(
                CGColor.hex(0x6B5A44, alpha: CGFloat.random(in: 0.06...0.16, using: &random)))
            context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
    }
}

/// A smooth, irregular wave between about -1 and 1: two sines of unrelated
/// frequency and random phase.
private struct Wave {
    var frequencies: (CGFloat, CGFloat)
    var phases: (CGFloat, CGFloat)

    init(random: inout SplitMix64) {
        frequencies = (
            CGFloat.random(in: 0.6...1.1, using: &random),
            CGFloat.random(in: 1.6...2.4, using: &random)
        )
        phases = (
            CGFloat.random(in: 0...1, using: &random), CGFloat.random(in: 0...1, using: &random)
        )
    }

    func value(at s: CGFloat) -> CGFloat {
        0.65 * sin(2 * .pi * (s * frequencies.0 + phases.0)) + 0.35
            * sin(2 * .pi * (s * frequencies.1 + phases.1))
    }
}

/// A small, fast, seedable generator, so that a tile drawn with the same
/// seed comes out the same every time.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
