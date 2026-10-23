// This implementation is very heavily based on Chaz Boston Baden's page
//    http://www.boston-baden.com/hazel/Knotware3/
// (so much so that his tile gifs are in the UI target's resources).
// Used with permission.

/// One of the four tiles a cell shows when no break line touches it. Which
/// one depends only on the cell's position: they alternate in a checkerboard.
public enum BaseTile: Sendable {
    case l, w, u, i

    /// The base tile at column `x`, row `y` of the tile grid.
    public static func at(x: Int, y: Int, inverted: Bool) -> BaseTile {
        let evenX = x % 2 == 0
        let evenY = y % 2 == 0
        if inverted {
            if evenY { return evenX ? .i : .u }
            return evenX ? .w : .l
        }
        if evenY { return evenX ? .l : .w }
        return evenX ? .u : .i
    }
}

/// A side of a tile, cut by a break line.
public enum Edge: Sendable { case n, s, w, e }

/// One of Boston-Baden's tiles. The raw value names its image.
public enum Tile: String, CaseIterable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case empty = "@"

    /// The tile for a cell whose base tile is `base`, with break lines along
    /// `edges`.
    public init(base: BaseTile, edges: Set<Edge>) {
        self =
            switch edges {
            case [.n, .w]: .n
            case [.n, .e]: .x
            case [.s, .w]: .a
            case [.s, .e]: .g
            case [.n, .s]: .q
            case [.w, .e]: .d
            case [.n]:
                switch base {
                case .l: .o
                case .w: .v
                case .i: .p
                case .u: .t
                }
            case [.s]:
                switch base {
                case .u: .s
                case .i: .j
                case .w: .r
                case .l: .m
                }
            case [.w]:
                switch base {
                case .l: .k
                case .w: .c
                case .u: .b
                case .i: .h
                }
            case [.e]:
                switch base {
                case .l: .e
                case .w: .y
                case .u: .z
                case .i: .f
                }
            case []:
                switch base {
                case .u: .u
                case .i: .i
                case .l: .l
                case .w: .w
                }
            default: .empty
            }
    }
}
