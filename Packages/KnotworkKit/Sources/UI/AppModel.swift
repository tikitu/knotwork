import Core
import OSLog
import Observation

private let logger = Logger(subsystem: "org.logophile.Knotwork", category: "AppModel")

/// The app's state, and the one place commands are performed.
///
/// Every gesture calls ``perform(_:)`` (through ``attempt(_:)``), and so does
/// ``CommandInbox``. That is what makes a scripted run exercise the same code
/// a touch does. See `docs/commands.md`.
@MainActor
@Observable
public final class AppModel {
    /// The largest knot, in cells, either way: far more than any screen
    /// shows, and small enough that a typo in a script cannot hang the app.
    public nonisolated static let maximumCells = 200

    /// The knot being edited. `nil` until the view has laid out and knows how
    /// many cells fit.
    public private(set) var grid: AntiGrid? { didSet { tiles = grid?.tiles() ?? [] } }

    /// The grid's tiles, worked out once per change rather than on every
    /// redraw.
    public private(set) var tiles: [[Tile]] = []

    /// How the tiles are drawn.
    public private(set) var tileStyle = TileStyle.smooth

    /// Whether the knot's corners come to a sharp point, as in the original
    /// images, rather than keeping the band's width. Drawn tiles only.
    public private(set) var hasPointedCorners = true

    /// Whether the appearance settings are showing.
    public private(set) var isShowingSettings = false

    /// The last thing that went wrong. Logged; nothing shows it yet.
    public private(set) var lastError: String?

    public init() {}

    /// Performs `command` and describes what happened, for a command file's
    /// result.
    @discardableResult
    public func perform(_ command: AppCommand) throws -> String {
        switch command {
        case .newGrid(let rows, let cols):
            let sizes = 1...Self.maximumCells
            guard sizes.contains(rows), sizes.contains(cols) else {
                throw CommandError.gridSize(rows: rows, cols: cols)
            }
            var grid = AntiGrid(rows: rows, cols: cols)
            grid.addBorders()
            self.grid = grid
            return "new \(rows) × \(cols) knot"

        case .toggle(let point):
            guard var grid else { throw CommandError.noGrid }
            guard grid.contains(point) else { throw CommandError.offGrid(point) }
            grid.toggle(x: point.x, y: point.y)
            self.grid = grid
            return "toggled \(point)"

        case .cut(let start, let end):
            guard var grid else { throw CommandError.noGrid }
            for point in [start, end] where !grid.contains(point) {
                throw CommandError.offGrid(point)
            }
            guard start != end, start.x == end.x || start.y == end.y else {
                throw CommandError.notStraight(start, end)
            }
            grid.cut(from: start, to: end)
            self.grid = grid
            return "cut \(start) to \(end)"

        case .setTiles(let style):
            tileStyle = style
            return "tiles: \(style.rawValue)"

        case .setPointedCorners(let on):
            hasPointedCorners = on
            return "pointed corners \(on ? "on" : "off")"

        case .showSettings(let shown):
            isShowingSettings = shown
            return "settings \(shown ? "shown" : "hidden")"
        }
    }

    /// Performs a command from a control, logging a failure rather than
    /// throwing into SwiftUI. Controls call this; ``CommandInbox`` calls
    /// `perform` directly, because a command file wants the error in its
    /// result.
    public func attempt(_ command: AppCommand) {
        do {
            lastError = nil
            try perform(command)
        } catch {
            logger.error("\(command.name, privacy: .public) failed: \(error, privacy: .public)")
            lastError = "\(error)"
        }
    }
}

// MARK: - For controls

extension AppModel {
    // Properties a control can bind to (`$model.tileStyleSetting`) whose
    // setters perform the command, so that the control changes nothing
    // itself (docs/commands.md).

    /// ``tileStyle``, set through ``AppCommand/setTiles(_:)``.
    public var tileStyleSetting: TileStyle {
        get { tileStyle }
        set { attempt(.setTiles(newValue)) }
    }

    /// ``hasPointedCorners``, set through
    /// ``AppCommand/setPointedCorners(_:)``.
    public var pointedCornersSetting: Bool {
        get { hasPointedCorners }
        set { attempt(.setPointedCorners(newValue)) }
    }
}
