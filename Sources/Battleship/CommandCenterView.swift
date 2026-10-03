import SwiftUI

public struct CommandCenterView: View {
    @StateObject private var engine = GameEngine()
    @ObservedObject private var soundEngine = SoundEngine.shared
    @State private var showCareerPopover = false

    public init() {}

    public var body: some View {
        ZStack {
            NavalTheme.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topCommandHeader
                tacticalAlertBanner

                switch engine.phase {
                case .setup(let playerIndex):
                    setupDrydockLayout(playerIndex: playerIndex)
                case .passScreen(let nextIdx, let reason):
                    passConsoleOverlay(nextPlayerIndex: nextIdx, reason: reason)
                case .combat, .gameOver:
                    combatCommandLayout
                }
            }
            .padding(14)
        }
        .frame(minWidth: 1080, minHeight: 760)
        .preferredColorScheme(.dark)
        .focusable()
        .onKeyPress(characters: CharacterSet(charactersIn: "rR")) { _ in
            engine.rotateActiveOrientation()
            return .handled
        }
    }

    // MARK: - Top Command Header

    private var topCommandHeader: some View {
        HStack(spacing: 14) {
            // Emblem & Title
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(NavalTheme.sonarCyan.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(NavalTheme.sonarCyan, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NavalTheme.sonarCyan)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("BATTLESHIP // AEGIS COMMAND")
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NavalTheme.textPrimary)
                        .tracking(1.2)
                    Text("TACTICAL NAVAL WARFARE SYSTEM • MACOS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NavalTheme.sonarCyan.opacity(0.85))
                }
            }

            Spacer()

            // Mode Selector Menu
            Menu {
                Section("Single Player vs. AI") {
                    ForEach(AIDifficulty.allCases) { diff in
                        Button {
                            engine.gameMode = .vsAI(diff)
                            engine.startNewOperation()
                        } label: {
                            HStack {
                                Text("VS AI — \(diff.rawValue) (\(diff.subtitle))")
                                if engine.gameMode == .vsAI(diff) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Section("Local Multiplayer") {
                    Button {
                        engine.gameMode = .passAndPlay
                        engine.startNewOperation()
                    } label: {
                        HStack {
                            Text("2-Player Pass & Play (Hotseat)")
                            if engine.gameMode == .passAndPlay {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: engine.gameMode == .passAndPlay ? "person.2.fill" : "cpu")
                        .foregroundStyle(NavalTheme.sonarCyan)
                    Text(engine.gameMode.displayTitle)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NavalTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NavalTheme.bgPanelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(NavalTheme.sonarCyan.opacity(0.35), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Combat Rules Picker
            Picker("Rules", selection: Binding(
                get: { engine.combatRules },
                set: { newRules in
                    engine.combatRules = newRules
                    engine.startNewOperation()
                }
            )) {
                ForEach(CombatRules.allCases) { rule in
                    Text(rule.rawValue).tag(rule)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 245)
            .help(engine.combatRules.description)

            // AI Probability Heatmap Toggle
            Button {
                SoundEngine.shared.play(.targetClick)
                engine.showProbabilityOverlay.toggle()
                engine.refreshProbabilityMap()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: engine.showProbabilityOverlay ? "waveform.path.ecg.rectangle.fill" : "waveform.path.ecg.rectangle")
                    Text("PROBABILITY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(engine.showProbabilityOverlay ? NavalTheme.bgDeep : NavalTheme.sonarCyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(engine.showProbabilityOverlay ? NavalTheme.sonarCyan : NavalTheme.bgPanelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(NavalTheme.sonarCyan.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Toggle real-time mathematical probability density heatmap on enemy radar")

            // Career Stats Popover Button
            Button {
                SoundEngine.shared.play(.targetClick)
                showCareerPopover.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(NavalTheme.warningAmber)
                    Text("\(engine.careerStats.victories)W-\(engine.careerStats.defeats)L")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(NavalTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NavalTheme.bgPanelElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(NavalTheme.warningAmber.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCareerPopover, arrowEdge: .bottom) {
                careerStatsPopover
            }

            // Mute / Unmute Audio Button
            Button {
                soundEngine.isMuted.toggle()
                if !soundEngine.isMuted {
                    soundEngine.play(.targetClick)
                }
            } label: {
                Image(systemName: soundEngine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(soundEngine.isMuted ? NavalTheme.threatCrimson : NavalTheme.sonarCyan)
                    .frame(width: 32, height: 28)
                    .background(NavalTheme.bgPanelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(NavalTheme.sonarCyan.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(soundEngine.isMuted ? "Unmute Naval Audio" : "Mute Naval Audio")

            // New Operation Button
            Button {
                SoundEngine.shared.play(.sonarPing)
                engine.startNewOperation()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                    Text("NEW OP")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NavalTheme.bgDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(NavalTheme.radarEmerald)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NavalTheme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(NavalTheme.sonarCyan.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Live Tactical Banner

    private var tacticalAlertBanner: some View {
        let bannerAccent: Color = {
            switch engine.latestBannerCategory {
            case .hit, .warning: return NavalTheme.warningAmber
            case .sunk: return NavalTheme.threatCrimson
            case .radar: return NavalTheme.radarEmerald
            case .info, .miss: return NavalTheme.sonarCyan
            }
        }()

        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(bannerAccent)
                    .frame(width: 8, height: 8)
                    .shadow(color: bannerAccent, radius: 4)
                Text("TURN \(String(format: "%02d", engine.turnNumber))")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(bannerAccent)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(bannerAccent.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(engine.latestBannerMessage)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NavalTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if case .combat(let activeIdx) = engine.phase {
                HStack(spacing: 8) {
                    if engine.isAITurnInProgress {
                        ProgressView()
                            .controlSize(.small)
                        Text("OPFOR TARGETING...")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(NavalTheme.warningAmber)
                    } else {
                        Text("\(engine.playerName(for: activeIdx))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(NavalTheme.sonarCyan)

                        if engine.combatRules == .salvo {
                            HStack(spacing: 3) {
                                Text("SALVO:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(NavalTheme.textSecondary)
                                ForEach(0..<max(1, engine.shotsRemainingInTurn), id: \.self) { _ in
                                    Circle()
                                        .fill(NavalTheme.warningAmber)
                                        .frame(width: 7, height: 7)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(NavalTheme.warningAmber.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(NavalTheme.bgPanel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bannerAccent.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Setup Drydock Phase Layout

    private func setupDrydockLayout(playerIndex: Int) -> some View {
        let board = engine.boards[playerIndex]

        return HStack(spacing: 16) {
            // Left Drydock Roster & Controls
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(engine.playerName(for: playerIndex)) // FLEET DRYDOCK")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NavalTheme.sonarCyan)
                    Text("Select a vessel below, press 'R' to rotate axis, and click on the tactical grid to position your fleet.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(NavalTheme.textSecondary)
                }

                // 5 Ships Selection List
                VStack(spacing: 8) {
                    ForEach(ShipType.allCases) { shipType in
                        let isSelected = (engine.selectedShipForPlacement == shipType)
                        let placed = board.ship(ofType: shipType)

                        Button {
                            SoundEngine.shared.play(.targetClick)
                            engine.selectedShipForPlacement = shipType
                            if let placed {
                                engine.placementOrientation = placed.orientation
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ShipSilhouetteView(shipType: shipType, orientation: .horizontal)
                                    .frame(width: CGFloat(shipType.length) * 22, height: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(shipType.hullName.uppercased())
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(NavalTheme.textPrimary)
                                        Text(shipType.hullClassification)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(NavalTheme.sonarCyan)
                                    }
                                    Text("\(shipType.roleDescription) • \(shipType.length) Sectors")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(NavalTheme.textSecondary)
                                }

                                Spacer()

                                if let placed {
                                    Text(placed.origin.compactNotation + " " + placed.orientation.shortCode)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(NavalTheme.radarEmerald)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(NavalTheme.radarEmerald.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Text("UNDEPLOYED")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(NavalTheme.warningAmber)
                                }
                            }
                            .padding(10)
                            .background(isSelected ? NavalTheme.bgPanelElevated : NavalTheme.bgDeep.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected ? NavalTheme.sonarCyan : NavalTheme.sonarCyan.opacity(0.18),
                                        lineWidth: isSelected ? 1.6 : 1.0
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Orientation & Auto-Deploy Toolbar
                HStack(spacing: 10) {
                    Button {
                        engine.rotateActiveOrientation()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rotate.right")
                            Text("AXIS: \(engine.placementOrientation.rawValue.uppercased()) (R)")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(NavalTheme.sonarCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(NavalTheme.bgPanelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(NavalTheme.sonarCyan.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.randomizeSetupFleet()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                            Text("AUTO-DEPLOY")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(NavalTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(NavalTheme.bgPanelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(NavalTheme.sonarCyan.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.clearSetupFleet()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(NavalTheme.threatCrimson)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(NavalTheme.bgPanelElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(NavalTheme.threatCrimson.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Clear all placed ships from the grid")
                }

                Spacer()

                // Launch Operation Button
                Button {
                    engine.confirmSetupDeployment()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(
                            engine.gameMode == .passAndPlay && playerIndex == 0
                                ? "CONFIRM ALPHA FLEET & PASS TO BRAVO"
                                : "COMMENCE NAVAL OPERATION"
                        )
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                    }
                    .foregroundStyle(board.isFleetComplete ? NavalTheme.bgDeep : NavalTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(board.isFleetComplete ? NavalTheme.radarEmerald : NavalTheme.bgPanelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: board.isFleetComplete ? NavalTheme.radarEmerald.opacity(0.4) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(!board.isFleetComplete)
            }
            .frame(width: 410)
            .padding(16)
            .background(NavalTheme.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(NavalTheme.sonarCyan.opacity(0.25), lineWidth: 1)
            )

            // Right Interactive Drydock Grid
            VStack(spacing: 12) {
                HStack {
                    Label("DRYDOCK DEPLOYMENT SECTOR GRID (10×10)", systemImage: "grid")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(NavalTheme.radarEmerald)
                    Spacer()
                    Text("\(board.ships.count) / 5 VESSELS DEPLOYED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(board.isFleetComplete ? NavalTheme.radarEmerald : NavalTheme.warningAmber)
                }

                Spacer(minLength: 0)

                TacticalGridView(
                    role: .setupDrydock,
                    board: board,
                    cellSize: 44,
                    showShips: true,
                    selectedSetupShip: engine.selectedShipForPlacement,
                    setupOrientation: engine.placementOrientation,
                    isInteractive: true,
                    onCellTap: { coord in
                        engine.handleSetupGridClick(at: coord)
                    }
                )

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .background(NavalTheme.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(NavalTheme.radarEmerald.opacity(0.28), lineWidth: 1)
            )
        }
    }

    // MARK: - Pass & Play Security Screen

    private func passConsoleOverlay(nextPlayerIndex: Int, reason: String) -> some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(NavalTheme.warningAmber.opacity(0.12))
                    .frame(width: 96, height: 96)
                Circle()
                    .stroke(NavalTheme.warningAmber, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(NavalTheme.warningAmber)
            }

            Text("CLASSIFIED COMMAND HANDOFF")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(NavalTheme.textPrimary)
                .tracking(2)

            Text(reason)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(NavalTheme.warningAmber)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Text("Friendly fleet coordinates are concealed during player transition.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(NavalTheme.textSecondary)

            Button {
                engine.proceedFromPassScreen()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("AUTHENTICATE AS \(engine.playerName(for: nextPlayerIndex))")
                }
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(NavalTheme.bgDeep)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(NavalTheme.sonarCyan)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: NavalTheme.sonarCyan.opacity(0.45), radius: 10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NavalTheme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(NavalTheme.warningAmber.opacity(0.45), lineWidth: 1.5)
        )
    }

    // MARK: - Main Combat & Game Over Layout

    private var combatCommandLayout: some View {
        let isGameOver: Bool = {
            if case .gameOver = engine.phase { return true }
            return false
        }()

        let canFire: Bool = {
            guard case .combat(let activeIdx) = engine.phase else { return false }
            if engine.isAITurnInProgress { return false }
            if engine.gameMode != .passAndPlay && activeIdx != 0 { return false }
            return true
        }()

        return HStack(spacing: 14) {
            // LEFT PRIMARY PANEL: Offensive Targeting Radar + Tactical Ordnance Deck
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "dot.radiowaves.Forward")
                                .foregroundStyle(NavalTheme.sonarCyan)
                            Text("OFFENSIVE TARGETING RADAR // ENEMY WATERS")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .foregroundStyle(NavalTheme.sonarCyan)
                        }
                        Text(
                            isGameOver
                                ? "All enemy vessel positions revealed — Click 'NEW OP' for rematch"
                                : "Click an unexplored enemy sector to launch ordnance"
                        )
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NavalTheme.textSecondary)
                    }

                    Spacer()

                    // Enemy Fleet Remaining Badge
                    let survivingEnemy = engine.activeTargetBoard.survivingShipsCount
                    HStack(spacing: 6) {
                        Text("HOSTILES AFLOAT:")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(NavalTheme.textSecondary)
                        Text("\(survivingEnemy)/5")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(survivingEnemy == 0 ? NavalTheme.radarEmerald : NavalTheme.threatCrimson)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(NavalTheme.bgPanelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer(minLength: 0)

                ZStack {
                    TacticalGridView(
                        role: .offensiveRadar,
                        board: engine.activeTargetBoard,
                        cellSize: 39,
                        showShips: isGameOver, // Reveal remaining ships when game ends
                        showProbabilityHeatmap: engine.showProbabilityOverlay,
                        probabilityMap: engine.targetProbabilityMap,
                        fxEvents: engine.offensiveFXEvents,
                        activeWeapon: engine.combatRules == .tactical ? engine.selectedWeapon : .standardTorpedo,
                        weaponOrientation: engine.weaponOrientation,
                        isInteractive: canFire,
                        onCellTap: { coord in
                            engine.fireAtEnemy(coordinate: coord)
                        }
                    )

                    if case .gameOver(let winnerIdx, let winnerName) = engine.phase {
                        gameOverBannerOverlay(winnerIdx: winnerIdx, winnerName: winnerName)
                    }
                }

                Spacer(minLength: 0)

                // Tactical Weapon Deck (shown in Tactical Ops mode, or Status strip in Classic/Salvo)
                ordnanceControlBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .background(NavalTheme.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(NavalTheme.sonarCyan.opacity(0.32), lineWidth: 1)
            )

            // RIGHT SECONDARY PANEL: Friendly Defensive Grid + Fleet Status Matrix + Combat Log
            VStack(spacing: 12) {
                // Top Right: Friendly Defensive Radar + Dual Fleet Telemetry
                HStack(alignment: .top, spacing: 12) {
                    // Defensive Radar (Friendly Fleet)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("FRIENDLY FLEET RADAR")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(NavalTheme.radarEmerald)
                            Spacer()
                            Text("\(engine.activeFriendlyBoard.survivingShipsCount)/5 INTACT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(NavalTheme.radarEmerald)
                        }

                        TacticalGridView(
                            role: .defensiveFleet,
                            board: engine.activeFriendlyBoard,
                            cellSize: 25,
                            showShips: true,
                            fxEvents: engine.defensiveFXEvents,
                            isInteractive: false,
                            onCellTap: { _ in }
                        )
                    }
                    .padding(10)
                    .background(NavalTheme.bgDeep.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NavalTheme.radarEmerald.opacity(0.28), lineWidth: 1)
                    )

                    // Fleet Integrity Matrix (Enemy & Friendly)
                    VStack(alignment: .leading, spacing: 10) {
                        fleetStatusCard(
                            title: "HOSTILE TARGETS",
                            ships: engine.activeTargetBoard.ships,
                            accent: NavalTheme.threatCrimson,
                            hideExactDamage: true
                        )

                        fleetStatusCard(
                            title: "FRIENDLY VESSELS",
                            ships: engine.activeFriendlyBoard.ships,
                            accent: NavalTheme.radarEmerald,
                            hideExactDamage: false
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                // Bottom Right: Live Telemetry Combat Log
                combatTelemetryLogPanel
            }
            .frame(width: 500)
        }
    }

    // MARK: - Ordnance Control Bar

    @ViewBuilder
    private var ordnanceControlBar: some View {
        let activeIdx = engine.activeHumanIndex
        let charges = engine.weaponCharges[activeIdx]

        if engine.combatRules == .tactical {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TACTICAL ORDNANCE DECK")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(NavalTheme.sonarCyan)
                    Spacer()
                    if engine.selectedWeapon == .airstrike {
                        Button {
                            engine.rotateActiveOrientation()
                        } label: {
                            Text("ROTATE AIRSTRIKE AXIS: \(engine.weaponOrientation.shortCode) (R)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(NavalTheme.warningAmber)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(engine.selectedWeapon.detailText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(NavalTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(TacticalWeapon.allCases) { weapon in
                        let count = charges[weapon] ?? 0
                        let isSelected = (engine.selectedWeapon == weapon)
                        let isAvailable = count > 0

                        Button {
                            guard isAvailable else { return }
                            SoundEngine.shared.play(.targetClick)
                            engine.selectedWeapon = weapon
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: weapon.iconName)
                                    .font(.system(size: 12, weight: .bold))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(weapon.shortName)
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    Text(weapon == .standardTorpedo ? "UNLIMITED" : "×\(count) LEFT")
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .opacity(0.8)
                                }
                            }
                            .foregroundStyle(
                                !isAvailable
                                    ? NavalTheme.textMuted
                                    : (isSelected ? NavalTheme.bgDeep : NavalTheme.textPrimary)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 6)
                            .background(
                                isSelected
                                    ? NavalTheme.sonarCyan
                                    : NavalTheme.bgPanelElevated.opacity(isAvailable ? 1.0 : 0.45)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        isSelected ? NavalTheme.sonarCyan : NavalTheme.sonarCyan.opacity(0.25),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isAvailable)
                    }
                }
            }
            .padding(10)
            .background(NavalTheme.bgDeep.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            // Classic / Salvo Telemetry Strip
            let totalShots = engine.activeTargetBoard.shots.count
            let hits = engine.activeTargetBoard.shots.values.filter { $0 == .hit || $0 == .sunk }.count
            let acc = totalShots > 0 ? Int((Double(hits) / Double(totalShots) * 100.0).rounded()) : 0

            HStack(spacing: 18) {
                metricPill(label: "MODE", value: engine.combatRules.rawValue.uppercased(), color: NavalTheme.sonarCyan)
                metricPill(label: "TORPEDOES FIRED", value: "\(totalShots)", color: NavalTheme.textPrimary)
                metricPill(label: "DIRECT HITS", value: "\(hits)", color: NavalTheme.warningAmber)
                metricPill(label: "HIT ACCURACY", value: "\(acc)%", color: NavalTheme.radarEmerald)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(NavalTheme.bgDeep.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(NavalTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Fleet Status Card

    private func fleetStatusCard(
        title: String,
        ships: [PlacedShip],
        accent: Color,
        hideExactDamage: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)

            ForEach(ShipType.allCases) { type in
                let ship = ships.first { $0.type == type }
                let isSunk = ship?.isSunk ?? false
                let hitsCount = ship?.hits.count ?? 0

                HStack(spacing: 6) {
                    Text(type.hullClassification)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSunk ? NavalTheme.threatCrimson : NavalTheme.textPrimary)
                        .frame(width: 44, alignment: .leading)

                    // Hull pips
                    HStack(spacing: 3) {
                        ForEach(0..<type.length, id: \.self) { pipIdx in
                            let isDamaged = isSunk || (!hideExactDamage && pipIdx < hitsCount)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    isSunk
                                        ? NavalTheme.threatCrimson
                                        : (isDamaged ? NavalTheme.warningAmber : accent.opacity(0.75))
                                )
                                .frame(width: 11, height: 6)
                        }
                    }

                    Spacer()

                    Text(isSunk ? "SUNK" : "ACTIVE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isSunk ? NavalTheme.threatCrimson : NavalTheme.radarEmerald)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .background(NavalTheme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: - Combat Telemetry Log Panel

    private var combatTelemetryLogPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("COMBAT TELEMETRY FEED", systemImage: "terminal.fill")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NavalTheme.sonarCyan)
                Spacer()
                Text("\(engine.combatLogs.count) EVENTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(NavalTheme.textMuted)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(engine.combatLogs) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text("[T\(String(format: "%02d", entry.turn))]")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(NavalTheme.textMuted)

                            Text("\(entry.actor):")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(logColor(for: entry.category))

                            Text(entry.message)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(NavalTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NavalTheme.bgDeep.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NavalTheme.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(NavalTheme.sonarCyan.opacity(0.25), lineWidth: 1)
        )
    }

    private func logColor(for category: CombatLogEntry.Category) -> Color {
        switch category {
        case .info: return NavalTheme.sonarCyan
        case .hit: return NavalTheme.warningAmber
        case .sunk: return NavalTheme.threatCrimson
        case .miss: return NavalTheme.textSecondary
        case .radar: return NavalTheme.radarEmerald
        case .warning: return NavalTheme.warningAmber
        }
    }

    // MARK: - Game Over Banner Overlay

    private func gameOverBannerOverlay(winnerIdx: Int, winnerName: String) -> some View {
        let playerWon = (winnerIdx == 0)
        let accent = playerWon ? NavalTheme.radarEmerald : NavalTheme.threatCrimson

        return VStack(spacing: 12) {
            Image(systemName: playerWon ? "trophy.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(accent)

            Text(playerWon ? "NAVAL VICTORY ACHIEVED" : "FLEET DEFEATED")
                .font(.system(size: 19, weight: .heavy, design: .monospaced))
                .foregroundStyle(NavalTheme.textPrimary)
                .tracking(1.5)

            Text("\(winnerName) PREVAILED ON TURN \(engine.turnNumber)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)

            Button {
                SoundEngine.shared.play(.sonarPing)
                engine.startNewOperation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("DEPLOY NEW OPERATION")
                }
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(NavalTheme.bgDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .background(NavalTheme.bgDeep.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.75), radius: 20)
    }

    // MARK: - Career Stats Popover

    private var careerStatsPopover: some View {
        let stats = engine.careerStats
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundStyle(NavalTheme.warningAmber)
                Text("SERVICE RECORD // CAREER STATS")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NavalTheme.textPrimary)
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    statItem(title: "OPERATIONS", value: "\(stats.gamesPlayed)")
                    statItem(title: "VICTORIES", value: "\(stats.victories)")
                    statItem(title: "WIN RATE", value: "\(stats.winRatePercentage)%")
                }
                GridRow {
                    statItem(title: "ACCURACY", value: "\(stats.accuracyPercentage)%")
                    statItem(title: "SHIPS SUNK", value: "\(stats.enemyShipsSunk)")
                    statItem(
                        title: "FASTEST WIN",
                        value: stats.fastestVictoryTurns.map { "\($0) TURNS" } ?? "—"
                    )
                }
                GridRow {
                    statItem(title: "WIN STREAK", value: "\(stats.currentWinStreak)")
                    statItem(title: "BEST STREAK", value: "\(stats.bestWinStreak)")
                    statItem(title: "SHOTS FIRED", value: "\(stats.totalShotsFired)")
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Reset Service Record") {
                    engine.resetCareerStats()
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(NavalTheme.threatCrimson)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(NavalTheme.bgPanel)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(NavalTheme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(NavalTheme.sonarCyan)
        }
    }
}
