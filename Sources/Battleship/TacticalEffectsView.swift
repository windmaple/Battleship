import SwiftUI

public struct ImpactAnimationEvent: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case hit
        case sunk
        case miss
        case sonar
    }

    public let id = UUID()
    public let coordinate: Coordinate
    public let kind: Kind
    public let createdAt: Date

    public init(coordinate: Coordinate, kind: Kind, createdAt: Date = Date()) {
        self.coordinate = coordinate
        self.kind = kind
        self.createdAt = createdAt
    }
}

public struct RadarSweepOverlayView: View {
    public let accentColor: Color

    public init(accentColor: Color = NavalTheme.sonarCyan) {
        self.accentColor = accentColor
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let angleDegrees = (elapsed * 48.0).truncatingRemainder(dividingBy: 360.0)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = hypot(size.width, size.height) * 0.52

                // Subtle concentric range rings
                for fraction in [0.28, 0.56, 0.84] {
                    let r = min(size.width, size.height) * 0.5 * fraction
                    let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    context.stroke(
                        ring,
                        with: .color(accentColor.opacity(0.08)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }

                // Rotating sweep sector (32 degree trailing cone)
                let startAngle = Angle.degrees(angleDegrees - 32.0)
                let endAngle = Angle.degrees(angleDegrees)

                var sector = Path()
                sector.move(to: center)
                sector.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                sector.closeSubpath()

                context.fill(
                    sector,
                    with: .radialGradient(
                        Gradient(colors: [accentColor.opacity(0.11), accentColor.opacity(0.01)]),
                        center: center,
                        startRadius: 2,
                        endRadius: radius
                    )
                )

                // Leading radar beam line
                var beam = Path()
                beam.move(to: center)
                let rad = CGFloat(endAngle.radians)
                beam.addLine(to: CGPoint(
                    x: center.x + cos(rad) * radius,
                    y: center.y + sin(rad) * radius
                ))
                context.stroke(beam, with: .color(accentColor.opacity(0.28)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
    }
}

public struct CellMarkerView: View {
    public let outcome: ShotOutcome?
    public let radarContact: Bool?

    public init(outcome: ShotOutcome?, radarContact: Bool?) {
        self.outcome = outcome
        self.radarContact = radarContact
    }

    public var body: some View {
        ZStack {
            if let outcome {
                switch outcome {
                case .miss:
                    ZStack {
                        Circle()
                            .stroke(NavalTheme.sonarCyan.opacity(0.45), lineWidth: 1.4)
                            .padding(8)
                        Circle()
                            .fill(NavalTheme.sonarCyan.opacity(0.65))
                            .frame(width: 6, height: 6)
                    }

                case .hit:
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        NavalTheme.warningAmber,
                                        NavalTheme.threatCrimson,
                                        NavalTheme.threatCrimson.opacity(0.15)
                                    ],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: 14
                                )
                            )
                            .padding(4)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: NavalTheme.threatCrimson, radius: 4)
                    }

                case .sunk:
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NavalTheme.threatCrimson.opacity(0.32))
                            .padding(2)

                        Path { path in
                            path.move(to: CGPoint(x: 7, y: 7))
                            path.addLine(to: CGPoint(x: 25, y: 25))
                            path.move(to: CGPoint(x: 25, y: 7))
                            path.addLine(to: CGPoint(x: 7, y: 25))
                        }
                        .stroke(NavalTheme.threatCrimson, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .frame(width: 32, height: 32)
                    }
                }
            } else if let radarContact {
                if radarContact {
                    ZStack {
                        Circle()
                            .stroke(NavalTheme.warningAmber, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            .padding(5)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NavalTheme.warningAmber)
                            .shadow(color: NavalTheme.warningAmber.opacity(0.8), radius: 4)
                    }
                } else {
                    Circle()
                        .fill(NavalTheme.radarEmerald.opacity(0.35))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

public struct ImpactFXOverlayView: View {
    public let events: [ImpactAnimationEvent]
    public let cellSize: CGFloat

    public init(events: [ImpactAnimationEvent], cellSize: CGFloat) {
        self.events = events
        self.cellSize = cellSize
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, _ in
                let now = timeline.date
                for event in events {
                    let age = now.timeIntervalSince(event.createdAt)
                    let duration = event.kind == .sunk ? 1.1 : 0.75
                    guard age >= 0 && age <= duration else { continue }
                    let progress = CGFloat(age / duration)
                    let fade = 1.0 - progress

                    let center = CGPoint(
                        x: (CGFloat(event.coordinate.col) + 0.5) * cellSize,
                        y: (CGFloat(event.coordinate.row) + 0.5) * cellSize
                    )

                    let color: Color
                    switch event.kind {
                    case .hit: color = NavalTheme.warningAmber
                    case .sunk: color = NavalTheme.threatCrimson
                    case .miss: color = NavalTheme.sonarCyan
                    case .sonar: color = NavalTheme.radarEmerald
                    }

                    // Expanding shockwave ring
                    let maxRadius = cellSize * (event.kind == .sunk ? 1.85 : 1.15)
                    let r1 = max(2, maxRadius * progress)
                    let ring1 = Path(ellipseIn: CGRect(x: center.x - r1, y: center.y - r1, width: r1 * 2, height: r1 * 2))
                    context.stroke(ring1, with: .color(color.opacity(Double(fade) * 0.95)), lineWidth: 2.6 * fade)

                    // Secondary ripple
                    if progress > 0.15 {
                        let r2 = max(2, maxRadius * (progress - 0.15))
                        let ring2 = Path(ellipseIn: CGRect(x: center.x - r2, y: center.y - r2, width: r2 * 2, height: r2 * 2))
                        context.stroke(ring2, with: .color(color.opacity(Double(fade) * 0.65)), lineWidth: 1.5 * fade)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
