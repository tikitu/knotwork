// What each tile shows, as geometry rather than as Boston-Baden's pixels, so
// that a tileset can draw it in any style.
//
// The knot's strands run diagonally through the tiles and cross at tile
// corners, on alternate corners in a checkerboard: every tile's strand runs
// between two crossing corners, passing over the other strand at one of them
// and under it at the other. A break line runs through a crossing corner and
// stops the crossing there; a strand that would have reached that corner
// turns instead, and leaves through the middle of the tile's other edge at
// that corner, square to it and running alongside the break.

/// A corner of a tile.
public enum Corner: CaseIterable, Sendable {
    case nw, ne, sw, se

    /// The two edges that meet here.
    public var edges: Set<Edge> {
        switch self {
        case .nw: [.n, .w]
        case .ne: [.n, .e]
        case .sw: [.s, .w]
        case .se: [.s, .e]
        }
    }
}

/// Where a strand leaves its tile.
public enum Port: Hashable, Sendable {
    /// Through a corner, diagonally, crossing another strand there: over
    /// it, or under it.
    case corner(Corner, isOver: Bool)
    /// Through the middle of an edge, square to it, beside a break line.
    case middle(Edge)
}

/// The piece of strand a tile shows: from one port to the other.
public struct Strand: Hashable, Sendable {
    public var start: Port
    public var end: Port

    public init(from start: Port, to end: Port) {
        self.start = start
        self.end = end
    }
}

extension BaseTile {
    /// The two crossing corners its strand runs between, and whether it
    /// passes over the other strand at each.
    var crossings: [(corner: Corner, isOver: Bool)] {
        switch self {
        case .l: [(.sw, true), (.ne, false)]
        case .i: [(.ne, true), (.sw, false)]
        case .u: [(.nw, false), (.se, true)]
        case .w: [(.nw, true), (.se, false)]
        }
    }

    /// Its strand with break lines along `edges`, or `nil` if two of them
    /// stop the same crossing (which no tile shows).
    func strand(edges: Set<Edge>) -> Strand? {
        let ports = crossings.map { crossing -> Port? in
            let broken = crossing.corner.edges.intersection(edges)
            switch broken.count {
            case 0: return .corner(crossing.corner, isOver: crossing.isOver)
            case 1: return crossing.corner.edges.subtracting(broken).first.map(Port.middle)
            default: return nil
            }
        }
        guard let start = ports[0], let end = ports[1],
            edges.count
                == [start, end].count(where: { if case .middle = $0 { true } else { false } })
        else { return nil }
        return Strand(from: start, to: end)
    }
}

extension Tile {
    /// The strand this tile shows, or `nil` for the empty tile.
    public var strand: Strand? { Self.strands[self] }

    /// Worked out from the rule above rather than written out by hand: for
    /// every base tile and set of break lines, the strand it gives, under
    /// the tile `init(base:edges:)` names for them.
    private static let strands: [Tile: Strand] = {
        let edgeSets: [Set<Edge>] =
            [[]] + Edge.allCases.map { [$0] }
            + Edge.allCases.flatMap { a in
                Edge.allCases.map { b in [a, b] }.filter { $0.count == 2 }
            }
        var strands: [Tile: Strand] = [:]
        for base in BaseTile.allCases {
            for edges in edgeSets {
                guard let strand = base.strand(edges: edges) else { continue }
                strands[Tile(base: base, edges: edges)] = strand
            }
        }
        return strands
    }()
}
