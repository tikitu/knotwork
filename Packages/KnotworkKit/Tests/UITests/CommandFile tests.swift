import CommandInbox
import Core
import Foundation
import Testing

@testable import UI

struct CommandFileTests {
    /// The request examples in `docs/commands.md`: every JSON block that
    /// holds `"commands"`. Read from the document itself, so the document
    /// cannot drift from the decoder.
    static let documentedRequests = CommandDocumentation.requests(
        inFileAt: URL(filePath: #filePath).deletingLastPathComponent().appending(
            path: "../../../../docs/commands.md"))

    @Test
    func `the document has request examples`() { #expect(Self.documentedRequests.count == 3) }

    @Test(arguments: documentedRequests)
    func `every documented request decodes`(json: String) throws {
        _ = try JSONDecoder().decode(CommandFile<AppCommand>.self, from: Data(json.utf8))
    }

    @Test
    func `the first example decodes to what it says`() throws {
        let file = try JSONDecoder().decode(
            CommandFile<AppCommand>.self, from: Data(Self.documentedRequests[0].utf8))
        #expect(file.id == "optional, echoed back into the result")
        #expect(
            file.commands == [
                .command(.newGrid(rows: 4, cols: 6)),
                .command(.cut(from: GridPoint(x: 2, y: 0), to: GridPoint(x: 2, y: 8))),
                .command(.toggle(GridPoint(x: 3, y: 3))),
            ])
    }

    @Test
    func `the appearance example decodes to what it says`() throws {
        let file = try JSONDecoder().decode(
            CommandFile<AppCommand>.self, from: Data(Self.documentedRequests[2].utf8))
        #expect(
            file.commands == [
                .command(.showSettings(true)), .command(.setTiles(.sketch)),
                .command(.setPointedCorners(false)),
            ])
    }

    @Test(arguments: [
        #"{"commands":[{"setTiles":{"style":"fancy"}}]}"#,
        #"{"commands":[{"togle":{"at":[1,0]}}]}"#, #"{"commands":[{"toggle":{"point":[1,0]}}]}"#,
        #"{"commands":[{"toggle":{"at":[1,0,2]}}]}"#,
        #"{"commands":[{"toggle":{"at":[1,0]},"newGrid":{"rows":1,"cols":1}}]}"#,
    ])
    func `typos are errors, not silently ignored`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CommandFile<AppCommand>.self, from: Data(json.utf8))
        }
    }
}
