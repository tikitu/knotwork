import Core
import Foundation
import ImageIO
import SwiftUI

extension Tile {
    /// Boston-Baden's image for this tile, 20 × 20 pixels.
    ///
    /// Read with ImageIO rather than `UIImage` or `NSImage`, so the same code
    /// serves every platform (`rules/platform-conditionals.md`); and from the
    /// resource bundle rather than an asset catalog, which `swift build`
    /// cannot compile.
    var image: Image { Self.images[self] ?? Image(systemName: "questionmark.square.dashed") }

    private static let images: [Tile: Image] = Dictionary(
        uniqueKeysWithValues: allCases.compactMap { tile in
            guard
                let url = Bundle.module.url(
                    forResource: tile.rawValue, withExtension: "gif", subdirectory: "Tiles"),
                let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            return (tile, Image(decorative: image, scale: 1))
        })
}
