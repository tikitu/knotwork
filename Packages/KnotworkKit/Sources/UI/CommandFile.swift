import Core
import Foundation

/// The JSON a command inbox holds. The format is documented, with examples,
/// in `docs/commands.md`; `CommandFileTests` decodes those examples verbatim,
/// so the document and the decoder cannot drift apart.
///
/// Strict on purpose: an unknown command or an unknown field is an error, not
/// something ignored, so a typo in a script cannot quietly do nothing.
struct CommandFile: Decodable, Equatable {
    /// Echoed into the result, so a sender can match result to request.
    var id: String?
    var commands: [AppCommand]
}

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

extension AppCommand: Decodable {
    private enum Name: String, CodingKey, CaseIterable {
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
        let commands = try decoder.container(keyedBy: AnyKey.self)
        guard commands.allKeys.count == 1, let key = commands.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "a command is an object with exactly one key, its name"))
        }
        guard let name = Name(stringValue: key.stringValue) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: commands.codingPath + [key],
                    debugDescription: "unknown command '\(key.stringValue)'; known: "
                        + Name.allCases.map(\.rawValue).sorted().joined(separator: ", ")))
        }
        let unknown = try commands.nestedContainer(keyedBy: AnyKey.self, forKey: key).allKeys.map(
            \.stringValue
        ).filter { !name.fields.contains($0) }
        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: commands.codingPath + [key],
                    debugDescription:
                        "unknown field(s) \(unknown.sorted()) for \(name.rawValue); allowed: "
                        + name.fields.sorted().joined(separator: ", ")))
        }

        let fields = try commands.nestedContainer(keyedBy: Field.self, forKey: key)
        func point(_ field: Field) throws -> GridPoint {
            try fields.decode(GridPoint.self, forKey: field)
        }
        switch name {
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

/// A coding key for whatever keys an object has, so the decoder can check
/// them against what it expects.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    // Declared, not memberwise: CodingKey needs it, and a synthesized
    // memberwise initializer does not satisfy a protocol requirement.
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
