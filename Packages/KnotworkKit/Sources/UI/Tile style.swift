import Tilesets

/// How the knot's tiles are drawn: Boston-Baden's images, or one of the
/// tilesets drawn in code.
public enum TileStyle: String, CaseIterable, Decodable, Identifiable, Sendable {
    case original, smooth, sketch

    public var id: Self { self }

    public var name: String {
        switch self {
        case .original: "Original"
        case .smooth: Tileset.smooth.name
        case .sketch: Tileset.sketch.name
        }
    }

    /// The tileset that draws this style, if it is drawn in code.
    var tileset: Tileset? {
        switch self {
        case .original: nil
        case .smooth: .smooth
        case .sketch: .sketch
        }
    }
}
