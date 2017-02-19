//: [Previous](@previous)

import Foundation
import UIKit

struct Grid {
    let width: Int
    let height: Int
}

let g = Grid(width: 5, height: 4)

enum Tile: String {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z

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

//: [Next](@next)
