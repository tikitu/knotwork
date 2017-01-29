//: Playground - noun: a place where people can play

import UIKit

struct Images {
    static let cross = UIImage(named: "cross")!
    static let splitV = UIImage(named: "split-vert")!
    static let splitH = UIImage(named: "split-hori")!
    static let northWest = UIImage(named: "north-west")!
    static let north = UIImage(named: "north")!
    static let northEast = UIImage(named: "north-east")!
    static let east = UIImage(named: "east")!
    static let southEast = UIImage(named: "south-east")!
    static let south = UIImage(named: "south")!
    static let southWest = UIImage(named: "south-west")!
    static let west = UIImage(named: "west")!
}

enum GridPoint {
    case cross, splitV, splitH
}

struct Grid {
    var points: [GridPoint]
    let rows: Int
    let cols: Int
    
    init(rows: Int, cols: Int) {
        precondition(rows > 0, "Rows must be positive")
        precondition(cols >= 0, "Cols must be non-negative")
        self.rows = rows
        self.cols = cols
        self.points = Array(repeating: GridPoint.cross, count: rows * cols)
    }
}

func draw(_ grid: Grid) -> UIImage {
    let size = CGSize(width: grid.cols * 40 + 100, height: grid.rows * 40 + 100)
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer { UIGraphicsEndImageContext() }
    for row in (0..<grid.rows) {
        for col in (0..<grid.cols) {
            let point = grid.points[row * grid.cols + col]
            let cell: UIImage
            switch point {
            case .cross:
                cell = Images.cross
            case .splitV:
                cell = Images.splitV
            case .splitH:
                cell = Images.splitH
            }
            let rect = CGRect(x: col * 40 + 50, y: row * 40 + 50, width: 40, height: 40)
            cell.draw(in: rect)
        }
    }
    Images.northWest.draw(in: CGRect(x: 0, y: 20 - 1, width: 50, height: 50))
    Images.northEast.draw(in: CGRect(x: size.width - 50, y: 20 - 1, width: 50, height: 50))
    Images.southWest.draw(in: CGRect(x: 0, y: size.height - 75, width: 50, height: 50))
    Images.southEast.draw(in: CGRect(x: size.width - 50, y: size.height - 75, width: 50, height: 50))
    for row in (1..<grid.rows) {
        Images.west.draw(in: CGRect(x: 2, y: row * 40 + 25, width: 50, height: 40))
        Images.east.draw(in: CGRect(x: size.width - 50, y: CGFloat(row) * 40 + 25 + 2, width: 50, height: 40))
    }
    for col in (0..<grid.cols) {
        Images.north.draw(in: CGRect(x: col * 40 + 50, y: 0, width: 40, height: 50))
        Images.south.draw(in: CGRect(x: CGFloat(col) * 40 + 50, y: size.height - 50, width: 40, height: 50))
    }
    return UIGraphicsGetImageFromCurrentImageContext()!
}

draw(Grid(rows: 3, cols: 3))

extension Grid {
    mutating func randomize() {
        for i in 0..<points.count {
            let new: GridPoint
            switch arc4random_uniform(3) {
            case 0:
                new = .cross
            case 1:
                new = .splitH
            case 3:
                new = .splitV
            default:
                new = .cross
            }
            points[i] = new
        }
    }
}

var grid = Grid(rows: 10, cols: 0)
grid.randomize()
draw(grid)
