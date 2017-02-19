//: [Previous](@previous)

import Foundation
import UIKit

struct Grid {
    let width: Int
    let height: Int
}

let g = Grid(width: 5, height: 4)

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

var grid: [[Tile]] = [
    [.l, .w, .l, .w, .l, .w, .l, .w],
    [.u, .i, .u, .i, .u, .i, .u, .i],
    [.l, .w, .l, .w, .l, .w, .l, .w],
    [.u, .i, .u, .i, .u, .i, .u, .i],
    [.l, .w, .l, .w, .l, .w, .l, .w],
    [.u, .i, .u, .i, .u, .i, .u, .i],
]

let base = grid

draw(grid)

func topBottom(cell: Tile) -> Tile {
    switch cell {
    case .l: return .o
    case .w: return .v
    case .u: return .s
    case .i: return .j
    default:
        return cell
    }
}

grid[0] = grid.first!.map(topBottom)
grid[grid.count - 1] = grid.last!.map(topBottom)

draw(grid)

func leftRight(_ cell: Tile) -> Tile {
    switch cell {
    case .l: return .k
    case .u: return .b
    case .w: return .y
    case .i: return .f
    default:
        return cell
    }
}

func leftRight(row: [Tile]) -> [Tile] {
    var row = row
    row[0] = leftRight(row[0])
    row[row.count - 1] = leftRight(row.last!)
    return row
}

grid = grid.map(leftRight)

draw(grid)

grid[0][0] = .n
grid[0][grid[0].count - 1] = .x
grid[grid.count - 1][0] = .a
grid[grid.count - 1][grid[0].count - 1] = .g

draw(grid)

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

enum Edge {
    case n, s, w, e
}

func edges(x: Int, y: Int) -> Set<Edge> {
    let odd = y % 2 == 1
    let above = antigrid[y][(x + (odd ? 1 : 0)) / 2]
    let below = antigrid[y+1][(x + (odd ? 0 : 1)) / 2]
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

edges(x: 7, y: 5)

func lookup(_ cell: Tile, with edges: Set<Edge>) -> Tile {
    switch edges {
    case []: return cell
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
        default:
            fatalError()
        }
    case [.s]:
        switch cell {
        case .u: return .s
        case .i: return .j
        case .w: return .r
        case .l: return .m
        default:
            fatalError()
        }
    case [.w]:
        switch cell {
        case .l: return .k
        case .w: return .c
        case .u: return .b
        case .i: return .h
        default:
            fatalError()
        }
    case [.e]:
        switch cell {
        case .l: return .e
        case .w: return .y
        case .u: return .z
        case .i: return .f
        default:
            fatalError()
        }
    default: return .empty
    }
}

var newGrid: [[Tile]] = []
for (y, row) in base.enumerated() {
    var newRow = [Tile]()
    for (x, cell) in row.enumerated() {
        let newCell = lookup(cell, with: edges(x: x, y: y))
        newRow.append(newCell)
    }
    newGrid.append(newRow)
}

draw(newGrid)

//: [Next](@next)
