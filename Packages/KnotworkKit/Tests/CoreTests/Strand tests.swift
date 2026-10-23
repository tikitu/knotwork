import Core
import Testing

struct StrandTests {
    @Test
    func `every tile but the empty one has a strand`() {
        for tile in Tile.allCases { #expect((tile.strand == nil) == (tile == .empty), "\(tile)") }
    }

    /// Read off Boston-Baden's images: which edges the band crosses, and at
    /// which corner it is cut short by a gap.
    @Test(arguments: [
        (Tile.l, Strand(from: .corner(.sw, isOver: true), to: .corner(.ne, isOver: false))),
        (.u, Strand(from: .corner(.nw, isOver: false), to: .corner(.se, isOver: true))),
        (.o, Strand(from: .corner(.sw, isOver: true), to: .middle(.e))),
        (.k, Strand(from: .middle(.s), to: .corner(.ne, isOver: false))),
        (.v, Strand(from: .middle(.w), to: .corner(.se, isOver: false))),
        (.z, Strand(from: .corner(.nw, isOver: false), to: .middle(.s))),
        (.n, Strand(from: .middle(.s), to: .middle(.e))),
        (.a, Strand(from: .middle(.n), to: .middle(.e))),
        (.x, Strand(from: .middle(.w), to: .middle(.s))),
        (.g, Strand(from: .middle(.n), to: .middle(.w))),
        (.q, Strand(from: .middle(.w), to: .middle(.e))),
        (.d, Strand(from: .middle(.s), to: .middle(.n))),
    ])
    func `strands match the original images`(tile: Tile, strand: Strand) {
        let ends = tile.strand.map { Set([$0.start, $0.end]) }
        #expect(ends == [strand.start, strand.end])
    }
}
