import Foundation

// MARK: - Grid Coordinate

public struct Coordinate: Hashable, Codable, Sendable, CustomStringConvertible {
    public static let gridSize = 10
    public static let rowLetters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]

    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    public var isValid: Bool {
        row >= 0 && row < Self.gridSize && col >= 0 && col < Self.gridSize
    }

    public var rowLabel: String {
        guard row >= 0 && row < Self.rowLetters.count else { return "?" }
        return Self.rowLetters[row]
    }

    public var colLabel: String {
        "\(col + 1)"
    }

    public var notation: String {
        "\(rowLabel)-\(String(format: "%02d", col + 1))"
    }

    public var compactNotation: String {
        "\(rowLabel)\(col + 1)"
    }

    public var description: String {
        compactNotation
    }

    public var orthogonalNeighbors: [Coordinate] {
        [
            Coordinate(row: row - 1, col: col),
            Coordinate(row: row + 1, col: col),
            Coordinate(row: row, col: col - 1),
            Coordinate(row: row, col: col + 1)
        ].filter(\.isValid)
    }

    public var surrounding3x3: [Coordinate] {
        var result: [Coordinate] = []
        for dr in -1...1 {
            for dc in -1...1 {
                let coord = Coordinate(row: row + dr, col: col + dc)
                if coord.isValid {
                    result.append(coord)
                }
            }
        }
        return result
    }

    public var crossPattern: [Coordinate] {
        [
            self,
            Coordinate(row: row - 1, col: col),
            Coordinate(row: row + 1, col: col),
            Coordinate(row: row, col: col - 1),
            Coordinate(row: row, col: col + 1)
        ].filter(\.isValid)
    }

    public func lineSegment(orientation: ShipOrientation, length: Int = 3) -> [Coordinate] {
        let half = length / 2
        return (-half...(length - 1 - half)).compactMap { offset in
            let c = orientation == .horizontal
                ? Coordinate(row: row, col: col + offset)
                : Coordinate(row: row + offset, col: col)
            return c.isValid ? c : nil
        }
    }
}

// MARK: - Ships & Orientation

public enum ShipOrientation: String, Codable, CaseIterable, Sendable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"

    public var toggled: ShipOrientation {
        self == .horizontal ? .vertical : .horizontal
    }

    public var shortCode: String {
        self == .horizontal ? "HORZ" : "VERT"
    }
}

public enum ShipType: String, CaseIterable, Codable, Identifiable, Sendable {
    case carrier = "Carrier"
    case battleship = "Battleship"
    case cruiser = "Cruiser"
    case submarine = "Submarine"
    case destroyer = "Destroyer"

    public var id: String { rawValue }

    public var hullName: String {
        switch self {
        case .carrier: return "USS Enterprise"
        case .battleship: return "USS Iowa"
        case .cruiser: return "USS Ticonderoga"
        case .submarine: return "USS Seawolf"
        case .destroyer: return "USS Arleigh Burke"
        }
    }

    public var hullClassification: String {
        switch self {
        case .carrier: return "CVN-65"
        case .battleship: return "BB-61"
        case .cruiser: return "CG-47"
        case .submarine: return "SSN-21"
        case .destroyer: return "DDG-51"
        }
    }

    public var length: Int {
        switch self {
        case .carrier: return 5
        case .battleship: return 4
        case .cruiser: return 3
        case .submarine: return 3
        case .destroyer: return 2
        }
    }

    public var roleDescription: String {
        switch self {
        case .carrier: return "Fleet Flagship Carrier"
        case .battleship: return "Heavy Dreadnought"
        case .cruiser: return "Aegis Guided-Missile Cruiser"
        case .submarine: return "Fast Attack Submarine"
        case .destroyer: return "Stealth Escort Destroyer"
        }
    }
}

public struct PlacedShip: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let type: ShipType
    public var origin: Coordinate
    public var orientation: ShipOrientation
    public var hits: Set<Coordinate>

    public init(
        id: UUID = UUID(),
        type: ShipType,
        origin: Coordinate,
        orientation: ShipOrientation,
        hits: Set<Coordinate> = []
    ) {
        self.id = id
        self.type = type
        self.origin = origin
        self.orientation = orientation
        self.hits = hits
    }

    public var coordinates: [Coordinate] {
        Self.computeCoordinates(origin: origin, length: type.length, orientation: orientation)
    }

    public static func computeCoordinates(
        origin: Coordinate,
        length: Int,
        orientation: ShipOrientation
    ) -> [Coordinate] {
        (0..<length).map { offset in
            switch orientation {
            case .horizontal:
                return Coordinate(row: origin.row, col: origin.col + offset)
            case .vertical:
                return Coordinate(row: origin.row + offset, col: origin.col)
            }
        }
    }

    public var isSunk: Bool {
        hits.count >= type.length
    }

    public var remainingHealth: Int {
        max(0, type.length - hits.count)
    }

    public var integrityFraction: Double {
        Double(remainingHealth) / Double(type.length)
    }

    public func occupies(_ coord: Coordinate) -> Bool {
        coordinates.contains(coord)
    }
}

// MARK: - Shot & Cell State

public enum ShotOutcome: String, Codable, Equatable, Sendable {
    case miss
    case hit
    case sunk
}

public enum ShotResult: Equatable, Sendable {
    case miss(Coordinate)
    case hit(Coordinate, ShipType)
    case sunk(Coordinate, PlacedShip)
    case alreadyTargeted(Coordinate)
    case invalidCoordinate(Coordinate)

    public var isValidShot: Bool {
        switch self {
        case .miss, .hit, .sunk:
            return true
        case .alreadyTargeted, .invalidCoordinate:
            return false
        }
    }

    public var wasHitOrSunk: Bool {
        switch self {
        case .hit, .sunk:
            return true
        default:
            return false
        }
    }
}

// MARK: - Naval Board

public struct NavalBoard: Equatable, Codable, Sendable {
    public var ships: [PlacedShip] = []
    public var shots: [Coordinate: ShotOutcome] = [:]
    public var radarContacts: [Coordinate: Bool] = [:] // true = ship detected, false = clear water

    public init(ships: [PlacedShip] = []) {
        self.ships = ships
    }

    public var isFleetComplete: Bool {
        let placedTypes = Set(ships.map(\.type))
        return placedTypes.count == ShipType.allCases.count
    }

    public var allShipsSunk: Bool {
        !ships.isEmpty && ships.allSatisfy(\.isSunk)
    }

    public var survivingShipsCount: Int {
        ships.filter { !$0.isSunk }.count
    }

    public var sunkShipsCount: Int {
        ships.filter(\.isSunk).count
    }

    public func ship(at coordinate: Coordinate) -> PlacedShip? {
        ships.first { $0.occupies(coordinate) }
    }

    public func ship(ofType type: ShipType) -> PlacedShip? {
        ships.first { $0.type == type }
    }

    public func canPlaceShip(
        type: ShipType,
        origin: Coordinate,
        orientation: ShipOrientation,
        ignoringShipType: ShipType? = nil
    ) -> Bool {
        let coords = PlacedShip.computeCoordinates(
            origin: origin,
            length: type.length,
            orientation: orientation
        )
        guard coords.allSatisfy(\.isValid) else { return false }

        let occupied = Set(
            ships
                .filter { $0.type != type && $0.type != ignoringShipType }
                .flatMap(\.coordinates)
        )
        return coords.allSatisfy { !occupied.contains($0) }
    }

    @discardableResult
    public mutating func placeShip(
        type: ShipType,
        origin: Coordinate,
        orientation: ShipOrientation
    ) -> Bool {
        guard canPlaceShip(type: type, origin: origin, orientation: orientation) else {
            return false
        }
        ships.removeAll { $0.type == type }
        let newShip = PlacedShip(type: type, origin: origin, orientation: orientation)
        ships.append(newShip)
        // Keep fleet sorted in canonical order
        ships.sort {
            ShipType.allCases.firstIndex(of: $0.type)! < ShipType.allCases.firstIndex(of: $1.type)!
        }
        return true
    }

    public mutating func removeShip(ofType type: ShipType) {
        ships.removeAll { $0.type == type }
    }

    public mutating func clearAll() {
        ships.removeAll()
        shots.removeAll()
        radarContacts.removeAll()
    }

    public mutating func randomizeFleet(preferSpaced: Bool = true) {
        clearAll()
        for shipType in ShipType.allCases {
            var placed = false
            var attempts = 0
            while !placed && attempts < 500 {
                attempts += 1
                let orientation = ShipOrientation.allCases.randomElement()!
                let maxRow = orientation == .vertical ? Coordinate.gridSize - shipType.length : Coordinate.gridSize - 1
                let maxCol = orientation == .horizontal ? Coordinate.gridSize - shipType.length : Coordinate.gridSize - 1
                let origin = Coordinate(
                    row: Int.random(in: 0...maxRow),
                    col: Int.random(in: 0...maxCol)
                )

                if canPlaceShip(type: shipType, origin: origin, orientation: orientation) {
                    if preferSpaced && attempts < 140 {
                        let candidateCoords = PlacedShip.computeCoordinates(
                            origin: origin,
                            length: shipType.length,
                            orientation: orientation
                        )
                        let neighborTouch = candidateCoords.contains { coord in
                            coord.orthogonalNeighbors.contains { neighbor in
                                ship(at: neighbor) != nil
                            }
                        }
                        if neighborTouch { continue }
                    }
                    placed = placeShip(type: shipType, origin: origin, orientation: orientation)
                }
            }
        }
    }

    public mutating func receiveShot(at coordinate: Coordinate) -> ShotResult {
        guard coordinate.isValid else {
            return .invalidCoordinate(coordinate)
        }
        if shots[coordinate] != nil {
            return .alreadyTargeted(coordinate)
        }

        // Clear radar indicator once directly targeted
        radarContacts.removeValue(forKey: coordinate)

        if let index = ships.firstIndex(where: { $0.occupies(coordinate) }) {
            ships[index].hits.insert(coordinate)
            if ships[index].isSunk {
                for shipCoord in ships[index].coordinates {
                    shots[shipCoord] = .sunk
                    radarContacts.removeValue(forKey: shipCoord)
                }
                return .sunk(coordinate, ships[index])
            } else {
                shots[coordinate] = .hit
                return .hit(coordinate, ships[index].type)
            }
        } else {
            shots[coordinate] = .miss
            return .miss(coordinate)
        }
    }

    /// Scans a 3x3 sector and records whether untouched cells contain a ship hull.
    public mutating func performSonarScan(center: Coordinate) -> [Coordinate: Bool] {
        var detected: [Coordinate: Bool] = [:]
        for coord in center.surrounding3x3 where shots[coord] == nil {
            let hasHull = ship(at: coord) != nil
            radarContacts[coord] = hasHull
            detected[coord] = hasHull
        }
        return detected
    }
}

// MARK: - Game Modes, Rules & Tactical Weapons

public enum AIDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case cadet = "Ensign"
    case commander = "Commander"
    case admiral = "Fleet Admiral"

    public var id: String { rawValue }

    public var subtitle: String {
        switch self {
        case .cadet:
            return "Opportunistic patrol sweeps"
        case .commander:
            return "Hunt & Target lock-on doctrine"
        case .admiral:
            return "Probability density & parity matrix AI"
        }
    }

    public var badgeColorName: String {
        switch self {
        case .cadet: return "emerald"
        case .commander: return "cyan"
        case .admiral: return "amber"
        }
    }
}

public enum GameMode: Equatable, Codable, Sendable {
    case vsAI(AIDifficulty)
    case passAndPlay

    public var displayTitle: String {
        switch self {
        case .vsAI(let diff):
            return "VS AI (\(diff.rawValue))"
        case .passAndPlay:
            return "2-Player Pass & Play"
        }
    }
}

public enum CombatRules: String, CaseIterable, Codable, Identifiable, Sendable {
    case classic = "Classic"
    case salvo = "Salvo"
    case tactical = "Tactical Ops"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .classic:
            return "1 torpedo per turn. Classic naval duel."
        case .salvo:
            return "Fire 1 torpedo for each surviving ship in your fleet."
        case .tactical:
            return "Standard torpedoes plus Sonar Ping, Airstrike, and Cluster Barrage."
        }
    }
}

public enum TacticalWeapon: String, CaseIterable, Codable, Identifiable, Sendable {
    case standardTorpedo = "Mk-48 Torpedo"
    case sonarPing = "Active Sonar Ping"
    case airstrike = "Harpoon Airstrike"
    case clusterBarrage = "Tomahawk Cross"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .standardTorpedo: return "TORPEDO"
        case .sonarPing: return "SONAR 3×3"
        case .airstrike: return "STRIKE 1×3"
        case .clusterBarrage: return "CROSS 5×"
        }
    }

    public var iconName: String {
        switch self {
        case .standardTorpedo: return "scope"
        case .sonarPing: return "dot.radiowaves.left.and.right"
        case .airstrike: return "airplane.departure"
        case .clusterBarrage: return "sparkles"
        }
    }

    public var detailText: String {
        switch self {
        case .standardTorpedo:
            return "Single precision torpedo strike (Unlimited)"
        case .sonarPing:
            return "Reveals enemy hull signatures in a 3×3 sector without firing"
        case .airstrike:
            return "Strikes 3 consecutive cells along a horizontal or vertical line (Press R to rotate)"
        case .clusterBarrage:
            return "Detonates 5 cells in a '+' cross formation"
        }
    }

    public var initialCharges: Int {
        switch self {
        case .standardTorpedo: return 999
        case .sonarPing: return 2
        case .airstrike: return 1
        case .clusterBarrage: return 1
        }
    }

    public func affectedCoordinates(center: Coordinate, orientation: ShipOrientation) -> [Coordinate] {
        switch self {
        case .standardTorpedo:
            return center.isValid ? [center] : []
        case .sonarPing:
            return center.surrounding3x3
        case .airstrike:
            return center.lineSegment(orientation: orientation, length: 3)
        case .clusterBarrage:
            return center.crossPattern
        }
    }
}

// MARK: - Telemetry Log & Career Stats

public struct CombatLogEntry: Identifiable, Equatable, Sendable {
    public enum Category: Sendable {
        case info
        case hit
        case sunk
        case miss
        case radar
        case warning
    }

    public let id = UUID()
    public let timestamp: Date
    public let turn: Int
    public let actor: String
    public let message: String
    public let category: Category

    public init(
        timestamp: Date = Date(),
        turn: Int,
        actor: String,
        message: String,
        category: Category
    ) {
        self.timestamp = timestamp
        self.turn = turn
        self.actor = actor
        self.message = message
        self.category = category
    }
}

public struct CareerStats: Codable, Equatable, Sendable {
    public var gamesPlayed: Int = 0
    public var victories: Int = 0
    public var defeats: Int = 0
    public var totalShotsFired: Int = 0
    public var totalHits: Int = 0
    public var enemyShipsSunk: Int = 0
    public var currentWinStreak: Int = 0
    public var bestWinStreak: Int = 0
    public var fastestVictoryTurns: Int? = nil

    public var winRatePercentage: Int {
        guard gamesPlayed > 0 else { return 0 }
        return Int((Double(victories) / Double(gamesPlayed) * 100.0).rounded())
    }

    public var accuracyPercentage: Int {
        guard totalShotsFired > 0 else { return 0 }
        return Int((Double(totalHits) / Double(totalShotsFired) * 100.0).rounded())
    }

    private static let storageKey = "com.battleship.command.careerStats"

    public static func load() -> CareerStats {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(CareerStats.self, from: data) else {
            return CareerStats()
        }
        return decoded
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
