import CoreGraphics

/// A path flattened into closely spaced points, for drawing that varies along
/// its length: a hand-drawn line's wobble, or its changing weight.
struct Polyline {
    var points: [CGPoint]
    /// The distance along the line to each point.
    var distances: [CGFloat]

    var length: CGFloat { distances.last ?? 0 }

    /// `path` flattened, with straight runs divided so that no two points are
    /// more than `spacing` apart.
    init(_ path: CGPath, spacing: CGFloat) {
        var points: [CGPoint] = []
        func addLine(to end: CGPoint) {
            guard let start = points.last else { return points.append(end) }
            let steps = max(1, Int(((end - start).length / spacing).rounded(.up)))
            for step in 1...steps {
                points.append(start + (end - start) * (CGFloat(step) / CGFloat(steps)))
            }
        }
        func addCurve(_ c1: CGPoint, _ c2: CGPoint, _ end: CGPoint) {
            guard let start = points.last else { return points.append(end) }
            let estimate = (c1 - start).length + (c2 - c1).length + (end - c2).length
            let steps = max(2, Int((estimate / spacing).rounded(.up)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let u = 1 - t
                let a = u * u * u
                let b = 3 * u * u * t
                let c = 3 * u * t * t
                let d = t * t * t
                points.append(
                    CGPoint(
                        x: a * start.x + b * c1.x + c * c2.x + d * end.x,
                        y: a * start.y + b * c1.y + c * c2.y + d * end.y))
            }
        }
        path.applyWithBlock { element in
            let p = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: points.append(p[0])
            case .addLineToPoint: addLine(to: p[0])
            case .addQuadCurveToPoint:
                if let start = points.last {
                    addCurve(start + (p[0] - start) * (2 / 3), p[1] + (p[0] - p[1]) * (2 / 3), p[1])
                }
            case .addCurveToPoint: addCurve(p[0], p[1], p[2])
            case .closeSubpath: if let first = points.first { addLine(to: first) }
            @unknown default: break
            }
        }
        self.init(points: points)
    }

    init(points: [CGPoint]) {
        // Without points that all but repeat the one before: a segment of
        // next to no length has no reliable direction, and stroked, it
        // shows as a hairline across the line.
        let points = points.reduce(into: [CGPoint]()) { kept, point in
            if let last = kept.last, (point - last).length < 1e-4 { return }
            kept.append(point)
        }
        var distances: [CGFloat] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            distances.append(distances[distances.count - 1] + (b - a).length)
        }
        self.points = points
        self.distances = distances
    }

    /// The unit normal at point `i`, a quarter turn clockwise from the
    /// direction of travel.
    func normal(at i: Int) -> CGVector {
        let before = points[max(0, i - 1)]
        let after = points[min(points.count - 1, i + 1)]
        return (after - before).normalized.perpendicular
    }

    /// The line moved sideways at every point, by `offset(i)` along its normal.
    func offset(by offset: (Int) -> CGFloat) -> [CGPoint] {
        points.indices.map { points[$0] + normal(at: $0) * offset($0) }
    }

    /// The points, without those that lie within `tolerance` of the line
    /// through their neighbours (Douglas–Peucker).
    func simplified(tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var spans = [(0, points.count - 1)]
        while let (first, last) = spans.popLast() {
            guard last > first + 1 else { continue }
            let chord = points[last] - points[first]
            let length = max(chord.length, 1e-12)
            var farthest = first
            var distance: CGFloat = 0
            for i in (first + 1)..<last {
                let r = points[i] - points[first]
                let d = abs(chord.dx * r.dy - chord.dy * r.dx) / length
                if d > distance {
                    distance = d
                    farthest = i
                }
            }
            guard distance > tolerance else { continue }
            keep[farthest] = true
            spans.append((first, farthest))
            spans.append((farthest, last))
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }
}
