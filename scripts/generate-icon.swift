#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Initialize AppKit so we can render SF Symbols + bitmap contexts from a script.
_ = NSApplication.shared

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Hop/Assets.xcassets/AppIcon.appiconset"

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func render(pixelSize: Int) -> Data? {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Rounded-rect clipping path.
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.225
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Vertical gradient background.
    let topColor = CGColor(red: 0.30, green: 0.78, blue: 0.48, alpha: 1)
    let bottomColor = CGColor(red: 0.14, green: 0.52, blue: 0.30, alpha: 1)
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: size / 2, y: size),
        end: CGPoint(x: size / 2, y: 0),
        options: []
    )

    // Render SF Symbol via NSImage into the CGContext.
    let symbolSide = size * 0.62
    let config = NSImage.SymbolConfiguration(pointSize: symbolSide, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        // Tint to white by drawing through a mask.
        let s = symbol.size
        let x = (size - s.width) / 2
        let y = (size - s.height) / 2
        let destRect = CGRect(x: x, y: y, width: s.width, height: s.height)

        // Get a CGImage for the symbol at its natural size.
        if let cgImage = symbol.cgImage(
            forProposedRect: nil,
            context: NSGraphicsContext(cgContext: ctx, flipped: false),
            hints: nil
        ) {
            // Draw the alpha mask filled with white.
            ctx.saveGState()
            ctx.clip(to: destRect, mask: cgImage)
            ctx.setFillColor(.white)
            ctx.fill(destRect)
            ctx.restoreGState()
        }
    }

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (filename, size) in variants {
    guard let data = render(pixelSize: size) else {
        FileHandle.standardError.write(Data("Failed: \(filename)\n".utf8))
        exit(1)
    }
    let path = "\(outputDir)/\(filename)"
    try! data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(size)×\(size))")
}
