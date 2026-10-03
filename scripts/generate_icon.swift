import AppKit
import CoreGraphics
import Foundation

func renderIcon(size: Int) -> Data? {
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

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }

    let s = CGFloat(size)
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = rect.width * 0.225

    // 1. Rounded Squircle Background
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.02, green: 0.06, blue: 0.12, alpha: 1.0),
        CGColor(red: 0.05, green: 0.14, blue: 0.25, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: s * 0.5, y: s),
            end: CGPoint(x: s * 0.5, y: 0),
            options: []
        )
    }

    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    let maxR = rect.width * 0.40

    // 2. Radar Sweep Cone
    ctx.saveGState()
    ctx.move(to: center)
    ctx.addArc(center: center, radius: maxR, startAngle: .pi * 0.12, endAngle: .pi * 0.42, clockwise: false)
    ctx.closePath()
    ctx.setFillColor(CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.22))
    ctx.fillPath()
    ctx.restoreGState()

    // 3. Concentric Radar Rings & Crosshair
    for frac in [0.35, 0.68, 1.0] {
        let r = maxR * CGFloat(frac)
        let ringRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.setStrokeColor(CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: frac == 1.0 ? 0.75 : 0.32))
        ctx.setLineWidth(max(1.5, s * 0.012))
        ctx.strokeEllipse(in: ringRect)
    }

    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.28))
    ctx.setLineWidth(max(1.0, s * 0.008))
    ctx.move(to: CGPoint(x: center.x - maxR, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + maxR, y: center.y))
    ctx.move(to: CGPoint(x: center.x, y: center.y - maxR))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + maxR))
    ctx.strokePath()

    // 4. Battleship Top-Down Silhouette (angled diagonally)
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: .pi * 0.18)

    let shipW = maxR * 1.45
    let shipH = maxR * 0.34
    let shipPath = CGMutablePath()
    shipPath.move(to: CGPoint(x: -shipW * 0.5, y: 0))
    shipPath.addLine(to: CGPoint(x: -shipW * 0.34, y: shipH * 0.5))
    shipPath.addLine(to: CGPoint(x: shipW * 0.32, y: shipH * 0.5))
    shipPath.addLine(to: CGPoint(x: shipW * 0.5, y: 0))
    shipPath.addLine(to: CGPoint(x: shipW * 0.32, y: -shipH * 0.5))
    shipPath.addLine(to: CGPoint(x: -shipW * 0.34, y: -shipH * 0.5))
    shipPath.closeSubpath()

    ctx.addPath(shipPath)
    ctx.setFillColor(CGColor(red: 0.25, green: 0.45, blue: 0.62, alpha: 0.9))
    ctx.fillPath()

    ctx.addPath(shipPath)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.95))
    ctx.setLineWidth(max(1.5, s * 0.014))
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Glowing Target-Lock Pip
    let targetPt = CGPoint(x: center.x + maxR * 0.36, y: center.y + maxR * 0.26)
    let pipR = max(3.0, s * 0.042)
    ctx.setFillColor(CGColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 0.95))
    ctx.fillEllipse(in: CGRect(x: targetPt.x - pipR, y: targetPt.y - pipR, width: pipR * 2, height: pipR * 2))

    ctx.restoreGState()

    // Outer Squircle Border
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.92, blue: 1.0, alpha: 0.55))
    ctx.setLineWidth(max(1.5, s * 0.015))
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
let iconsetPath = "Resources/AppIcon.iconset"
try? fm.removeItem(atPath: iconsetPath)
try fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in specs {
    if let data = renderIcon(size: px) {
        try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
    }
}
print("Generated iconset at \(iconsetPath)")
