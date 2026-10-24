import Core
import Testing

/// Every strand that leaves a tile must arrive in the next one: through an
/// edge's middle into the tile beside it, or through a crossing corner into
/// the tile diagonally across, at the same height (over or under).
struct ConnectionTests {
    @Test
    func `emptying a cell beside a break line leaves no loose ends`() {
        var grid = AntiGrid(rows: 3, cols: 3)
        grid.addBorders()
        grid.toggle(x: 2, y: 3)
        grid.toggle(x: 3, y: 3)
        #expect(looseEnds(grid.tiles()) == [])
    }

    @Test(arguments: 0..<200)
    func `random knots have no loose ends`(seed: UInt64) {
        var random = SplitMix(seed: seed)
        var grid = AntiGrid(rows: 4, cols: 5)
        grid.addBorders()
        for _ in 0..<Int(random.next() % 30) {
            let x = 1 + Int(random.next() % 9)
            let y = 1 + Int(random.next() % 7)
            grid.toggle(x: x, y: y)
        }
        #expect(looseEnds(grid.tiles()) == [], "seed \(seed)")
    }
}

/// The ports that lead nowhere, as "(x, y) port".
func looseEnds(_ tiles: [[Tile]]) -> [String] {
    func ports(_ x: Int, _ y: Int) -> Set<Port> {
        guard tiles.indices.contains(y), tiles[y].indices.contains(x),
            let strand = tiles[y][x].strand
        else { return [] }
        return [strand.start, strand.end]
    }
    var loose: [String] = []
    for y in tiles.indices {
        for x in tiles[y].indices {
            if tiles[y][x] == .empty { continue }
            guard tiles[y][x].strand != nil else {
                loose.append("(\(x), \(y)) \(tiles[y][x]) has no strand")
                continue
            }
            for port in ports(x, y) {
                let (dx, dy, partner): (Int, Int, Port) =
                    switch port {
                    case .middle(.n): (0, -1, .middle(.s))
                    case .middle(.s): (0, 1, .middle(.n))
                    case .middle(.w): (-1, 0, .middle(.e))
                    case .middle(.e): (1, 0, .middle(.w))
                    case .corner(.nw, let over): (-1, -1, .corner(.se, isOver: over))
                    case .corner(.ne, let over): (1, -1, .corner(.sw, isOver: over))
                    case .corner(.sw, let over): (-1, 1, .corner(.ne, isOver: over))
                    case .corner(.se, let over): (1, 1, .corner(.nw, isOver: over))
                    }
                if !ports(x + dx, y + dy).contains(partner) {
                    loose.append("(\(x), \(y)) \(tiles[y][x]) \(port)")
                }
            }
        }
    }
    return loose
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
