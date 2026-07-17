//
//  RenderPixels.swift
//  FinanceTrackerTests
//
//  Small pixel-inspection helper so ImageRenderer-based view tests can assert on
//  what actually got drawn — opacity, colour, coverage — instead of only emitting
//  an artifact. A render test with no assertion is a guard with no callers.
//

import UIKit
import XCTest

/// An RGBA (premultiplied-last, 8-bit) view of a rendered image, top-left origin.
struct RenderBitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: UIImage) {
        let cg = image.cgImage!
        width = cg.width
        height = cg.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buffer
    }

    struct Pixel { let r, g, b, a: Int }

    func pixel(_ x: Int, _ y: Int) -> Pixel {
        let i = (y * width + x) * 4
        return Pixel(r: Int(bytes[i]), g: Int(bytes[i + 1]),
                     b: Int(bytes[i + 2]), a: Int(bytes[i + 3]))
    }

    /// The four corners, inset a couple of points to dodge any edge antialiasing.
    var corners: [Pixel] {
        let m = 2
        return [pixel(m, m), pixel(width - 1 - m, m),
                pixel(m, height - 1 - m), pixel(width - 1 - m, height - 1 - m)]
    }

    var center: Pixel { pixel(width / 2, height / 2) }

    /// Does any pixel come within `tolerance` (per channel) of the target colour?
    /// Used to prove specific content actually drew (e.g. the brand-mint crab).
    func containsColor(r: Int, g: Int, b: Int, tolerance: Int) -> Bool {
        var i = 0
        while i < bytes.count {
            if abs(Int(bytes[i]) - r) <= tolerance,
               abs(Int(bytes[i + 1]) - g) <= tolerance,
               abs(Int(bytes[i + 2]) - b) <= tolerance {
                return true
            }
            i += 4
        }
        return false
    }
}

extension RenderBitmap.Pixel {
    /// Max per-channel RGB distance to another pixel (ignores alpha).
    func rgbDistance(to other: RenderBitmap.Pixel) -> Int {
        max(abs(r - other.r), max(abs(g - other.g), abs(b - other.b)))
    }
}
