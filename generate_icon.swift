#!/usr/bin/env swift
import AppKit
import CoreGraphics

let logoPath = "\(FileManager.default.currentDirectoryPath)/assets/welcome_logo.png"

func generateIcon(size: Int, logo: NSImage) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Background: rounded square with gradient (matching color picker pattern)
    let bgRect = CGRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.2, cornerHeight: s * 0.2, transform: nil)

    // Draw shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.06, color: CGColor(gray: 0, alpha: 0.3))
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.addPath(bgPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient (#08131c to slightly lighter)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgColors = [
        CGColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 1),  // slightly lighter at top
        CGColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1)   // #08131c at bottom
    ]
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: s/2, y: s * 0.94), end: CGPoint(x: s/2, y: s * 0.06), options: [])

    // Draw the M logo centered in the squircle
    let logoSize = s * 0.65
    let logoX = s * 0.06 + (s * 0.88 - logoSize) / 2
    let logoY = s * 0.06 + (s * 0.88 - logoSize) / 2
    let logoRect = NSRect(x: logoX, y: logoY, width: logoSize, height: logoSize)
    logo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, size: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// Load the M logo (transparent PNG)
guard let logo = NSImage(contentsOfFile: logoPath) else {
    print("Error: Could not load logo from \(logoPath)")
    exit(1)
}

// Generate iconset
let iconsetPath = "assets/mdview.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let image = generateIcon(size: entry.pixels, logo: logo)
    let path = "\(iconsetPath)/\(entry.name).png"
    savePNG(image, to: path, size: entry.pixels)
    print("Generated \(entry.name).png (\(entry.pixels)x\(entry.pixels))")
}

// Also save 1024 as icon_1024.png
let icon1024 = generateIcon(size: 1024, logo: logo)
savePNG(icon1024, to: "assets/icon_1024.png", size: 1024)
print("Generated icon_1024.png")

print("Done! Run: iconutil -c icns assets/mdview.iconset -o assets/mdview.icns")
