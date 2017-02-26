//: [Previous](@previous)

import Foundation
import UIKit

// This implementation is very heavily based on Chaz Boston Baden's page
//    http://www.boston-baden.com/hazel/Knotware3/
// (so much so that I added his tile gifs directly to the project).
// Used with permission.

struct Grid {
    let width: Int
    let height: Int
}

let g = Grid(width: 5, height: 4)

enum BaseTile {
    case l, w, u, i
}

enum Tile: String {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z, empty = "@"

    var image: UIImage {
        return UIImage(imageLiteralResourceName: "\(self.rawValue).gif")
    }
}

let aGrid: [[Tile]] = [
    [.n, .v, .o, .x, .n, .t, .p, .x, .n, .v, .o, .x],
    [.b, .i, .u, .f, .c, .l, .w, .e, .b, .i, .z, .d],
    [.k, .w, .l, .y, .h, .u, .i, .z, .k, .w, .e, .d],
    [.b, .i, .u, .f, .c, .l, .w, .e, .b, .i, .u, .f],
    [.k, .w, .l, .y, .h, .u, .i, .z, .k, .r, .m, .y],
    [.a, .j, .s, .g, .a, .m, .r, .g, .a, .q, .q, .g]
]

func draw(_ grid: [[Tile]]) -> UIImage {
    let rows = grid.count
    let cols = grid.first!.count
    let size = CGSize(width: cols * 20, height: rows * 20)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer { UIGraphicsEndImageContext() }
    for (y, row) in grid.enumerated() {
        for (x, cell) in row.enumerated() {
            let rect = CGRect(x: x * 20, y: y * 20, width: 20, height: 20)
            cell.image.draw(in: rect)
        }
    }
    return UIGraphicsGetImageFromCurrentImageContext()!
}

draw(aGrid)

func base(x: Int, y: Int, inverted: Bool) -> BaseTile {
    let evenX = x % 2 == 0
    let evenY = y % 2 == 0
    if inverted {
        if evenY {
            return evenX ? .i : .u
        } else {
            return evenX ? .w : .l
        }
    } else {
        if evenY {
            return evenX ? .l : .w
        } else {
            return evenX ? .u : .i
        }
    }
}


enum BreakLine {
    case h, v, o
}

let antigrid: [[BreakLine]] = [
    [.h, .h, .h, .h],
    [.v, .o, .h, .o, .v],
    [.o, .o, .o, .o],
    [.v, .v, .v, .v, .v],
    [.o, .o, .o, .o],
    [.v, .o, .h, .o, .v],
    [.h, .h, .h, .h],
]

func lookup(_ cell: BaseTile, with edges: Set<Edge>) -> Tile {
    switch edges {
    case [.n, .w]: return .n
    case [.n, .e]: return .x
    case [.s, .w]: return .a
    case [.s, .e]: return .g
    case [.n, .s]: return .q
    case [.w, .e]: return .d
    case [.n]:
        switch cell {
        case .l: return .o
        case .w: return .v
        case .i: return .p
        case .u: return .t
        }
    case [.s]:
        switch cell {
        case .u: return .s
        case .i: return .j
        case .w: return .r
        case .l: return .m
        }
    case [.w]:
        switch cell {
        case .l: return .k
        case .w: return .c
        case .u: return .b
        case .i: return .h
        }
    case [.e]:
        switch cell {
        case .l: return .e
        case .w: return .y
        case .u: return .z
        case .i: return .f
        }
    case []:
        switch cell {
        case .u: return .u
        case .i: return .i
        case .l: return .l
        case .w: return .w
        }
    default: return .empty
    }
}

struct AntiGrid {
    fileprivate var breaklines: [[BreakLine]]
    private var rows: Int
    private var cols: Int
    public init(rows: Int, cols: Int) {
        precondition(rows > 0)
        precondition(cols > 0)
        var breaklines = [[BreakLine]]()
        for _ in 0..<rows {
            breaklines.append([BreakLine](repeating: .o, count: cols))
            breaklines.append([BreakLine](repeating: .o, count: cols + 1))
        }
        breaklines.append([BreakLine](repeating: .o, count: cols * 2))
        self.breaklines = breaklines
        self.rows = rows
        self.cols = cols
    }
    
    private func edges(x: Int, y: Int) -> Set<Edge> {
        let odd = y % 2 == 1
        let above = breaklines[y][(x + (odd ? 1 : 0)) / 2]
        let below = breaklines[y+1][(x + (odd ? 0 : 1)) / 2]
        var edges = Set<Edge>()
        switch above {
        case .h:
            edges.insert(.n)
        case .v:
            edges.insert((x + y) % 2 == 0 ? .e : .w)
        case .o:
            break
        }
        switch below {
        case .h:
            edges.insert(.s)
        case .v:
            edges.insert((x + y) % 2 == 0 ? .w : .e)
        case .o:
            break
        }
        return edges
    }

    public func grid(inverted: Bool = false) -> [[Tile]] {
        return (0..<rows * 2).map { y in
            (0..<cols * 2).map { x in lookup(base(x: x, y: y, inverted: inverted), with: edges(x: x, y: y)) }
        }
    }
    
    public mutating func addBorders() {
        addEdge(.h, x: 0, y: 0, length: cols * 2)
        addEdge(.h, x: 0, y: rows * 2, length: cols * 2)
        addEdge(.v, x: 0, y: 0, length: rows * 2)
        addEdge(.v, x: cols * 2, y: 0, length: rows * 2)
    }
    
    public mutating func addEdge(_ line: BreakLine, x: Int, y: Int) {
        guard (0...cols * 2).contains(x), (0...rows * 2).contains(y) else { return }
        guard (x + y) % 2 == 1 else { return }
        breaklines[y][x / 2] = line
    }

    public mutating func addEdge(_ line: BreakLine, x: Int, y: Int, length: Int) {
        guard length > 0 else { return }
        for i in 0..<length {
            addEdge(line, x: x + (line == .h ? i : 0), y: y + (line == .v ? i : 0))
        }
    }
}

enum Edge {
    case n, s, w, e
}

var grid = AntiGrid(rows: 4, cols: 6)
grid.addBorders()
grid.addEdge(.h, x: 1, y: 1, length: 10)
grid.addEdge(.h, x: 1, y: 7, length: 10)
grid.addEdge(.v, x: 1, y: 1, length: 6)
grid.addEdge(.v, x: 11, y: 1, length: 6)
draw(grid.grid(inverted: false))

//: [Next](@next)
