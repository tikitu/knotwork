import Core
import Foundation
import Testing

@testable import UI

@MainActor
struct ModelTests {
    private let model = AppModel()

    @Test
    func `there is no knot until one is asked for`() {
        #expect(model.grid == nil)
        #expect(throws: CommandError.noGrid) { try model.perform(.toggle(GridPoint(x: 1, y: 0))) }
    }

    @Test
    func `a new grid is bordered, and its tiles are ready to draw`() throws {
        try model.perform(.newGrid(rows: 1, cols: 1))
        #expect(model.tiles == [[.n, .x], [.a, .g]])
    }

    @Test(arguments: [(0, 3), (3, 0), (201, 3), (-1, -1)])
    func `a grid has to be a sensible size`(rows: Int, cols: Int) {
        #expect(throws: CommandError.gridSize(rows: rows, cols: cols)) {
            try model.perform(.newGrid(rows: rows, cols: cols))
        }
    }

    @Test
    func `a toggle changes the tiles`() throws {
        try model.perform(.newGrid(rows: 2, cols: 2))
        let before = model.tiles
        try model.perform(.toggle(GridPoint(x: 1, y: 1)))
        #expect(model.tiles != before)
        #expect(model.tiles[0][0] == .empty)
    }

    @Test
    func `a cut changes the tiles, and the same cut changes them back`() throws {
        try model.perform(.newGrid(rows: 2, cols: 2))
        let before = model.tiles
        let start = GridPoint(x: 0, y: 2)
        let end = GridPoint(x: 4, y: 2)
        try model.perform(.cut(from: start, to: end))
        #expect(model.tiles != before)
        try model.perform(.cut(from: end, to: start))
        #expect(model.tiles == before)
    }

    @Test
    func `cuts must be straight, go somewhere, and stay on the grid`() throws {
        try model.perform(.newGrid(rows: 2, cols: 2))
        let origin = GridPoint(x: 0, y: 0)
        let diagonal = GridPoint(x: 2, y: 2)
        let outside = GridPoint(x: 0, y: 5)
        #expect(throws: CommandError.notStraight(origin, diagonal)) {
            try model.perform(.cut(from: origin, to: diagonal))
        }
        #expect(throws: CommandError.notStraight(origin, origin)) {
            try model.perform(.cut(from: origin, to: origin))
        }
        #expect(throws: CommandError.offGrid(outside)) {
            try model.perform(.cut(from: origin, to: outside))
        }
        #expect(throws: CommandError.offGrid(outside)) { try model.perform(.toggle(outside)) }
    }

    @Test
    func `a control's failure is kept, not thrown`() {
        model.attempt(.toggle(GridPoint(x: 1, y: 0)))
        #expect(model.lastError == "there is no knot yet")
        model.attempt(.newGrid(rows: 1, cols: 1))
        #expect(model.lastError == nil)
    }

    @Test
    func `the inbox runs commands in order and stops at the first failure`() {
        let json = #"""
            {"id": "r1", "commands": [
              {"newGrid": {"rows": 2, "cols": 2}},
              {"cut": {"from": [0, 0], "to": [2, 2]}},
              {"toggle": {"at": [1, 1]}}
            ]}
            """#
        let result = CommandInbox.run(Data(json.utf8), on: model)
        #expect(result.requestID == "r1")
        #expect(result.completed.map(\.command) == ["newGrid"])
        #expect(
            result.error
                == "cut failed: a cut runs straight along a row or column; (0, 0) to (2, 2) does not"
        )
        #expect(model.tiles.joined().contains(.empty) == false)
    }

    @Test
    func `appearance settings start hidden, with smooth pointed tiles`() {
        #expect(!model.isShowingSettings)
        #expect(model.tileStyle == .smooth)
        #expect(model.hasPointedCorners)
    }

    @Test
    func `appearance commands change the appearance, with or without a knot`() throws {
        try model.perform(.showSettings(true))
        try model.perform(.setTiles(.original))
        try model.perform(.setPointedCorners(false))
        #expect(model.isShowingSettings)
        #expect(model.tileStyle == .original)
        #expect(!model.hasPointedCorners)
    }

    @Test
    func `the settings controls bind to change the appearance`() {
        model.tileStyleSetting = .sketch
        model.pointedCornersSetting = false
        #expect(model.tileStyle == .sketch)
        #expect(!model.hasPointedCorners)
    }
}
