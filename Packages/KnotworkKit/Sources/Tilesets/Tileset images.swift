import Core
import CoreGraphics

/// Every tile of a tileset drawn once, as images, so that a knot can be
/// drawn by repeating them, as the original images are.
///
/// Drawing the geometry is slow (thousands of points and a transparency
/// layer or two per tile), and a knot that fills an iPad has thousands of
/// tiles but only 27 different ones. Drawn afresh for every tile, a redraw
/// took a large fraction of a second; repeating images is as quick as the
/// original images.
///
/// The images are the same two passes as `Tileset.draw(_:in:origin:tileSide:pointedCorners:variant:)`
/// makes, on a clear ground: draw the ground under the whole knot, then every
/// strand, then every spill. Each image reaches past its tile, by its
/// margin: a strand's by a little, so that neighbours overlap; a spill's
/// into the tiles beside it.
public struct TileImages {
    /// Each tile's strand, without its spills.
    public let strands: [Tile: CGImage]
    /// Where each tile's band spills into the tiles beside it. None for a
    /// tile whose strand passes over nothing.
    public let spills: [Tile: CGImage]
    /// How far a strand's image reaches past its tile on every side, in
    /// tile sides.
    public let strandMargin: CGFloat
    /// The same for a spill's image.
    public let spillMargin: CGFloat
}

extension Tileset {
    /// Every tile drawn `side` pixels square, with variant 0.
    public func images(side: Int, pointedCorners: Bool = true) -> TileImages {
        // A pixel each way is more than `CGContext.overlap`; a spill reaches
        // 0.6 of a tile past the corner (`TileGeometry.clip(_:toSpillAt:overlap:)`).
        let strandMargin = 1
        let spillMargin = Int((0.6 * CGFloat(side)).rounded(.up)) + 1
        var strands: [Tile: CGImage] = [:]
        var spills: [Tile: CGImage] = [:]
        for tile in Tile.allCases {
            strands[tile] = image(side: side, margin: strandMargin) { context, rect in
                drawStrand(
                    of: tile, in: context, rect: rect, pointedCorners: pointedCorners, variant: 0)
            }
            if let strand = tile.strand, !TileGeometry.overCorners(of: strand).isEmpty {
                spills[tile] = image(side: side, margin: spillMargin) { context, rect in
                    drawSpills(
                        of: tile, in: context, rect: rect, pointedCorners: pointedCorners,
                        variant: 0)
                }
            }
        }
        return TileImages(
            strands: strands, spills: spills, strandMargin: CGFloat(strandMargin) / CGFloat(side),
            spillMargin: CGFloat(spillMargin) / CGFloat(side))
    }

    /// An image `side` pixels square plus `margin` all round, clear but for
    /// what `draw` draws, given a context whose y axis runs down and the
    /// tile's rectangle in it.
    private func image(side: Int, margin: Int, draw: (CGContext, CGRect) -> Void) -> CGImage? {
        let width = side + 2 * margin
        guard
            let context = CGContext(
                data: nil, width: width, height: width, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(width))
        context.scaleBy(x: 1, y: -1)
        draw(context, CGRect(x: margin, y: margin, width: side, height: side))
        return context.makeImage()
    }
}
