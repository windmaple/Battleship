import SwiftUI

public struct TacticalGridView: View {
    public enum GridRole {
        case setupDrydock
        case offensiveRadar
        case defensiveFleet
    }

    public let role: GridRole
    public let board: NavalBoard
    public let cellSize: CGFloat
    public let showShips: Bool
    public let showProbabilityHeatmap: Bool
    public let probabilityMap: [[Double]]
    public let fxEvents: [ImpactAnimationEvent]

    // Setup preview
    public let selectedSetupShip: ShipType?
    public let setupOrientation: ShipOrientation

    // Offensive weapon preview
    public let activeWeapon: TacticalWeapon
    public let weaponOrientation: ShipOrientation
    public let isInteractive: Bool
    public let onCellTap: (Coordinate) -> Void

    @State private var hoveredCoord: Coordinate? = nil

    public init(
        role: GridRole,
        board: NavalBoard,
        cellSize: CGFloat = 38,
        showShips: Bool,
        showProbabilityHeatmap: Bool = false,
        probabilityMap: [[Double]] = [],
        fxEvents: [ImpactAnimationEvent] = [],
        selectedSetupShip: ShipType? = nil,
        setupOrientation: ShipOrientation = .horizontal,
        activeWeapon: TacticalWeapon = .standardTorpedo,
        weaponOrientation: ShipOrientation = .horizontal,
        isInteractive: Bool = true,
        onCellTap: @escaping (Coordinate) -> Void
    ) {
        self.role = role
        self.board = board
        self.cellSize = cellSize
        self.showShips = showShips
        self.showProbabilityHeatmap = showProbabilityHeatmap
        self.probabilityMap = probabilityMap
        self.fxEvents = fxEvents
        self.selectedSetupShip = selectedSetupShip
        self.setupOrientation = setupOrientation
        self.activeWeapon = activeWeapon
        self.weaponOrientation = weaponOrientation
        self.isInteractive = isInteractive
        self.onCellTap = onCellTap
    }

    private var headerSize: CGFloat {
        max(20, cellSize * 0.62)
    }

    private var gridDimension: CGFloat {
        cellSize * CGFloat(Coordinate.gridSize)
    }

    private var highlightedWeaponCoords: Set<Coordinate> {
        guard role == .offensiveRadar, isInteractive, let hoveredCoord else { return [] }
        return Set(activeWeapon.affectedCoordinates(center: hoveredCoord, orientation: weaponOrientation))
    }

    private var setupPreviewCoords: (coords: Set<Coordinate>, isValid: Bool) {
        guard role == .setupDrydock,
              let hoveredCoord,
              let shipType = selectedSetupShip else {
            return ([], false)
        }
        let coords = PlacedShip.computeCoordinates(
            origin: hoveredCoord,
            length: shipType.length,
            orientation: setupOrientation
        )
        let valid = board.canPlaceShip(
            type: shipType,
            origin: hoveredCoord,
            orientation: setupOrientation
        )
        return (Set(coords), valid)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Column Labels (1 ... 10)
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: headerSize, height: headerSize)

                ForEach(0..<Coordinate.gridSize, id: \.self) { col in
                    let isColHovered = hoveredCoord?.col == col
                    Text("\(col + 1)")
                        .font(.system(size: max(10, cellSize * 0.29), weight: .bold, design: .monospaced))
                        .foregroundStyle(isColHovered ? NavalTheme.sonarCyan : NavalTheme.textSecondary)
                        .frame(width: cellSize, height: headerSize)
                        .background(
                            isColHovered
                                ? NavalTheme.sonarCyan.opacity(0.12)
                                : Color.clear
                        )
                }
            }

            HStack(spacing: 0) {
                // Left Row Labels (A ... J)
                VStack(spacing: 0) {
                    ForEach(0..<Coordinate.gridSize, id: \.self) { row in
                        let isRowHovered = hoveredCoord?.row == row
                        Text(Coordinate.rowLetters[row])
                            .font(.system(size: max(10, cellSize * 0.29), weight: .bold, design: .monospaced))
                            .foregroundStyle(isRowHovered ? NavalTheme.sonarCyan : NavalTheme.textSecondary)
                            .frame(width: headerSize, height: cellSize)
                            .background(
                                isRowHovered
                                    ? NavalTheme.sonarCyan.opacity(0.12)
                                    : Color.clear
                            )
                    }
                }

                // Main 10x10 Radar Canvas + Interactive Cells
                ZStack(alignment: .topLeading) {
                    // 1. Base Water Background
                    Rectangle()
                        .fill(NavalTheme.gridWater)
                        .frame(width: gridDimension, height: gridDimension)

                    // 2. Optional Probability Heatmap Layer
                    if showProbabilityHeatmap && probabilityMap.count == Coordinate.gridSize {
                        probabilityLayer
                    }

                    // 3. Crosshair Row/Col Guide Highlight on Hover
                    if let hoveredCoord, isInteractive {
                        Rectangle()
                            .fill(NavalTheme.sonarCyan.opacity(0.05))
                            .frame(width: gridDimension, height: cellSize)
                            .offset(x: 0, y: CGFloat(hoveredCoord.row) * cellSize)
                            .allowsHitTesting(false)

                        Rectangle()
                            .fill(NavalTheme.sonarCyan.opacity(0.05))
                            .frame(width: cellSize, height: gridDimension)
                            .offset(x: CGFloat(hoveredCoord.col) * cellSize, y: 0)
                            .allowsHitTesting(false)
                    }

                    // 4. Placed Ships Layer (All ships if showShips == true, or sunk ships on enemy board)
                    ForEach(board.ships) { ship in
                        if showShips || ship.isSunk {
                            let shipWidth = ship.orientation == .horizontal
                                ? CGFloat(ship.type.length) * cellSize
                                : cellSize
                            let shipHeight = ship.orientation == .vertical
                                ? CGFloat(ship.type.length) * cellSize
                                : cellSize

                            ShipSilhouetteView(
                                shipType: ship.type,
                                orientation: ship.orientation,
                                isSunk: ship.isSunk
                            )
                            .frame(width: shipWidth, height: shipHeight)
                            .offset(
                                x: CGFloat(ship.origin.col) * cellSize,
                                y: CGFloat(ship.origin.row) * cellSize
                            )
                        }
                    }

                    // 5. Ghost Ship Preview in Setup Mode
                    if role == .setupDrydock,
                       let hoveredCoord,
                       let shipType = selectedSetupShip {
                        let valid = setupPreviewCoords.isValid
                        let ghostW = setupOrientation == .horizontal
                            ? CGFloat(shipType.length) * cellSize
                            : cellSize
                        let ghostH = setupOrientation == .vertical
                            ? CGFloat(shipType.length) * cellSize
                            : cellSize

                        ShipSilhouetteView(
                            shipType: shipType,
                            orientation: setupOrientation,
                            isSunk: false,
                            isGhostPreview: true,
                            isValidGhost: valid
                        )
                        .frame(width: ghostW, height: ghostH)
                        .offset(
                            x: CGFloat(hoveredCoord.col) * cellSize,
                            y: CGFloat(hoveredCoord.row) * cellSize
                        )
                        .clipShape(Rectangle().size(width: gridDimension, height: gridDimension))
                    }

                    // 6. Grid Cells + Markers + Interactive Tap Targets
                    VStack(spacing: 0) {
                        ForEach(0..<Coordinate.gridSize, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(0..<Coordinate.gridSize, id: \.self) { col in
                                    let coord = Coordinate(row: row, col: col)
                                    cellView(for: coord)
                                }
                            }
                        }
                    }

                    // 7. Radar Sweep Overlay
                    RadarSweepOverlayView(
                        accentColor: role == .offensiveRadar ? NavalTheme.sonarCyan : NavalTheme.radarEmerald
                    )
                    .frame(width: gridDimension, height: gridDimension)

                    // 8. Shockwave & Explosion FX Layer
                    ImpactFXOverlayView(events: fxEvents, cellSize: cellSize)
                        .frame(width: gridDimension, height: gridDimension)
                }
                .frame(width: gridDimension, height: gridDimension)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            role == .offensiveRadar
                                ? NavalTheme.sonarCyan.opacity(0.55)
                                : NavalTheme.radarEmerald.opacity(0.42),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: (role == .offensiveRadar ? NavalTheme.sonarCyan : NavalTheme.radarEmerald).opacity(0.14),
                    radius: 10
                )
            }
        }
    }

    @ViewBuilder
    private var probabilityLayer: some View {
        VStack(spacing: 0) {
            ForEach(0..<Coordinate.gridSize, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<Coordinate.gridSize, id: \.self) { col in
                        let weight = probabilityMap[row][col]
                        let coord = Coordinate(row: row, col: col)
                        ZStack {
                            if board.shots[coord] == nil && weight > 0.02 {
                                Rectangle()
                                    .fill(heatmapColor(for: weight))
                                if weight >= 0.65 && cellSize >= 34 {
                                    Text("\(Int((weight * 99).rounded()))")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func heatmapColor(for normalized: Double) -> Color {
        if normalized > 0.80 {
            return NavalTheme.threatCrimson.opacity(0.42)
        } else if normalized > 0.50 {
            return NavalTheme.warningAmber.opacity(0.32)
        } else {
            return NavalTheme.sonarCyan.opacity(normalized * 0.28)
        }
    }

    @ViewBuilder
    private func cellView(for coord: Coordinate) -> some View {
        let outcome = board.shots[coord]
        let radarContact = board.radarContacts[coord]
        let isWeaponTarget = highlightedWeaponCoords.contains(coord)
        let isDirectHover = (hoveredCoord == coord && isInteractive)

        ZStack {
            // Grid cell border
            Rectangle()
                .stroke(NavalTheme.gridLine, lineWidth: 0.6)

            // Weapon footprint highlight
            if isWeaponTarget {
                Rectangle()
                    .fill(
                        activeWeapon == .sonarPing
                            ? NavalTheme.radarEmerald.opacity(0.24)
                            : NavalTheme.warningAmber.opacity(0.26)
                    )
                Rectangle()
                    .stroke(
                        activeWeapon == .sonarPing ? NavalTheme.radarEmerald : NavalTheme.warningAmber,
                        lineWidth: 1.4
                    )
            } else if isDirectHover && role == .setupDrydock {
                Rectangle()
                    .stroke(
                        setupPreviewCoords.isValid ? NavalTheme.sonarCyan : NavalTheme.threatCrimson,
                        lineWidth: 1.4
                    )
            }

            // Shot / Radar Marker
            CellMarkerView(outcome: outcome, radarContact: radarContact)

            // Target Lock Reticle on Offensive Radar Hover
            if isDirectHover && role == .offensiveRadar && outcome == nil {
                Image(systemName: activeWeapon == .sonarPing ? "wave.3.right" : "plus.viewfinder")
                    .font(.system(size: cellSize * 0.45, weight: .regular))
                    .foregroundStyle(
                        activeWeapon == .sonarPing ? NavalTheme.radarEmerald : NavalTheme.sonarCyan
                    )
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoveredCoord = coord
            } else if hoveredCoord == coord {
                hoveredCoord = nil
            }
        }
        .onTapGesture {
            guard isInteractive else { return }
            onCellTap(coord)
        }
    }
}
