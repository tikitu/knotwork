import CommandInbox
import Core
import Foundation

extension GridPoint: Decodable {
    /// A point is `[x, y]`.
    public init(from decoder: any Decoder) throws {
        var pair = try decoder.unkeyedContainer()
        let x = try pair.decode(Int.self)
        let y = try pair.decode(Int.self)
        guard pair.isAtEnd else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "a point is [x, y]"))
        }
        self.init(x: x, y: y)
    }
}

/// How a command file's commands decode. The format is documented, with
/// examples, in `docs/commands.md`; `CommandFileTests` decodes those examples
/// verbatim, so the document and the decoder cannot drift apart. The file
/// around them, the runner and the strict check of names and fields (an
/// unknown command or field is an error, so a typo in a script cannot quietly
/// do nothing) are app-utils' `CommandInbox` (app-tooling's command-inbox
/// pattern).
extension AppCommand: InboxCommand {
    private enum Name: String, CommandName {
        case newGrid, toggle, cut, setTiles, setPointedCorners, showSettings

        var fields: Set<String> {
            switch self {
            case .newGrid: ["rows", "cols"]
            case .toggle: ["at"]
            case .cut: ["from", "to"]
            case .setTiles: ["style"]
            case .setPointedCorners: ["on"]
            case .showSettings: ["shown"]
            }
        }
    }

    private enum Field: String, CodingKey { case rows, cols, at, from, to, style, on, shown }

    public init(from decoder: any Decoder) throws {
        let command = try StrictCommand<Name>(from: decoder)
        let fields = try command.fields(keyedBy: Field.self)
        func point(_ field: Field) throws -> GridPoint {
            try fields.decode(GridPoint.self, forKey: field)
        }
        switch command.name {
        case .newGrid:
            self = .newGrid(
                rows: try fields.decode(Int.self, forKey: .rows),
                cols: try fields.decode(Int.self, forKey: .cols))
        case .toggle: self = .toggle(try point(.at))
        case .cut: self = .cut(from: try point(.from), to: try point(.to))
        case .setTiles: self = .setTiles(try fields.decode(TileStyle.self, forKey: .style))
        case .setPointedCorners:
            self = .setPointedCorners(try fields.decode(Bool.self, forKey: .on))
        case .showSettings: self = .showSettings(try fields.decode(Bool.self, forKey: .shown))
        }
    }
}
