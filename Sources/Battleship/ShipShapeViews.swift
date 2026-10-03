import SwiftUI

public struct ShipSilhouetteView: View {
    public let shipType: ShipType
    public let orientation: ShipOrientation
    public let isSunk: Bool
    public let isGhostPreview: Bool
    public let isValidGhost: Bool

    public init(
        shipType: ShipType,
        orientation: ShipOrientation = .horizontal,
        isSunk: Bool = false,
        isGhostPreview: Bool = false,
        isValidGhost: Bool = true
    ) {
        self.shipType = shipType
        self.orientation = orientation
        self.isSunk = isSunk
        self.isGhostPreview = isGhostPreview
        self.isValidGhost = isValidGhost
    }

    private var fillColor: Color {
        if isGhostPreview {
            return isValidGhost
                ? NavalTheme.sonarCyan.opacity(0.32)
                : NavalTheme.threatCrimson.opacity(0.38)
        }
        if isSunk {
            return NavalTheme.threatCrimson.opacity(0.28)
        }
        return NavalTheme.hullSteel.opacity(0.65)
    }

    private var strokeColor: Color {
        if isGhostPreview {
            return isValidGhost ? NavalTheme.sonarCyan : NavalTheme.threatCrimson
        }
        if isSunk {
            return NavalTheme.threatCrimson.opacity(0.85)
        }
        return NavalTheme.hullOutline
    }

    public var body: some View {
        Canvas { context, size in
            let isVert = (orientation == .vertical)
            let w = isVert ? size.height : size.width
            let h = isVert ? size.width : size.height

            var drawCtx = context
            if isVert {
                // Rotate 90 degrees clockwise around center:
                // After translating to (size.width, 0) and rotating +90deg, a horizontal drawing of (w, h) fits (size.width, size.height)
                drawCtx.translateBy(x: size.width, y: 0)
                drawCtx.rotate(by: .degrees(90))
            }

            let rect = CGRect(x: 3, y: 4, width: max(10, w - 6), height: max(8, h - 8))
            drawHull(in: &drawCtx, rect: rect)
        }
        .allowsHitTesting(false)
    }

    private func drawHull(in context: inout GraphicsContext, rect: CGRect) {
        var hull = Path()
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let midY = rect.midY
        let w = rect.width
        let h = rect.height

        switch shipType {
        case .carrier:
            // Angled flight deck aircraft carrier silhouette
            hull.move(to: CGPoint(x: minX + w * 0.04, y: minY + h * 0.18))
            hull.addLine(to: CGPoint(x: minX + w * 0.86, y: minY + h * 0.06))
            hull.addLine(to: CGPoint(x: maxX, y: minY + h * 0.25))
            hull.addLine(to: CGPoint(x: maxX, y: maxY - h * 0.22))
            hull.addLine(to: CGPoint(x: minX + w * 0.78, y: maxY - h * 0.05))
            hull.addLine(to: CGPoint(x: minX + w * 0.08, y: maxY - h * 0.12))
            hull.addLine(to: CGPoint(x: minX, y: midY))
            hull.closeSubpath()

            context.fill(hull, with: .color(fillColor))
            context.stroke(hull, with: .color(strokeColor), lineWidth: 1.6)

            // Flight deck runway dashed centerline
            var runway = Path()
            runway.move(to: CGPoint(x: minX + w * 0.12, y: midY + h * 0.06))
            runway.addLine(to: CGPoint(x: maxX - w * 0.06, y: midY - h * 0.08))
            context.stroke(
                runway,
                with: .color(strokeColor.opacity(0.75)),
                style: StrokeStyle(lineWidth: 1.1, dash: [4, 3])
            )

            // Superstructure island
            let island = CGRect(
                x: minX + w * 0.32,
                y: minY + h * 0.14,
                width: w * 0.16,
                height: h * 0.24
            )
            context.fill(Path(roundedRect: island, cornerRadius: 2), with: .color(strokeColor.opacity(0.55)))

        case .battleship:
            // Heavy armored hull with pointed bow and triple gun turrets
            hull.move(to: CGPoint(x: minX, y: midY))
            hull.addQuadCurve(
                to: CGPoint(x: minX + w * 0.18, y: minY + h * 0.10),
                control: CGPoint(x: minX + w * 0.06, y: minY + h * 0.10)
            )
            hull.addLine(to: CGPoint(x: maxX - w * 0.16, y: minY + h * 0.10))
            hull.addQuadCurve(
                to: CGPoint(x: maxX, y: midY),
                control: CGPoint(x: maxX - w * 0.02, y: minY + h * 0.15)
            )
            hull.addQuadCurve(
                to: CGPoint(x: maxX - w * 0.16, y: maxY - h * 0.10),
                control: CGPoint(x: maxX - w * 0.02, y: maxY - h * 0.15)
            )
            hull.addLine(to: CGPoint(x: minX + w * 0.18, y: maxY - h * 0.10))
            hull.addQuadCurve(
                to: CGPoint(x: minX, y: midY),
                control: CGPoint(x: minX + w * 0.06, y: maxY - h * 0.10)
            )
            hull.closeSubpath()

            context.fill(hull, with: .color(fillColor))
            context.stroke(hull, with: .color(strokeColor), lineWidth: 1.6)

            // Turrets
            for turretX in [0.24, 0.50, 0.74] {
                let c = CGPoint(x: minX + w * turretX, y: midY)
                let r = min(w * 0.06, h * 0.24)
                let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                context.fill(circle, with: .color(strokeColor.opacity(0.65)))
            }

        case .cruiser:
            // Sleek guided-missile hull with VLS cells and bridge
            hull.move(to: CGPoint(x: minX + w * 0.04, y: minY + h * 0.20))
            hull.addLine(to: CGPoint(x: maxX - w * 0.22, y: minY + h * 0.12))
            hull.addLine(to: CGPoint(x: maxX, y: midY))
            hull.addLine(to: CGPoint(x: maxX - w * 0.22, y: maxY - h * 0.12))
            hull.addLine(to: CGPoint(x: minX + w * 0.04, y: maxY - h * 0.20))
            hull.closeSubpath()

            context.fill(hull, with: .color(fillColor))
            context.stroke(hull, with: .color(strokeColor), lineWidth: 1.5)

            let bridge = CGRect(x: minX + w * 0.35, y: midY - h * 0.18, width: w * 0.26, height: h * 0.36)
            context.stroke(Path(roundedRect: bridge, cornerRadius: 2), with: .color(strokeColor.opacity(0.8)), lineWidth: 1.1)

        case .submarine:
            // Cigar-shaped pressure hull with bow planes and conning tower
            let capsuleRect = CGRect(
                x: minX + w * 0.03,
                y: minY + h * 0.18,
                width: w * 0.94,
                height: h * 0.64
            )
            hull = Path(roundedRect: capsuleRect, cornerRadius: h * 0.32)
            context.fill(hull, with: .color(fillColor))
            context.stroke(hull, with: .color(strokeColor), lineWidth: 1.5)

            // Sail / Conning tower + dive planes
            let sail = CGRect(x: minX + w * 0.38, y: midY - h * 0.14, width: w * 0.22, height: h * 0.28)
            context.fill(Path(roundedRect: sail, cornerRadius: h * 0.14), with: .color(strokeColor.opacity(0.7)))

            var planes = Path()
            planes.move(to: CGPoint(x: minX + w * 0.72, y: minY + h * 0.06))
            planes.addLine(to: CGPoint(x: minX + w * 0.72, y: maxY - h * 0.06))
            context.stroke(planes, with: .color(strokeColor), lineWidth: 1.6)

        case .destroyer:
            // Sharp stealth destroyer wedge
            hull.move(to: CGPoint(x: minX + w * 0.02, y: minY + h * 0.22))
            hull.addLine(to: CGPoint(x: maxX - w * 0.28, y: minY + h * 0.14))
            hull.addLine(to: CGPoint(x: maxX, y: midY))
            hull.addLine(to: CGPoint(x: maxX - w * 0.28, y: maxY - h * 0.14))
            hull.addLine(to: CGPoint(x: minX + w * 0.02, y: maxY - h * 0.22))
            hull.closeSubpath()

            context.fill(hull, with: .color(fillColor))
            context.stroke(hull, with: .color(strokeColor), lineWidth: 1.5)
        }
    }
}
