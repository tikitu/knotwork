import Core
import CoreGraphics
import Testing
import Tilesets

/// The app draws a knot by repeating `TileImages`; the tile sheets and the
/// icon draw its geometry. The two must come out the same.
struct TilesetImagesTests {
    @Test(arguments: Tileset.allCases, [true, false])
    func `a knot of images matches the knot drawn`(tileset: Tileset, pointedCorners: Bool) throws {
        var grid = AntiGrid(rows: 3, cols: 4)
        grid.addBorders()
        grid.cut(from: GridPoint(x: 4, y: 2), to: GridPoint(x: 4, y: 6))
        grid.toggle(x: 5, y: 3)
        grid.toggle(x: 3, y: 2)
        let tiles = grid.tiles()
        let side = 20

        let drawn = try Bitmap(tiles: tiles, side: side)
        tileset.draw(
            tiles, in: drawn.context, origin: .zero, tileSide: CGFloat(side),
            pointedCorners: pointedCorners)

        let repeated = try Bitmap(tiles: tiles, side: side)
        let images = tileset.images(side: side, pointedCorners: pointedCorners)
        let context = repeated.context
        context.setFillColor(tileset.ground)
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
        for (layer, margin) in [
            (images.strands, images.strandMargin), (images.spills, images.spillMargin),
        ] {
            for (y, row) in tiles.enumerated() {
                for (x, tile) in row.enumerated() {
                    guard let image = layer[tile] else { continue }
                    let inset = -margin * CGFloat(side)
                    let rect = CGRect(x: x * side, y: y * side, width: side, height: side).insetBy(
                        dx: inset, dy: inset)
                    // Upright in a context whose y axis runs down.
                    context.saveGState()
                    context.translateBy(x: rect.minX, y: rect.maxY)
                    context.scaleBy(x: 1, y: -1)
                    context.draw(image, in: CGRect(origin: .zero, size: rect.size))
                    context.restoreGState()
                }
            }
        }

        #expect(drawn.largestDifference(from: repeated) <= 4)
    }
}

/// An RGBA bitmap whose y axis runs down.
private struct Bitmap {
    let context: CGContext

    init(tiles: [[Tile]], side: Int) throws {
        let width = (tiles.first?.count ?? 0) * side
        let height = tiles.count * side
        context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
    }

    /// The largest difference in any channel of any pixel.
    func largestDifference(from other: Bitmap) -> Int {
        let count = context.bytesPerRow * context.height
        let a = context.data!.bindMemory(to: UInt8.self, capacity: count)
        let b = other.context.data!.bindMemory(to: UInt8.self, capacity: count)
        return (0..<count).map { abs(Int(a[$0]) - Int(b[$0])) }.max() ?? 0
    }
}
