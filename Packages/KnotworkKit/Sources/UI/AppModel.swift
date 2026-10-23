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
