import Core
import Foundation
import Testing

@testable import UI

struct CommandFileTests {
    /// Every JSON block in `docs/commands.md` that holds `"commands"`, which
    /// are the request examples. Read from the document itself, so the
    /// document cannot drift from the decoder.
    static let documentedRequests: [String] = {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(
            path: "../../../../docs/commands.md")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return text.components(separatedBy: "```json\n").dropFirst().compactMap { block in
            let json = block.components(separatedBy: "```").first ?? ""
            return json.contains("\"commands\"") ? json : nil
        }
    }()

    @Test
    func `the document has request examples`() { #expect(Self.documentedRequests.count == 3) }

    @Test(arguments: documentedRequests)
    func `every documented request decodes`(json: String) throws {
        _ = try JSONDecoder().decode(CommandFile.self, from: Data(json.utf8))
    }

    @Test
    func `the first example decodes to what it says`() throws {
        let file = try JSONDecoder().decode(
            CommandFile.self, from: Data(Self.documentedRequests[0].utf8))
        #expect(file.id == "optional, echoed back into the result")
        #expect(
            file.commands == [
                .newGrid(rows: 4, cols: 6),
                .cut(from: GridPoint(x: 2, y: 0), to: GridPoint(x: 2, y: 8)),
                .toggle(GridPoint(x: 3, y: 3)),
            ])
    }

    @Test
    func `the appearance example decodes to what it says`() throws {
        let file = try JSONDecoder().decode(
            CommandFile.self, from: Data(Self.documentedRequests[2].utf8))
        #expect(
            file.commands == [.showSettings(true), .setTiles(.sketch), .setPointedCorners(false)])
    }

    @Test(arguments: [
        #"{"commands":[{"setTiles":{"style":"fancy"}}]}"#,
        #"{"commands":[{"togle":{"at":[1,0]}}]}"#, #"{"commands":[{"toggle":{"point":[1,0]}}]}"#,
        #"{"commands":[{"toggle":{"at":[1,0,2]}}]}"#,
        #"{"commands":[{"toggle":{"at":[1,0]},"newGrid":{"rows":1,"cols":1}}]}"#,
    ])
    func `typos are errors, not silently ignored`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(CommandFile.self, from: Data(json.utf8))
        }
    }
}
