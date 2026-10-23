import Core
import SwiftUI

/// The knot, edited by touch: a tap on a grid point toggles it, a drag along
/// a row or column cuts there.
///
/// Fills the space it is given. Until there is a knot, it asks for one with
/// as many cells as fit; after that the knot keeps its size, and is drawn
/// smaller if the space shrinks (on rotation, say).
public struct KnotView: View {
    let model: AppModel

    public init(model: AppModel) { self.model = model }

    public var body: some View {
        GeometryReader { proxy in
            if let grid = model.grid {
                KnotEditor(
                    model: model, rows: grid.rows, cols: grid.cols,
                    tileSide: KnotMetrics.tileSide(
                        rows: grid.rows, cols: grid.cols, fitting: proxy.size)
                ).frame(maxWidth: .infinity)
            }
        }.onGeometryChange(for: CGSize.self, of: \.size) { size in
            // The first size reported can be zero, before layout has
            // finished; a knot made from it would be a single cell.
            guard model.grid == nil, size.width >= KnotMetrics.cellSide,
                size.height >= KnotMetrics.cellSide
            else { return }
            model.attempt(
                .newGrid(
                    rows: KnotMetrics.cells(fitting: size.height),
                    cols: KnotMetrics.cells(fitting: size.width)))
        }
    }
}

/// Sizes, in points.
enum KnotMetrics {
    /// A tile at full size: one pixel of Boston-Baden's images to a point.
    static let tileSide: CGFloat = 20
    /// A cell is two tiles each way.
    static let cellSide = tileSide * 2

    /// How many cells fit in `length`, which is at least one cell long.
    static func cells(fitting length: CGFloat) -> Int {
        min(Int(length / cellSide), AppModel.maximumCells)
    }

    /// Full size, unless that would not fit.
    static func tileSide(rows: Int, cols: Int, fitting size: CGSize) -> CGFloat {
        min(tileSide, size.width / CGFloat(cols * 2), size.height / CGFloat(rows * 2))
    }
}

/// The knot at a given size, with the gesture that edits it and the line
/// that shows a cut in progress.
private struct KnotEditor: View {
    let model: AppModel
    let rows: Int
    let cols: Int
    let tileSide: CGFloat

    /// The drag in progress, if any. Only a preview: what the drag does
    /// happens when it ends, as a command.
    @GestureState
    private var drag: DragGesture.Value?

    var body: some View {
        KnotCanvas(
            tiles: model.tiles, tileSide: tileSide, style: model.tileStyle,
            hasPointedCorners: model.hasPointedCorners
        ).frame(width: CGFloat(cols * 2) * tileSide, height: CGFloat(rows * 2) * tileSide).overlay {
            if let drag {
                let start = point(nearest: drag.startLocation)
                let end = point(nearest: drag.location)
                CutPreview(
                    start: start, end: end, tileSide: tileSide,
                    isValid: start == end || isCut(from: start, to: end))
            }
        }.contentShape(.rect).gesture(
            DragGesture(minimumDistance: 0).updating($drag) { value, drag, _ in drag = value }
                .onEnded(didEndDrag)
        ).accessibilityElement().accessibilityLabel("Knot").accessibilityValue(
            "\(rows) by \(cols) cells"
        ).accessibilityHint("Tap a grid point to change it, or drag along a line to cut the knot.")
    }

    private func didEndDrag(_ value: DragGesture.Value) {
        let start = point(nearest: value.startLocation)
        let end = point(nearest: value.location)
        if start == end {
            model.attempt(.toggle(start))
        } else if isCut(from: start, to: end) {
            model.attempt(.cut(from: start, to: end))
        }
    }

    /// Whether a drag from `start` to `end` would cut, rather than being
    /// dropped: straight along a row or column, and on the grid.
    private func isCut(from start: GridPoint, to end: GridPoint) -> Bool {
        (start.x == end.x || start.y == end.y) && isOnGrid(start) && isOnGrid(end)
    }

    private func isOnGrid(_ point: GridPoint) -> Bool {
        (0...cols * 2).contains(point.x) && (0...rows * 2).contains(point.y)
    }

    private func point(nearest location: CGPoint) -> GridPoint {
        GridPoint(
            x: Int((location.x / tileSide).rounded()), y: Int((location.y / tileSide).rounded()))
    }
}

/// The line that follows a drag: solid while letting go would cut or tap,
/// faint while it would do nothing.
private struct CutPreview: View {
    let start: GridPoint
    let end: GridPoint
    let tileSide: CGFloat
    let isValid: Bool

    var body: some View {
        Path { path in
            path.move(to: location(of: start))
            path.addLine(to: location(of: end))
        }.stroke(.red.opacity(isValid ? 1 : 0.5), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .allowsHitTesting(false)
    }

    private func location(of point: GridPoint) -> CGPoint {
        CGPoint(x: CGFloat(point.x) * tileSide, y: CGFloat(point.y) * tileSide)
    }
}

/// The tiles, drawn. A view of its own so that a drag, which redraws the
/// preview line many times a second, does not redraw them.
private struct KnotCanvas: View {
    let tiles: [[Tile]]
    let tileSide: CGFloat
    let style: TileStyle
    let hasPointedCorners: Bool

    var body: some View {
        Canvas { context, _ in
            if let tileset = style.tileset {
                // Drawn in CoreGraphics, in two passes over the whole knot
                // (`Tileset.draw(_:in:origin:tileSide:pointedCorners:variant:)`).
                context.withCGContext { cg in
                    tileset.draw(
                        tiles, in: cg, origin: .zero, tileSide: tileSide,
                        pointedCorners: hasPointedCorners)
                }
            } else {
                drawImages(in: context)
            }
        }
    }

    /// Boston-Baden's images, tile by tile.
    private func drawImages(in context: GraphicsContext) {
        var resolved: [Tile: GraphicsContext.ResolvedImage] = [:]
        for (y, row) in tiles.enumerated() {
            for (x, tile) in row.enumerated() {
                let image = resolved[tile] ?? context.resolve(tile.image)
                resolved[tile] = image
                context.draw(
                    image,
                    in: CGRect(
                        x: CGFloat(x) * tileSide, y: CGFloat(y) * tileSide, width: tileSide,
                        height: tileSide))
            }
        }
    }
}
