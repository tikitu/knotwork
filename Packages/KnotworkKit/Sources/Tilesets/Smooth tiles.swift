import Core
import CoreGraphics

/// Bands with a dark outline and a light fill, on a dark ground, with a gap
/// either side of a strand where it passes over another, cut from the
/// strand beneath.
enum SmoothTiles {
    static let ground = CGColor.hex(0x17352E)
    static let fill = CGColor.hex(0xE8D7A8)
    static let outline = CGColor.hex(0x0B1C17)
    static let outlineWidth: CGFloat = 0.07
    /// The gap either side of a strand where it passes over another.
    static let gap: CGFloat = 0.07

    /// Draws `tile` in a unit square.
    static func draw(_ tile: Tile, in context: CGContext) {
        context.setFillColor(ground)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let strand = tile.strand else { return }
        // A layer of its own, so that erasing a gap uncovers the ground
        // rather than punching through it.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        band(TileGeometry.edges(of: strand), in: context)
        for corner in TileGeometry.underCorners(of: strand) {
            context.erase(
                along: TileGeometry.overStrand(at: corner),
                width: 2 * (TileGeometry.halfWidth + gap))
        }
        context.endTransparencyLayer()
    }

    /// The band of `strand`, for drawing where it spills into the tiles
    /// beside it.
    static func drawBand(of strand: Strand, in context: CGContext) {
        band(TileGeometry.edges(of: strand), in: context)
    }

    private static func band(_ edges: [Polyline], in context: CGContext) {
        context.addPath(TileGeometry.region(between: edges))
        context.setFillColor(fill)
        context.fillPath()
        for edge in edges {
            let path = CGMutablePath()
            // Simplified: CoreGraphics strokes a run of many tiny segments
            // with faint hairlines across it.
            path.addLines(between: edge.simplified(tolerance: 1e-4))
            context.stroke(path, width: outlineWidth, color: outline)
        }
    }
}
