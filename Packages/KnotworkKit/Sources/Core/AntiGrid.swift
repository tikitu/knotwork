/// What lies along one segment of the grid: a horizontal or vertical break
/// line, or nothing (`o`), which lets the knot's strands cross there.
public enum BreakLine: Sendable { case h, v, o }

/// A point where break lines can start and end, in tile units: `x` runs
/// `0...2 * cols`, `y` runs `0...2 * rows`.
public struct GridPoint: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public var description: String { "(\(x), \(y))" }
}

/// The break lines of a knot, from which its tiles are worked out
/// (Boston-Baden's "anti-grid"). A knot of `rows` × `cols` cells is
/// `2 * rows` × `2 * cols` tiles.
public struct AntiGrid: Equatable, Sendable {
    fileprivate var breaklines: [[BreakLine]]
    fileprivate var empty: [[Bool]]
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        precondition(rows > 0)
        precondition(cols > 0)
        var breaklines: [[BreakLine]] = []
        for _ in 0..<rows {
            breaklines.append([BreakLine](repeating: .o, count: cols))
            breaklines.append([BreakLine](repeating: .o, count: cols + 1))
        }
        breaklines.append([BreakLine](repeating: .o, count: cols * 2))
        self.breaklines = breaklines
        self.rows = rows
        self.cols = cols
        self.empty = [[Bool]](repeating: [Bool](repeating: false, count: cols * 2), count: rows * 2)
    }

    /// Whether `point` is on the grid, borders included.
    public func contains(_ point: GridPoint) -> Bool {
        (0...cols * 2).contains(point.x) && (0...rows * 2).contains(point.y)
    }

    private func edges(x: Int, y: Int) -> Set<Edge> {
        let odd = y % 2 == 1
        let above = breaklines[y][(x + (odd ? 1 : 0)) / 2]
        let below = breaklines[y + 1][(x + (odd ? 0 : 1)) / 2]
        var edges = Set<Edge>()
        switch above {
        case .h: edges.insert(.n)
        case .v: edges.insert((x + y) % 2 == 0 ? .e : .w)
        case .o: break
        }
        switch below {
        case .h: edges.insert(.s)
        case .v: edges.insert((x + y) % 2 == 0 ? .w : .e)
        case .o: break
        }
        if empty[(y - 1) / 2][x / 2] { edges.insert(.n) }
        if empty[y / 2][(x - 1) / 2] { edges.insert(.w) }
        if empty[(y + 1) / 2][x / 2] { edges.insert(.s) }
        if empty[y / 2][(x + 1) / 2] { edges.insert(.e) }
        if empty[y / 2][x / 2] { edges.formUnion([.n, .s, .w, .e]) }
        return edges
    }

    /// The tiles to draw, row by row.
    public func tiles(inverted: Bool = false) -> [[Tile]] {
        (0..<rows * 2).map { y in
            (0..<cols * 2).map { x in
                Tile(base: .at(x: x, y: y, inverted: inverted), edges: edges(x: x, y: y))
            }
        }
    }

    /// Break lines all the way round.
    public mutating func addBorders() {
        addEdge(.h, x: 0, y: 0, length: cols * 2)
        addEdge(.h, x: 0, y: rows * 2, length: cols * 2)
        addEdge(.v, x: 0, y: 0, length: rows * 2)
        addEdge(.v, x: cols * 2, y: 0, length: rows * 2)
    }

    public mutating func addEdge(_ line: BreakLine, x: Int, y: Int) {
        guard contains(GridPoint(x: x, y: y)) else { return }
        guard (x + y) % 2 == 1 else { return }
        toggle(line, x: x, y: y)
    }

    public mutating func addEdge(_ line: BreakLine, x: Int, y: Int, length: Int) {
        guard length > 0 else { return }
        for i in 0..<length {
            addEdge(line, x: x + (line == .h ? i : 0), y: y + (line == .v ? i : 0))
        }
    }

    /// Toggles a break line along the straight line from `start` to `end`,
    /// which must differ in exactly one coordinate.
    public mutating func cut(from start: GridPoint, to end: GridPoint) {
        precondition(start != end && (start.x == end.x || start.y == end.y))
        let line: BreakLine = start.x == end.x ? .v : .h
        addEdge(
            line, x: min(start.x, end.x), y: min(start.y, end.y),
            length: abs(end.x - start.x + end.y - start.y))
    }

    /// What a tap does: on a segment, cycles it through horizontal, vertical
    /// and no break line; in the middle of a cell, empties or refills it.
    public mutating func toggle(x: Int, y: Int) {
        guard contains(GridPoint(x: x, y: y)) else { return }
        guard (x + y) % 2 == 1 else {
            if x % 2 == 1 && y % 2 == 1 { empty[y / 2][x / 2].toggle() }
            return
        }
        breaklines[y][x / 2] =
            switch breaklines[y][x / 2] {
            case .h: .v
            case .v: .o
            case .o: .h
            }
    }

    private mutating func toggle(_ line: BreakLine, x: Int, y: Int) {
        let current = breaklines[y][x / 2]
        breaklines[y][x / 2] =
            switch (line, current) {
            case (.h, .h), (.v, .v): .o
            case (.h, _): .h
            case (.v, _): .v
            case (.o, _): current
            }
    }
}
