import Core
import Testing

struct AntiGridTests {
    @Test
    func `a bordered single cell is a closed loop`() {
        var grid = AntiGrid(rows: 1, cols: 1)
        grid.addBorders()
        #expect(grid.tiles() == [[.n, .x], [.a, .g]])
    }

    @Test
    func `a bordered knot has the loop's corners and no empty tiles`() {
        var grid = AntiGrid(rows: 3, cols: 4)
        grid.addBorders()
        let tiles = grid.tiles()
        #expect(tiles.count == 6)
        #expect(tiles.allSatisfy { $0.count == 8 })
        #expect([tiles[0][0], tiles[0][7], tiles[5][0], tiles[5][7]] == [.n, .x, .a, .g])
        #expect(!tiles.joined().contains(.empty))
    }

    @Test
    func `cutting the same line twice undoes it`() {
        var grid = AntiGrid(rows: 3, cols: 4)
        grid.addBorders()
        let bordered = grid
        grid.cut(from: GridPoint(x: 2, y: 0), to: GridPoint(x: 2, y: 6))
        #expect(grid != bordered)
        grid.cut(from: GridPoint(x: 2, y: 6), to: GridPoint(x: 2, y: 0))
        #expect(grid == bordered)
    }

    @Test
    func `a cut along a row draws horizontal break lines`() {
        var cut = AntiGrid(rows: 2, cols: 2)
        cut.cut(from: GridPoint(x: 0, y: 2), to: GridPoint(x: 4, y: 2))
        var byHand = AntiGrid(rows: 2, cols: 2)
        byHand.addEdge(.h, x: 0, y: 2, length: 4)
        #expect(cut == byHand)
    }

    @Test
    func `tapping a segment three times brings it back`() {
        var grid = AntiGrid(rows: 2, cols: 2)
        grid.addBorders()
        let start = grid
        grid.toggle(x: 1, y: 2)
        let once = grid
        grid.toggle(x: 1, y: 2)
        #expect(grid != once)
        grid.toggle(x: 1, y: 2)
        #expect(grid == start)
    }

    @Test
    func `tapping a cell's centre empties it, and again refills it`() {
        var grid = AntiGrid(rows: 2, cols: 2)
        grid.addBorders()
        let start = grid
        grid.toggle(x: 1, y: 1)
        #expect(grid.tiles()[0][0] == .empty)
        grid.toggle(x: 1, y: 1)
        #expect(grid == start)
    }

    @Test
    func `points off the grid do nothing`() {
        var grid = AntiGrid(rows: 2, cols: 2)
        let start = grid
        grid.toggle(x: 5, y: 0)
        grid.toggle(x: -1, y: 0)
        #expect(grid == start)
        #expect(!grid.contains(GridPoint(x: 0, y: 5)))
        #expect(grid.contains(GridPoint(x: 4, y: 4)))
    }
}
