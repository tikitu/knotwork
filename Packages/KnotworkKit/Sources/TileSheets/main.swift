// Renders every tileset to PNG, beside Boston-Baden's original images, for
// comparing them: each tile on its own, and knots made of them.
//
//     swift run --package-path Packages/KnotworkKit TileSheets <original GIFs> <output directory>
//
// `make tile-sheets` runs it with the paths filled in.

import Core
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Tilesets
import UniformTypeIdentifiers

/// Draws a tile filling a rectangle, in a context whose y axis runs down.
typealias DrawTile = (Tile, CGContext, CGRect) -> Void

/// One way of drawing tiles: alone, and as a knot (which for the tilesets is
/// more than tile after tile: see `Tileset.draw(_:in:origin:tileSide:variant:)`).
struct Style {
    var title: String
    var file: String
    var drawTile: DrawTile
    var drawKnot: (_ tiles: [[Tile]], CGContext, _ origin: CGPoint, _ side: CGFloat) -> Void
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("usage: TileSheets <original GIFs> <output directory>\n".utf8))
    exit(64)
}
let originals = URL(filePath: arguments[1], directoryHint: .isDirectory)
let output = URL(filePath: arguments[2], directoryHint: .isDirectory)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Boston-Baden's images, scaled up without smoothing, as they are in the app.
func originalTiles() throws -> DrawTile {
    var images: [Tile: CGImage] = [:]
    for tile in Tile.allCases {
        let url = originals.appending(path: "\(tile.rawValue).gif")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path]) }
        images[tile] = image
    }
    return { tile, context, rect in
        guard let image = images[tile] else { return }
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}

// MARK: - Knots to show

struct Sample {
    var name: String
    var tiles: [[Tile]]
}

let samples: [Sample] = {
    var small = AntiGrid(rows: 3, cols: 2)
    small.addBorders()
    var large = AntiGrid(rows: 4, cols: 6)
    large.addBorders()
    large.cut(from: GridPoint(x: 6, y: 2), to: GridPoint(x: 6, y: 6))
    large.cut(from: GridPoint(x: 0, y: 4), to: GridPoint(x: 4, y: 4))
    large.cut(from: GridPoint(x: 8, y: 2), to: GridPoint(x: 12, y: 2))
    large.toggle(x: 9, y: 5)
    return [
        Sample(name: "3 × 2", tiles: small.tiles()),
        Sample(name: "3 × 2, inverted", tiles: small.tiles(inverted: true)),
        Sample(name: "4 × 6, with cuts and an empty cell", tiles: large.tiles()),
    ]
}()

// MARK: - Drawing

let paper = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let text = CGColor(srgbRed: 0.2, green: 0.2, blue: 0.22, alpha: 1)

func drawText(_ string: String, at point: CGPoint, size: CGFloat, in context: CGContext) {
    let font = CTFontCreateWithName("Helvetica Neue" as CFString, size, nil)
    let attributed = NSAttributedString(
        string: string,
        attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): text,
        ])
    let line = CTLineCreateWithAttributedString(attributed)
    context.saveGState()
    context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    context.textPosition = point
    CTLineDraw(line, context)
    context.restoreGState()
}

/// Draws a knot tile after tile.
func drawTiles(
    _ tiles: [[Tile]], at origin: CGPoint, side: CGFloat, with drawTile: DrawTile,
    in context: CGContext
) {
    for (y, row) in tiles.enumerated() {
        for (x, tile) in row.enumerated() {
            drawTile(
                tile, context,
                CGRect(
                    x: origin.x + CGFloat(x) * side, y: origin.y + CGFloat(y) * side, width: side,
                    height: side))
        }
    }
}

/// A sheet for one tileset: every tile, labelled, then the sample knots.
struct Sheet {
    static let margin: CGFloat = 32
    static let tileSide: CGFloat = 64
    static let tileGap: CGFloat = 22
    static let tilesPerRow = 14
    static let knotTileSide: CGFloat = 32

    static var width: CGFloat { 2 * margin + CGFloat(tilesPerRow) * (tileSide + tileGap) - tileGap }

    static var height: CGFloat {
        let tileRows = (Tile.allCases.count + tilesPerRow - 1) / tilesPerRow
        let knotHeight = samples.map { CGFloat($0.tiles.count) }.max()! * knotTileSide
        return margin + 40 + CGFloat(tileRows) * (tileSide + 30) + 16 + knotHeight + 30 + margin
    }

    /// Draws the sheet with its top left at `origin`.
    static func draw(_ style: Style, at origin: CGPoint, in context: CGContext) {
        var y = origin.y + margin
        drawText(style.title, at: CGPoint(x: origin.x + margin, y: y + 22), size: 26, in: context)
        y += 40
        for (i, tile) in Tile.allCases.enumerated() {
            let column = i % tilesPerRow
            let row = i / tilesPerRow
            let rect = CGRect(
                x: origin.x + margin + CGFloat(column) * (tileSide + tileGap),
                y: y + CGFloat(row) * (tileSide + 30), width: tileSide, height: tileSide)
            style.drawTile(tile, context, rect)
            drawText(
                tile.rawValue, at: CGPoint(x: rect.midX - 4, y: rect.maxY + 18), size: 15,
                in: context)
        }
        y += CGFloat((Tile.allCases.count + tilesPerRow - 1) / tilesPerRow) * (tileSide + 30) + 16
        var x = origin.x + margin
        for sample in samples {
            style.drawKnot(sample.tiles, context, CGPoint(x: x, y: y), knotTileSide)
            let knotHeight = CGFloat(sample.tiles.count) * knotTileSide
            drawText(sample.name, at: CGPoint(x: x, y: y + knotHeight + 20), size: 13, in: context)
            x += CGFloat(sample.tiles[0].count) * knotTileSide + 40
        }
    }
}

/// Renders `size` points at `scale` pixels to the point, y running down, to
/// a PNG at `url`.
func render(to url: URL, size: CGSize, scale: CGFloat = 2, drawing: (CGContext) -> Void) throws {
    guard
        let context = CGContext(
            data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }
    context.translateBy(x: 0, y: size.height * scale)
    context.scaleBy(x: scale, y: -scale)
    context.setFillColor(paper)
    context.fill(CGRect(origin: .zero, size: size))
    drawing(context)
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

// MARK: - Output

let original = try originalTiles()
let styles =
    [
        Style(
            title: "Original (Boston-Baden)", file: "original", drawTile: original,
            drawKnot: { tiles, context, origin, side in
                drawTiles(tiles, at: origin, side: side, with: original, in: context)
            })
    ]
    + Tileset.allCases.map { tileset in
        Style(
            title: tileset.name, file: tileset.rawValue,
            drawTile: { tile, context, rect in tileset.draw(tile, in: context, rect: rect) },
            drawKnot: { tiles, context, origin, side in
                tileset.draw(tiles, in: context, origin: origin, tileSide: side)
            })
    }

let sheetSize = CGSize(width: Sheet.width, height: Sheet.height)
for style in styles {
    let url = output.appending(path: "\(style.file).png")
    try render(to: url, size: sheetSize) { context in Sheet.draw(style, at: .zero, in: context) }
    print(url.path)
}

let all = output.appending(path: "all.png")
try render(to: all, size: CGSize(width: Sheet.width, height: Sheet.height * CGFloat(styles.count)))
{ context in
    for (i, style) in styles.enumerated() {
        Sheet.draw(style, at: CGPoint(x: 0, y: CGFloat(i) * Sheet.height), in: context)
    }
}
print(all.path)

/// One knot large, in every tileset side by side, for the detail; and last,
/// the shared geometry's outlines laid over the original.
let closeUp = output.appending(path: "close-up.png")
let closeUpSide: CGFloat = 72
let closeUpTiles = samples[0].tiles
let closeUpKnot = CGSize(
    width: CGFloat(closeUpTiles[0].count) * closeUpSide,
    height: CGFloat(closeUpTiles.count) * closeUpSide)
let outlineColor = CGColor(srgbRed: 0.85, green: 0.05, blue: 0.1, alpha: 1)
try render(
    to: closeUp,
    size: CGSize(
        width: 2 * Sheet.margin + CGFloat(styles.count + 1) * (closeUpKnot.width + 40) - 40,
        height: 2 * Sheet.margin + closeUpKnot.height + 30)
) { context in
    for (i, style) in styles.enumerated() {
        let x = Sheet.margin + CGFloat(i) * (closeUpKnot.width + 40)
        style.drawKnot(closeUpTiles, context, CGPoint(x: x, y: Sheet.margin), closeUpSide)
        drawText(
            style.title, at: CGPoint(x: x, y: Sheet.margin + closeUpKnot.height + 24), size: 15,
            in: context)
    }
    let x = Sheet.margin + CGFloat(styles.count) * (closeUpKnot.width + 40)
    context.setAlpha(0.45)
    drawTiles(
        closeUpTiles, at: CGPoint(x: x, y: Sheet.margin), side: closeUpSide, with: original,
        in: context)
    context.setAlpha(1)
    drawTiles(
        closeUpTiles, at: CGPoint(x: x, y: Sheet.margin), side: closeUpSide,
        with: { tile, context, rect in
            Tileset.drawOutline(
                of: tile, in: context, rect: rect, color: outlineColor, lineWidth: 1.5)
        }, in: context)
    drawText(
        "New outlines over the original",
        at: CGPoint(x: x, y: Sheet.margin + closeUpKnot.height + 24), size: 15, in: context)
}
print(closeUp.path)
