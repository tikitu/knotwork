//: [Previous](@previous)

import Foundation
import UIKit
import PlaygroundSupport

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
        toggle(line, x: x, y: y)
    }

    public mutating func addEdge(_ line: BreakLine, x: Int, y: Int, length: Int) {
        guard length > 0 else { return }
        for i in 0..<length {
            addEdge(line, x: x + (line == .h ? i : 0), y: y + (line == .v ? i : 0))
        }
    }
    
    public mutating func toggle(x: Int, y: Int) {
        guard (0...cols * 2).contains(x), (0...rows * 2).contains(y) else { return }
        guard (x + y) % 2 == 1 else { return }
        let current = breaklines[y][x / 2]
        let new: BreakLine
        switch current {
        case .h: new = .v
        case .v: new = .o
        case .o: new = .h
        }
        breaklines[y][x / 2] = new
    }
    
    private mutating func toggle(_ line: BreakLine, x: Int, y: Int) {
        let current = breaklines[y][x / 2]
        let new: BreakLine
        switch (line, current) {
        case (.h, .h), (.v, .v): new = .o
        case (.h, _): new = .h
        case (.v, _): new = .v
        /*case (.h, .h), (.v, .o): new = .v
        case (.h, .v), (.v, .h): new = .o
        case (.h, .o), (.v, .v): new = .h */
        default:
            new = current
        }
        breaklines[y][x / 2] = new
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

final class Canvas: UIImageView {
    var start: CGPoint? = nil
    var end: CGPoint? = nil
    
    var cut: ((CGPoint, CGPoint) -> ()) = {_,_ in }
    var toggle: (CGPoint) -> () = {_ in }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first?.location(in: self) else { return }
        start = CGPoint(x: round(touch.x / 20) * 20, y: round(touch.y / 20) * 20)
        end = start
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first?.location(in: self), let start = self.start else { return }
        
        let mid = CGPoint(x: round(touch.x / 20) * 20, y: round(touch.y / 20) * 20)
        let color: UIColor
        if (mid.x >= 0 && mid.x <= bounds.width) && (mid.y >= 0 && mid.y <= bounds.height) && (mid.x == start.x || mid.y == start.y) {
            end = mid
            color = .red
        } else {
            end = nil
            color = UIColor.red.withAlphaComponent(0.5)
        }
        
        UIGraphicsBeginImageContext(self.frame.size);
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.setLineCap(.round)
        ctx?.setLineWidth(5.0)
        ctx?.setStrokeColor(color.cgColor)
        ctx?.beginPath()
        ctx?.move(to: start)
        ctx?.addLine(to: mid)
        ctx?.strokePath()
        self.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            start = nil
            end = nil
        }
        guard let start = start,
            let end = end else {
            self.image = UIImage()
            return
        }
        if start == end {
            toggle(CGPoint(x: start.x / 20, y: start.y / 20))
        } else {
            cut(CGPoint(x: start.x / 20, y: start.y / 20), CGPoint(x: end.x / 20, y: end.y / 20))
        }
        image = UIImage()
    }
}

final class Controller: UIViewController {
    var grid: AntiGrid
    
    init(in size: CGSize) {
        let rows = Int(size.height) / 40
        let cols = Int(size.width) / 40
        grid = AntiGrid(rows: rows, cols: cols)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let knot = UIImageView()
    let canvas = Canvas()
    
    override func loadView() {
        knot.image = draw(grid.grid())
        
        canvas.cut = self.cut
        canvas.toggle = self.toggle
        canvas.isUserInteractionEnabled = true
        knot.isUserInteractionEnabled = true
        
        knot.addSubview(canvas)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        knot.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[c]|", options: [], metrics: nil, views: ["c": canvas]))
        knot.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[c]|", options: [], metrics: nil, views: ["c": canvas]))
        
        self.view = knot
    }
    
    func cut(from start: CGPoint, to end: CGPoint) {
        let direction: BreakLine = (start.x == end.x) ? .v : .h
        grid.addEdge(direction,
                     x: min(Int(start.x), Int(end.x)),
                     y: min(Int(start.y), Int(end.y)),
                     length: abs(Int(end.x) - Int(start.x) + Int(end.y) - Int(start.y)))
        knot.image = draw(grid.grid())
    }
    func toggle(point: CGPoint) {
        grid.toggle(x: Int(point.x), y: Int(point.y))
        knot.image = draw(grid.grid())
    }
}

private extension CGSize {
    static let iphone4 = CGSize(width: 320, height: 480)
    static let iphone5 = CGSize(width: 320, height: 568)
    static let iphone6 = CGSize(width: 375, height: 667)
    static let iphone6plus = CGSize(width: 414, height: 736)
    static let ipadMini = CGSize(width: 768, height: 1024)
    static let ipadAir = CGSize(width: 768, height: 1024)
    static let ipadPro = CGSize(width: 1024, height: 1366)
    
    var landscape: CGSize { return CGSize(width: height, height: width) }
}

private func setup(_ controller: UIViewController, with actions: [UIBarButtonItem], in size: CGSize) {
    PlaygroundPage.current.needsIndefiniteExecution = true
    controller.navigationItem.rightBarButtonItems = actions
    let w = UIWindow(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    w.rootViewController = controller
    w.makeKeyAndVisible()
    PlaygroundPage.current.liveView = w
}

let size = CGSize.iphone4
let controller = Controller(in: size)
setup(controller, with: [], in: size)

//: [Next](@next)
