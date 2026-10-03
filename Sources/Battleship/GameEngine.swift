import Foundation
import SwiftUI

@MainActor
public final class GameEngine: ObservableObject {
    public enum Phase: Equatable {
        case setup(playerIndex: Int)          // 0 = Player 1, 1 = Player 2
        case passScreen(nextPlayerIndex: Int, reason: String)
        case combat(activePlayerIndex: Int)   // 0 = Player 1, 1 = Player 2 or AI
        case gameOver(winnerIndex: Int, winnerName: String)
    }

    // Configuration
    @Published public var gameMode: GameMode = .vsAI(.commander)
    @Published public var combatRules: CombatRules = .classic
    @Published public var showProbabilityOverlay: Bool = false

    // State
    @Published public var phase: Phase = .setup(playerIndex: 0)
    @Published public var boards: [NavalBoard] = [NavalBoard(), NavalBoard()]
    @Published public var turnNumber: Int = 1
    @Published public var shotsRemainingInTurn: Int = 1

    // Setup state
    @Published public var selectedShipForPlacement: ShipType = .carrier
    @Published public var placementOrientation: ShipOrientation = .horizontal
    @Published public var hoveredCoordinate: Coordinate? = nil

    // Tactical Weapon state (per player index 0 and 1)
    @Published public var selectedWeapon: TacticalWeapon = .standardTorpedo
    @Published public var weaponOrientation: ShipOrientation = .horizontal
    @Published public var weaponCharges: [[TacticalWeapon: Int]] = [[:], [:]]

    // Telemetry & FX
    @Published public var combatLogs: [CombatLogEntry] = []
    @Published public var offensiveFXEvents: [ImpactAnimationEvent] = []
    @Published public var defensiveFXEvents: [ImpactAnimationEvent] = []
    @Published public var latestBannerMessage: String = "DEPLOY FLEET TO COMMENCE NAVAL OPERATION"
    @Published public var latestBannerCategory: CombatLogEntry.Category = .info
    @Published public var isAITurnInProgress: Bool = false

    // Persistent Career Stats
    @Published public var careerStats: CareerStats = CareerStats.load()

    // Cached probability map for the active target board
    @Published public var targetProbabilityMap: [[Double]] = Array(
        repeating: Array(repeating: 0.0, count: Coordinate.gridSize),
        count: Coordinate.gridSize
    )

    private var aiTask: Task<Void, Never>? = nil

    public init() {
        startNewOperation()
    }

    // MARK: - Player Helpers

    public func playerName(for index: Int) -> String {
        if index == 0 {
            return gameMode == .passAndPlay ? "COMMANDER ALPHA" : "FLEET COMMAND"
        } else {
            switch gameMode {
            case .vsAI(let diff):
                return "OPFOR AI (\(diff.rawValue.uppercased()))"
            case .passAndPlay:
                return "COMMANDER BRAVO"
            }
        }
    }

    public var activeHumanIndex: Int {
        switch phase {
        case .setup(let idx):
            return idx
        case .passScreen(let nextIdx, _):
            return nextIdx
        case .combat(let idx):
            return gameMode == .passAndPlay ? idx : 0
        case .gameOver:
            return 0
        }
    }

    public var opponentIndex: Int {
        1 - activeHumanIndex
    }

    public var activeFriendlyBoard: NavalBoard {
        boards[activeHumanIndex]
    }

    public var activeTargetBoard: NavalBoard {
        boards[opponentIndex]
    }

    // MARK: - Game Lifecycle

    public func startNewOperation() {
        aiTask?.cancel()
        isAITurnInProgress = false

        var board0 = NavalBoard()
        board0.randomizeFleet(preferSpaced: true)
        var board1 = NavalBoard()
        board1.randomizeFleet(preferSpaced: true)

        boards = [board0, board1]
        turnNumber = 1
        selectedShipForPlacement = .carrier
        placementOrientation = .horizontal
        selectedWeapon = .standardTorpedo
        weaponOrientation = .horizontal
        weaponCharges = [
            Self.initialWeaponLoadout(for: combatRules),
            Self.initialWeaponLoadout(for: combatRules)
        ]
        combatLogs.removeAll()
        offensiveFXEvents.removeAll()
        defensiveFXEvents.removeAll()

        phase = .setup(playerIndex: 0)
        latestBannerMessage = "FLEET DRYDOCK READY — POSITION VESSELS OR COMMENCE OPERATION"
        latestBannerCategory = .info

        appendLog(
            actor: "SYSTEM",
            message: "Initialized \(gameMode.displayTitle) • Rules: \(combatRules.rawValue)",
            category: .info
        )
        refreshProbabilityMap()
    }

    private static func initialWeaponLoadout(for rules: CombatRules) -> [TacticalWeapon: Int] {
        var dict: [TacticalWeapon: Int] = [:]
        for weapon in TacticalWeapon.allCases {
            if rules == .tactical {
                dict[weapon] = weapon.initialCharges
            } else {
                dict[weapon] = weapon == .standardTorpedo ? 999 : 0
            }
        }
        return dict
    }

    // MARK: - Fleet Setup Actions

    public func rotateActiveOrientation() {
        SoundEngine.shared.play(.targetClick)
        if case .setup(let idx) = phase {
            placementOrientation = placementOrientation.toggled
            // If hovered over or selected an already-placed ship, try rotating it in place if not hovering
            if hoveredCoordinate == nil, let existing = boards[idx].ship(ofType: selectedShipForPlacement) {
                if boards[idx].canPlaceShip(
                    type: existing.type,
                    origin: existing.origin,
                    orientation: existing.orientation.toggled
                ) {
                    boards[idx].placeShip(
                        type: existing.type,
                        origin: existing.origin,
                        orientation: existing.orientation.toggled
                    )
                    placementOrientation = existing.orientation.toggled
                }
            }
        } else {
            weaponOrientation = weaponOrientation.toggled
        }
    }

    public func randomizeSetupFleet() {
        guard case .setup(let idx) = phase else { return }
        SoundEngine.shared.play(.sonarPing)
        boards[idx].randomizeFleet(preferSpaced: true)
        latestBannerMessage = "\(playerName(for: idx)): FLEET DEPLOYED IN TACTICAL FORMATION"
        latestBannerCategory = .radar
    }

    public func clearSetupFleet() {
        guard case .setup(let idx) = phase else { return }
        SoundEngine.shared.play(.targetClick)
        boards[idx].clearAll()
        selectedShipForPlacement = .carrier
        latestBannerMessage = "DRYDOCK CLEARED — PLACE ALL 5 VESSELS ON THE GRID"
        latestBannerCategory = .info
    }

    public func handleSetupGridClick(at coordinate: Coordinate) {
        guard case .setup(let idx) = phase else { return }

        // If user clicked an existing ship of a different type, select it or place current ship if empty
        if boards[idx].canPlaceShip(
            type: selectedShipForPlacement,
            origin: coordinate,
            orientation: placementOrientation
        ) {
            boards[idx].placeShip(
                type: selectedShipForPlacement,
                origin: coordinate,
                orientation: placementOrientation
            )
            SoundEngine.shared.play(.targetClick)
            latestBannerMessage = "DEPLOYED \(selectedShipForPlacement.hullName.uppercased()) (\(selectedShipForPlacement.hullClassification)) AT \(coordinate.notation)"
            latestBannerCategory = .info

            // Automatically select the next unplaced ship if any
            if let nextUnplaced = ShipType.allCases.first(where: { boards[idx].ship(ofType: $0) == nil }) {
                selectedShipForPlacement = nextUnplaced
            }
        } else if let tappedShip = boards[idx].ship(at: coordinate) {
            selectedShipForPlacement = tappedShip.type
            placementOrientation = tappedShip.orientation
            SoundEngine.shared.play(.targetClick)
            latestBannerMessage = "SELECTED \(tappedShip.type.hullName.uppercased()) — CLICK NEW SECTOR TO REPOSITION OR PRESS R"
            latestBannerCategory = .info
        } else {
            SoundEngine.shared.play(.waterSplash)
            latestBannerMessage = "INVALID PLACEMENT AT \(coordinate.notation) — HULL EXTENDS OUT OF BOUNDS OR OVERLAPS"
            latestBannerCategory = .warning
        }
    }

    public func confirmSetupDeployment() {
        guard case .setup(let idx) = phase else { return }
        guard boards[idx].isFleetComplete else {
            latestBannerMessage = "ALL 5 NAVAL VESSELS MUST BE DEPLOYED BEFORE LAUNCH"
            latestBannerCategory = .warning
            return
        }

        SoundEngine.shared.play(.sonarPing)

        if gameMode == .passAndPlay && idx == 0 {
            selectedShipForPlacement = .carrier
            placementOrientation = .horizontal
            phase = .passScreen(
                nextPlayerIndex: 1,
                reason: "PASS COMMAND CONSOLE TO COMMANDER BRAVO FOR FLEET DEPLOYMENT"
            )
        } else if gameMode == .passAndPlay && idx == 1 {
            beginCombat(startingPlayer: 0, showPassScreenFirst: true)
        } else {
            beginCombat(startingPlayer: 0, showPassScreenFirst: false)
        }
    }

    public func proceedFromPassScreen() {
        guard case .passScreen(let nextIdx, _) = phase else { return }
        SoundEngine.shared.play(.targetClick)
        if !boards[nextIdx].isFleetComplete || (turnNumber == 1 && nextIdx == 1 && boards[1].shots.isEmpty && boards[0].shots.isEmpty && phase != .combat(activePlayerIndex: nextIdx)) {
            // Check if player 2 still needs setup or if both fleets are ready and combat is starting
            if turnNumber == 1 && boards[0].shots.isEmpty && boards[1].shots.isEmpty {
                // If we came from Player 1 setup, go to Player 2 setup; if we came from Player 2 setup, start combat(0)
                if nextIdx == 1 {
                    phase = .setup(playerIndex: 1)
                    latestBannerMessage = "COMMANDER BRAVO: DEPLOY YOUR FLEET"
                    latestBannerCategory = .info
                    return
                }
            }
        }
        phase = .combat(activePlayerIndex: nextIdx)
        shotsRemainingInTurn = computeShotsPerTurn(for: nextIdx)
        selectedWeapon = .standardTorpedo
        refreshProbabilityMap()
        latestBannerMessage = "\(playerName(for: nextIdx)) — WEAPONS FREE (\(shotsRemainingInTurn) \(shotsRemainingInTurn == 1 ? "SHOT" : "SHOTS") READY)"
        latestBannerCategory = .info
    }

    private func beginCombat(startingPlayer: Int, showPassScreenFirst: Bool) {
        turnNumber = 1
        shotsRemainingInTurn = computeShotsPerTurn(for: startingPlayer)
        selectedWeapon = .standardTorpedo
        refreshProbabilityMap()

        if showPassScreenFirst {
            phase = .passScreen(
                nextPlayerIndex: startingPlayer,
                reason: "BOTH FLEETS DEPLOYED — PASS CONSOLE TO \(playerName(for: startingPlayer)) TO COMMENCE COMBAT"
            )
        } else {
            phase = .combat(activePlayerIndex: startingPlayer)
            latestBannerMessage = "COMBAT ENGAGED — TARGET ENEMY SECTOR ON OFFENSIVE RADAR"
            latestBannerCategory = .info
            appendLog(
                actor: "COMMAND",
                message: "All vessels at general quarters. Offensive weapons online.",
                category: .info
            )
        }
    }

    public func computeShotsPerTurn(for playerIdx: Int) -> Int {
        switch combatRules {
        case .classic, .tactical:
            return 1
        case .salvo:
            return max(1, boards[playerIdx].survivingShipsCount)
        }
    }

    // MARK: - Combat Actions

    public func fireAtEnemy(coordinate: Coordinate) {
        guard case .combat(let activeIdx) = phase else { return }
        guard !isAITurnInProgress else { return }
        let targetIdx = 1 - activeIdx

        let weapon = (combatRules == .tactical) ? selectedWeapon : .standardTorpedo
        let availableCharges = weaponCharges[activeIdx][weapon] ?? 0
        guard availableCharges > 0 else {
            latestBannerMessage = "NO CHARGES REMAINING FOR \(weapon.rawValue.uppercased())"
            latestBannerCategory = .warning
            return
        }

        if weapon == .sonarPing {
            executeSonarPing(at: coordinate, attackerIdx: activeIdx, targetIdx: targetIdx)
            return
        }

        let targetCoords = weapon.affectedCoordinates(center: coordinate, orientation: weaponOrientation)
        let validUntargeted = targetCoords.filter { boards[targetIdx].shots[$0] == nil }

        guard !validUntargeted.isEmpty else {
            SoundEngine.shared.play(.targetClick)
            latestBannerMessage = "SECTOR \(coordinate.notation) ALREADY TARGETED — SELECT UNEXPLORED COORDINATES"
            latestBannerCategory = .warning
            return
        }

        // Consume weapon charge if special weapon
        if weapon != .standardTorpedo {
            weaponCharges[activeIdx][weapon] = max(0, availableCharges - 1)
            selectedWeapon = .standardTorpedo
        }

        var hitsCount = 0
        var sunkShips: [PlacedShip] = []

        for coord in validUntargeted {
            let result = boards[targetIdx].receiveShot(at: coord)
            if activeIdx == 0 {
                careerStats.totalShotsFired += 1
            }

            switch result {
            case .miss(let c):
                offensiveFXEvents.append(ImpactAnimationEvent(coordinate: c, kind: .miss))
            case .hit(let c, _):
                hitsCount += 1
                if activeIdx == 0 { careerStats.totalHits += 1 }
                offensiveFXEvents.append(ImpactAnimationEvent(coordinate: c, kind: .hit))
            case .sunk(let c, let ship):
                hitsCount += 1
                sunkShips.append(ship)
                if activeIdx == 0 {
                    careerStats.totalHits += 1
                    careerStats.enemyShipsSunk += 1
                }
                for sc in ship.coordinates {
                    offensiveFXEvents.append(ImpactAnimationEvent(coordinate: sc, kind: .sunk))
                }
                offensiveFXEvents.append(ImpactAnimationEvent(coordinate: c, kind: .sunk))
            default:
                break
            }
        }

        pruneExpiredFX()
        refreshProbabilityMap()

        // Audio & Log feedback
        let actor = playerName(for: activeIdx)
        if let sunk = sunkShips.first {
            SoundEngine.shared.play(.shipSunk)
            let msg = "DIRECT HIT AT \(coordinate.notation) — SUNK ENEMY \(sunk.type.hullName.uppercased()) (\(sunk.type.hullClassification))!"
            latestBannerMessage = msg
            latestBannerCategory = .sunk
            appendLog(actor: actor, message: msg, category: .sunk)
        } else if hitsCount > 0 {
            SoundEngine.shared.play(.explosionHit)
            let msg = validUntargeted.count > 1
                ? "\(weapon.shortName) AT \(coordinate.notation) — \(hitsCount) HULL \(hitsCount == 1 ? "IMPACT" : "IMPACTS") CONFIRMED!"
                : "TORPEDO IMPACT AT \(coordinate.notation) — DIRECT HIT ON ENEMY VESSEL!"
            latestBannerMessage = msg
            latestBannerCategory = .hit
            appendLog(actor: actor, message: msg, category: .hit)
        } else {
            SoundEngine.shared.play(.waterSplash)
            let msg = "\(weapon.shortName) AT \(coordinate.notation) — MISS (OPEN WATER)"
            latestBannerMessage = msg
            latestBannerCategory = .miss
            appendLog(actor: actor, message: msg, category: .miss)
        }

        // Check victory condition
        if boards[targetIdx].allShipsSunk {
            handleGameOver(winnerIndex: activeIdx)
            return
        }

        // Advance salvo or end turn
        shotsRemainingInTurn -= 1
        if shotsRemainingInTurn <= 0 {
            advanceTurn(from: activeIdx)
        }
    }

    private func executeSonarPing(at center: Coordinate, attackerIdx: Int, targetIdx: Int) {
        let charges = weaponCharges[attackerIdx][.sonarPing] ?? 0
        guard charges > 0 else { return }

        weaponCharges[attackerIdx][.sonarPing] = charges - 1
        selectedWeapon = .standardTorpedo

        let scanResults = boards[targetIdx].performSonarScan(center: center)
        for coord in scanResults.keys {
            offensiveFXEvents.append(ImpactAnimationEvent(coordinate: coord, kind: .sonar))
        }
        pruneExpiredFX()
        refreshProbabilityMap()

        let positiveCount = scanResults.values.filter { $0 }.count
        SoundEngine.shared.play(.sonarPing)

        let msg = positiveCount > 0
            ? "SONAR PING AT \(center.notation): \(positiveCount) HULL \(positiveCount == 1 ? "SIGNATURE" : "SIGNATURES") DETECTED IN 3×3 SECTOR!"
            : "SONAR PING AT \(center.notation): SECTOR CLEAR — NO HULL SIGNATURES"
        latestBannerMessage = msg
        latestBannerCategory = .radar
        appendLog(actor: playerName(for: attackerIdx), message: msg, category: .radar)

        shotsRemainingInTurn -= 1
        if shotsRemainingInTurn <= 0 {
            advanceTurn(from: attackerIdx)
        }
    }

    private func advanceTurn(from previousIdx: Int) {
        let nextIdx = 1 - previousIdx
        if nextIdx == 0 {
            turnNumber += 1
        }

        switch gameMode {
        case .passAndPlay:
            phase = .passScreen(
                nextPlayerIndex: nextIdx,
                reason: "TURN COMPLETE — PASS CONSOLE TO \(playerName(for: nextIdx))"
            )

        case .vsAI(let difficulty):
            if nextIdx == 1 {
                phase = .combat(activePlayerIndex: 1)
                isAITurnInProgress = true
                let aiShots = computeShotsPerTurn(for: 1)
                shotsRemainingInTurn = aiShots

                aiTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    for shotIndex in 0..<aiShots {
                        try? await Task.sleep(nanoseconds: shotIndex == 0 ? 520_000_000 : 380_000_000)
                        guard !Task.isCancelled else { return }
                        let targetCoord = NavalAI.selectTarget(on: self.boards[0], difficulty: difficulty)
                        let result = self.boards[0].receiveShot(at: targetCoord)
                        self.recordAIShotResult(result, difficulty: difficulty)

                        if self.boards[0].allShipsSunk {
                            self.isAITurnInProgress = false
                            self.handleGameOver(winnerIndex: 1)
                            return
                        }
                    }

                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    self.turnNumber += 1
                    self.isAITurnInProgress = false
                    self.phase = .combat(activePlayerIndex: 0)
                    self.shotsRemainingInTurn = self.computeShotsPerTurn(for: 0)
                    self.refreshProbabilityMap()
                }
            }
        }
    }

    private func recordAIShotResult(_ result: ShotResult, difficulty: AIDifficulty) {
        let aiActor = "OPFOR (\(difficulty.rawValue.uppercased()))"
        switch result {
        case .miss(let coord):
            defensiveFXEvents.append(ImpactAnimationEvent(coordinate: coord, kind: .miss))
            SoundEngine.shared.play(.waterSplash)
            appendLog(actor: aiActor, message: "Fired torpedo at \(coord.notation) — Missed friendly fleet.", category: .miss)

        case .hit(let coord, let shipType):
            defensiveFXEvents.append(ImpactAnimationEvent(coordinate: coord, kind: .hit))
            SoundEngine.shared.play(.explosionHit)
            let msg = "ALERT: Enemy torpedo hit friendly \(shipType.hullName) at \(coord.notation)!"
            latestBannerMessage = msg.uppercased()
            latestBannerCategory = .warning
            appendLog(actor: aiActor, message: msg, category: .hit)

        case .sunk(let coord, let ship):
            for sc in ship.coordinates {
                defensiveFXEvents.append(ImpactAnimationEvent(coordinate: sc, kind: .sunk))
            }
            SoundEngine.shared.play(.shipSunk)
            let msg = "CRITICAL: Friendly \(ship.type.hullName) (\(ship.type.hullClassification)) SUNK at \(coord.notation)!"
            latestBannerMessage = msg
            latestBannerCategory = .sunk
            appendLog(actor: aiActor, message: msg, category: .sunk)

        default:
            break
        }
        pruneExpiredFX()
    }

    private func handleGameOver(winnerIndex: Int) {
        let winner = playerName(for: winnerIndex)
        phase = .gameOver(winnerIndex: winnerIndex, winnerName: winner)

        if winnerIndex == 0 {
            SoundEngine.shared.play(.victoryFanfare)
            latestBannerMessage = "VICTORY! ALL ENEMY VESSELS NEUTRALIZED IN \(turnNumber) TURNS!"
            latestBannerCategory = .sunk
            careerStats.gamesPlayed += 1
            careerStats.victories += 1
            careerStats.currentWinStreak += 1
            careerStats.bestWinStreak = max(careerStats.bestWinStreak, careerStats.currentWinStreak)
            if let fastest = careerStats.fastestVictoryTurns {
                careerStats.fastestVictoryTurns = min(fastest, turnNumber)
            } else {
                careerStats.fastestVictoryTurns = turnNumber
            }
            careerStats.save()
        } else {
            SoundEngine.shared.play(.defeatAlarm)
            latestBannerMessage = "FLEET LOST — \(winner) ACHIEVED NAVAL SUPREMACY"
            latestBannerCategory = .warning
            if gameMode != .passAndPlay {
                careerStats.gamesPlayed += 1
                careerStats.defeats += 1
                careerStats.currentWinStreak = 0
                careerStats.save()
            }
        }

        appendLog(
            actor: "COMMAND",
            message: "Operation concluded on Turn \(turnNumber). Winner: \(winner).",
            category: winnerIndex == 0 ? .sunk : .warning
        )
    }

    public func resetCareerStats() {
        careerStats = CareerStats()
        careerStats.save()
    }

    // MARK: - Helpers

    public func refreshProbabilityMap() {
        targetProbabilityMap = NavalAI.computeProbabilityMap(for: activeTargetBoard)
    }

    private func pruneExpiredFX() {
        let cutoff = Date().addingTimeInterval(-1.5)
        offensiveFXEvents.removeAll { $0.createdAt < cutoff }
        defensiveFXEvents.removeAll { $0.createdAt < cutoff }
    }

    private func appendLog(actor: String, message: String, category: CombatLogEntry.Category) {
        let entry = CombatLogEntry(
            turn: turnNumber,
            actor: actor,
            message: message,
            category: category
        )
        combatLogs.insert(entry, at: 0)
        if combatLogs.count > 80 {
            combatLogs.removeLast(combatLogs.count - 80)
        }
    }
}
