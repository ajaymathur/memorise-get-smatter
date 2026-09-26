// Renders the app icon variants into the asset catalog. Run: swift scripts/make-icon.swift
import AppKit

let size = 1024.0
let out = "GetSmarter/Resources/Assets.xcassets/AppIcon.appiconset"

// Okabe–Ito game colors, one tile per game.
let tiles: [NSColor] = [
    NSColor(srgbRed: 0.90, green: 0.62, blue: 0.00, alpha: 1),
    NSColor(srgbRed: 0.34, green: 0.71, blue: 0.91, alpha: 1),
    NSColor(srgbRed: 0.00, green: 0.62, blue: 0.45, alpha: 1),
    NSColor(srgbRed: 0.80, green: 0.47, blue: 0.65, alpha: 1),
]

enum Variant { case light, dark, tinted }

func render(_ variant: Variant, to name: String) {
    // Opaque (no alpha channel): App Store rejects marketing icons with alpha.
    let cg = CGContext(
        data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    let full = NSRect(x: 0, y: 0, width: size, height: size)

    switch variant {
    case .light:
        NSGradient(
            starting: NSColor(srgbRed: 0.36, green: 0.29, blue: 0.80, alpha: 1),
            ending: NSColor(srgbRed: 0.18, green: 0.13, blue: 0.48, alpha: 1))!.draw(in: full, angle: -90)
    case .dark:
        NSGradient(
            starting: NSColor(srgbRed: 0.10, green: 0.08, blue: 0.20, alpha: 1),
            ending: NSColor(srgbRed: 0.03, green: 0.02, blue: 0.08, alpha: 1))!.draw(in: full, angle: -90)
    case .tinted:
        NSColor.black.setFill()
        full.fill()
    }

    // 2×2 grid of rounded tiles; the top-right one "lit" with a glow, like Sequence Echo.
    let tile = 300.0, gap = 56.0
    let origin = (size - tile * 2 - gap) / 2
    for i in 0..<4 {
        let col = Double(i % 2), row = Double(1 - i / 2)
        let rect = NSRect(x: origin + col * (tile + gap), y: origin + row * (tile + gap), width: tile, height: tile)
        let path = NSBezierPath(roundedRect: rect, xRadius: 72, yRadius: 72)
        let color: NSColor
        switch variant {
        case .tinted: color = NSColor(white: i == 1 ? 1 : 0.55, alpha: 1)
        default: color = tiles[i].withAlphaComponent(i == 1 ? 1 : 0.9)
        }
        if i == 1 {
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = (variant == .tinted ? NSColor.white : tiles[1]).withAlphaComponent(0.9)
            glow.shadowBlurRadius = 90
            glow.set()
            color.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            color.setFill()
            path.fill()
        }
    }
    NSGraphicsContext.current = nil
    let rep = NSBitmapImageRep(cgImage: cg.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}

render(.light, to: "icon-light.png")
render(.dark, to: "icon-dark.png")
render(.tinted, to: "icon-tinted.png")

let contents = """
    {
      "images" : [
        { "filename" : "icon-light.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
        { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
          "filename" : "icon-dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
        { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
          "filename" : "icon-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
try! contents.write(toFile: "\(out)/Contents.json", atomically: true, encoding: .utf8)
print("icons written to \(out)")
