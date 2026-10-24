import Core
import SwiftUI
import Tilesets

/// The knot, edited by touch: a tap on a grid point toggles it, a drag along
/// a row or column cuts there. In clear mode, a drag spans a rectangle whose
/// cells are emptied instead.
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

/// The knot at a given size, with the gesture that edits it and the line or
/// rectangle that shows a drag in progress.
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
                switch model.dragMode {
                case .cut:
                    let start = point(nearest: drag.startLocation)
                    let end = point(nearest: drag.location)
                    CutPreview(
                        start: start, end: end, tileSide: tileSide,
                        isValid: start == end || isCut(from: start, to: end))
                case .clear:
                    ClearPreview(
                        start: corner(nearest: drag.startLocation),
                        end: corner(nearest: drag.location), tileSide: tileSide)
                }
            }
        }.contentShape(.rect).gesture(
            DragGesture(minimumDistance: 0).updating($drag) { value, drag, _ in drag = value }
                .onEnded(didEndDrag)
        ).accessibilityElement().accessibilityLabel("Knot").accessibilityValue(
            "\(rows) by \(cols) cells"
        ).accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch model.dragMode {
        case .cut: "Tap a grid point to change it, or drag along a line to cut the knot."
        case .clear: "Drag across the knot to clear the cells in a rectangle."
        }
    }

    private func didEndDrag(_ value: DragGesture.Value) {
        switch model.dragMode {
        case .cut:
            let start = point(nearest: value.startLocation)
            let end = point(nearest: value.location)
            if start == end {
                model.attempt(.toggle(start))
            } else if isCut(from: start, to: end) {
                model.attempt(.cut(from: start, to: end))
            }
        case .clear:
            let start = corner(nearest: value.startLocation)
            let end = corner(nearest: value.location)
            if start.x != end.x && start.y != end.y {
                model.attempt(.clearCells(from: start, to: end))
            }
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

    /// The cell corner nearest `location`, kept on the grid, so that a drag
    /// that runs off the knot clears up to its edge.
    private func corner(nearest location: CGPoint) -> GridPoint {
        func corner(_ length: CGFloat, cells: Int) -> Int {
            2 * min(max(Int((length / (2 * tileSide)).rounded()), 0), cells)
        }
        return GridPoint(x: corner(location.x, cells: cols), y: corner(location.y, cells: rows))
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

/// The rectangle that follows a drag in clear mode, snapped to cell corners:
/// filled while letting go would clear it, an outline while it has no cells
/// in it.
private struct ClearPreview: View {
    let start: GridPoint
    let end: GridPoint
    let tileSide: CGFloat

    var body: some View {
        let rect = CGRect(
            x: CGFloat(min(start.x, end.x)) * tileSide, y: CGFloat(min(start.y, end.y)) * tileSide,
            width: CGFloat(abs(end.x - start.x)) * tileSide,
            height: CGFloat(abs(end.y - start.y)) * tileSide)
        Path(rect).fill(.red.opacity(rect.width > 0 && rect.height > 0 ? 0.25 : 0)).stroke(
            .red, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        ).allowsHitTesting(false)
    }
}

/// The tiles, drawn. A view of its own so that a drag, which redraws the
/// preview line many times a second, does not redraw them.
///
/// Every style is drawn by repeating one image per tile: drawing each tile's
/// geometry afresh was far too slow for a large knot (`TileImages`).
private struct KnotCanvas: View {
    let tiles: [[Tile]]
    let tileSide: CGFloat
    let style: TileStyle
    let hasPointedCorners: Bool

    @Environment(\.displayScale)
    private var displayScale

    var body: some View {
        let images = style.tileset.map { tileset in
            DrawnTiles.images(
                tileset, side: Int((tileSide * displayScale).rounded(.up)),
                pointedCorners: hasPointedCorners)
        }
        Canvas { context, size in
            if let tileset = style.tileset, let images {
                context.fill(
                    Path(CGRect(origin: .zero, size: size)), with: .color(Color(tileset.ground)))
                draw(images.strands, margin: images.strandMargin, in: context)
                draw(images.spills, margin: images.spillMargin, in: context)
            } else {
                drawImages(in: context)
            }
        }
    }

    /// One image per tile, each reaching `margin` tile sides past it.
    private func draw(_ images: [Tile: CGImage], margin: CGFloat, in context: GraphicsContext) {
        var resolved: [Tile: GraphicsContext.ResolvedImage] = [:]
        for (y, row) in tiles.enumerated() {
            for (x, tile) in row.enumerated() {
                guard let image = images[tile] else { continue }
                let resolvedImage =
                    resolved[tile] ?? context.resolve(Image(decorative: image, scale: displayScale))
                resolved[tile] = resolvedImage
                context.draw(
                    resolvedImage,
                    in: rect(x, y).insetBy(dx: -margin * tileSide, dy: -margin * tileSide))
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
                context.draw(image, in: rect(x, y))
            }
        }
    }

    private func rect(_ x: Int, _ y: Int) -> CGRect {
        CGRect(
            x: CGFloat(x) * tileSide, y: CGFloat(y) * tileSide, width: tileSide, height: tileSide)
    }
}

/// The images of the tileset last drawn, kept until the tileset, its size or
/// its corners change, rather than drawn again for every change to the knot.
@MainActor
private enum DrawnTiles {
    private static var last: (key: Key, images: TileImages)?

    private struct Key: Equatable {
        var tileset: Tileset
        var side: Int
        var pointedCorners: Bool
    }

    static func images(_ tileset: Tileset, side: Int, pointedCorners: Bool) -> TileImages {
        let key = Key(tileset: tileset, side: side, pointedCorners: pointedCorners)
        if let last, last.key == key { return last.images }
        let images = tileset.images(side: side, pointedCorners: pointedCorners)
        last = (key, images)
        return images
    }
}
