import Core

/// Everything a person can do in the app, as a value.
///
/// The gestures perform these, and so does the command inbox, which is how a
/// scripted run drives the app without touches. Because both go through
/// ``AppModel/perform(_:)``, a script exercises the same code a touch does.
/// **A control that bypasses `perform` is a bug.** Adding one means adding
/// its command, its row in `docs/commands.md`, and its case in the decoder.
public enum AppCommand: Equatable, Sendable {
    /// Replaces the knot with a fresh one of `rows` × `cols` cells, bordered.
    case newGrid(rows: Int, cols: Int)
    /// A tap on a grid point: cycles a segment's break line, or empties or
    /// refills a cell.
    case toggle(GridPoint)
    /// A drag along a straight line: toggles break lines all along it.
    case cut(from: GridPoint, to: GridPoint)
    /// Draws the tiles in `style`.
    case setTiles(TileStyle)
    /// Whether the knot's corners come to a sharp point (drawn tiles only).
    case setPointedCorners(Bool)
    /// Shows or hides the appearance settings.
    case showSettings(Bool)

    /// The command's name in a command file.
    public var name: String {
        switch self {
        case .newGrid: "newGrid"
        case .toggle: "toggle"
        case .cut: "cut"
        case .setTiles: "setTiles"
        case .setPointedCorners: "setPointedCorners"
        case .showSettings: "showSettings"
        }
    }
}

public enum CommandError: Error, Equatable, CustomStringConvertible {
    case noGrid
    case gridSize(rows: Int, cols: Int)
    case offGrid(GridPoint)
    /// A cut has to run straight along a row or a column, and go somewhere.
    case notStraight(GridPoint, GridPoint)

    public var description: String {
        switch self {
        case .noGrid: "there is no knot yet"
        case .gridSize(let rows, let cols):
            "a knot is 1 to \(AppModel.maximumCells) cells each way, not \(rows) × \(cols)"
        case .offGrid(let point): "\(point) is off the grid"
        case .notStraight(let start, let end):
            "a cut runs straight along a row or column; \(start) to \(end) does not"
        }
    }
}
