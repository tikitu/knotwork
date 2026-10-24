/// What a drag across the knot does.
public enum DragMode: String, CaseIterable, Decodable, Identifiable, Sendable {
    /// A drag along a row or column cuts there, and a tap changes a point.
    case cut
    /// A drag spans a rectangle, snapped to cell corners, whose cells are
    /// emptied.
    case clear

    public var id: Self { self }

    public var name: String {
        switch self {
        case .cut: "Cut"
        case .clear: "Clear rectangle"
        }
    }
}
