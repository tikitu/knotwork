import Core
import CoreGraphics

/// A way of drawing the knot's tiles, generated in code rather than read
/// from images, so that a tile can be drawn at any size and, in time,
/// differently each time it appears.
///
/// Every tileset draws the same geometry (`TileGeometry`); they differ in
/// how.
public enum Tileset: String, CaseIterable, Sendable {
    /// Crisp outlined bands, as if engraved.
    case smooth
    /// Pencil and wash, slightly unsteady.
    case sketch

    public var name: String {
        switch self {
        case .smooth: "Smooth"
        case .sketch: "Sketch"
        }
    }

    /// Draws a knot, `tiles` row by row, with its top left at `origin`, in a
    /// context whose y axis runs down.
    ///
    /// In two passes: every tile, then every crossing. A strand that passes
    /// over another at a tile's corner spills into the two tiles beside it,
    /// and the tile it belongs to draws that spill, on top of them.
    ///
    /// `variant` chooses, for each tile by column and row, among the ways it
    /// can be drawn, for tilesets whose tiles are not all alike; tiles drawn
    /// with different variants still meet without a seam. Only the sketch
    /// tileset varies, and it does not yet vary with `variant`, only with the
    /// tile.
    public func draw(
        _ tiles: [[Tile]], in context: CGContext, origin: CGPoint, tileSide: CGFloat,
        pointedCorners: Bool = true, variant: (_ x: Int, _ y: Int) -> UInt64 = { _, _ in 0 }
    ) {
        func rect(_ x: Int, _ y: Int) -> CGRect {
            CGRect(
                x: origin.x + CGFloat(x) * tileSide, y: origin.y + CGFloat(y) * tileSide,
                width: tileSide, height: tileSide)
        }
        // The ground once, under the whole knot: drawn tile by tile, it
        // shows the edges between tiles as hairlines.
        let rows = CGFloat(tiles.count)
        let cols = CGFloat(tiles.first?.count ?? 0)
        context.setFillColor(ground)
        context.fill(
            CGRect(x: origin.x, y: origin.y, width: cols * tileSide, height: rows * tileSide))
        for (y, row) in tiles.enumerated() {
            for (x, tile) in row.enumerated() {
                drawStrand(
                    of: tile, in: context, rect: rect(x, y), pointedCorners: pointedCorners,
                    variant: variant(x, y))
            }
        }
        for (y, row) in tiles.enumerated() {
            for (x, tile) in row.enumerated() {
                drawSpills(
                    of: tile, in: context, rect: rect(x, y), pointedCorners: pointedCorners,
                    variant: variant(x, y))
            }
        }
    }

    /// Draws `tile` alone, filling `rect`, without the spills of the strands
    /// that pass over it at its corners, which belong to its neighbours.
    public func draw(
        _ tile: Tile, in context: CGContext, rect: CGRect, pointedCorners: Bool = true,
        variant: UInt64 = 0
    ) {
        context.setFillColor(ground)
        context.fill(rect)
        drawStrand(
            of: tile, in: context, rect: rect, pointedCorners: pointedCorners, variant: variant)
    }

    /// The colour under the strands.
    public var ground: CGColor {
        switch self {
        case .smooth: SmoothTiles.ground
        case .sketch: SketchTiles.paper
        }
    }

    /// Draws what `tile` adds to the ground under it, filling `rect`.
    func drawStrand(
        of tile: Tile, in context: CGContext, rect: CGRect, pointedCorners: Bool, variant: UInt64
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect.insetBy(dx: -context.overlap, dy: -context.overlap))
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width, y: rect.height)
        // One layer, so that at the clip's antialiased edge the tile is
        // blended once, not outline and fill each in part.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        switch self {
        case .smooth: SmoothTiles.draw(tile, in: context, pointedCorners: pointedCorners)
        case .sketch:
            SketchTiles.draw(tile, in: context, seed: variant, pointedCorners: pointedCorners)
        }
        context.endTransparencyLayer()
    }

    /// Draws where `tile`'s band spills over its corners into the tiles
    /// beside it, where it passes over another strand.
    func drawSpills(
        of tile: Tile, in context: CGContext, rect: CGRect, pointedCorners: Bool, variant: UInt64
    ) {
        guard let strand = tile.strand else { return }
        let corners = TileGeometry.overCorners(of: strand)
        guard !corners.isEmpty else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width, y: rect.height)
        let overlap = context.overlap
        for corner in corners {
            context.saveGState()
            TileGeometry.clip(context, toSpillAt: corner, overlap: overlap)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            switch self {
            case .smooth:
                SmoothTiles.drawBand(of: tile, in: context, pointedCorners: pointedCorners)
            case .sketch:
                SketchTiles.drawBand(
                    of: tile, in: context, seed: variant, pointedCorners: pointedCorners)
            }
            context.endTransparencyLayer()
            context.restoreGState()
        }
    }

    /// Draws the edges of `tile`'s band, without gaps, as lines `lineWidth`
    /// wide: for laying the shared geometry over other images to compare.
    public static func drawOutline(
        of tile: Tile, in context: CGContext, rect: CGRect, color: CGColor, lineWidth: CGFloat,
        pointedCorners: Bool = true
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width, y: rect.height)
        for edge in TileGeometry.edges(of: tile, pointedCorners: pointedCorners) {
            let path = CGMutablePath()
            path.addLines(between: edge.simplified(tolerance: 1e-4))
            context.stroke(path, width: lineWidth / rect.width, color: color)
        }
    }

    /// `tile` as an image `side` pixels square.
    public func image(of tile: Tile, side: Int, variant: UInt64 = 0) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(side))
        context.scaleBy(x: 1, y: -1)
        draw(
            tile, in: context, rect: CGRect(x: 0, y: 0, width: side, height: side), variant: variant
        )
        return context.makeImage()
    }
}

extension CGContext {
    /// How far, in the current units, each tile is drawn past its edges, so
    /// that neighbours overlap: two antialiased edges that merely meet let
    /// the background show through as a hairline. Every tileset draws the
    /// same thing either side of an edge, and opaquely, so the overlap does
    /// not show (as long as each tile is drawn as a single layer).
    var overlap: CGFloat {
        let pixel = convertToDeviceSpace(CGSize(width: 1, height: 0))
        return 0.75
            / max(1e-6, (pixel.width * pixel.width + pixel.height * pixel.height).squareRoot())
    }

    /// Strokes `path` with butt caps and round joins.
    func stroke(_ path: CGPath, width: CGFloat, color: CGColor) {
        addPath(path)
        setLineWidth(width)
        setLineCap(.butt)
        setLineJoin(.round)
        setStrokeColor(color)
        strokePath()
    }

    /// Erases a band `width` wide along `path`: the gap either side of a
    /// strand that passes over another.
    func erase(along path: CGPath, width: CGFloat) {
        saveGState()
        setBlendMode(.clear)
        stroke(path, width: width, color: CGColor(gray: 0, alpha: 1))
        restoreGState()
    }
}

extension CGColor {
    /// A colour from a hex triple such as `0x1F3A3D`.
    static func hex(_ rgb: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255, alpha: alpha)
    }
}
