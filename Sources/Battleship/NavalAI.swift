import Foundation

public struct NavalAI {
    /// Computes a 10x10 probability density matrix representing the likelihood of an unsunk ship
    /// occupying each unexplored cell on the opponent's board.
    public static func computeProbabilityMap(for board: NavalBoard) -> [[Double]] {
        let size = Coordinate.gridSize
        var rawWeights = Array(repeating: Array(repeating: 0.0, count: size), count: size)

        // Identify remaining unsunk ship lengths
        let unsunkShips = board.ships.filter { !$0.isSunk }
        let remainingLengths = unsunkShips.isEmpty
            ? ShipType.allCases.map(\.length)
            : unsunkShips.map(\.type.length)

        // Cells that are known misses or already sunk ships cannot belong to an unsunk ship
        var blocked = Set<Coordinate>()
        var activeHits = Set<Coordinate>()

        for (coord, outcome) in board.shots {
            switch outcome {
            case .miss, .sunk:
                blocked.insert(coord)
            case .hit:
                activeHits.insert(coord)
            }
        }

        // Also incorporate negative radar contacts if available
        for (coord, hasShip) in board.radarContacts {
            if !hasShip {
                blocked.insert(coord)
            }
        }

        // 1. Enumerate every valid placement of every remaining unsunk ship
        for length in remainingLengths {
            for row in 0..<size {
                for col in 0..<size {
                    for orientation in ShipOrientation.allCases {
                        let coords = PlacedShip.computeCoordinates(
                            origin: Coordinate(row: row, col: col),
                            length: length,
                            orientation: orientation
                        )
                        guard coords.allSatisfy({ $0.isValid && !blocked.contains($0) }) else {
                            continue
                        }

                        // Count how many known active hits this placement overlaps
                        let overlapHits = coords.filter { activeHits.contains($0) }.count
                        let weight: Double
                        if overlapHits > 0 {
                            // Exponentially reward placements that explain existing active hits
                            weight = pow(12.0, Double(overlapHits))
                        } else {
                            weight = 1.0
                        }

                        for c in coords where board.shots[c] == nil {
                            rawWeights[c.row][c.col] += weight
                        }
                    }
                }
            }
        }

        // 2. If there are active unsunk hits, strongly boost collinear/adjacent unexplored cells
        if !activeHits.isEmpty {
            for hit in activeHits {
                for neighbor in hit.orthogonalNeighbors where board.shots[neighbor] == nil && !blocked.contains(neighbor) {
                    rawWeights[neighbor.row][neighbor.col] += 35.0

                    // Check if there is another active hit in the opposite direction (line formation!)
                    let dr = neighbor.row - hit.row
                    let dc = neighbor.col - hit.col
                    let opposite = Coordinate(row: hit.row - dr, col: hit.col - dc)
                    if activeHits.contains(opposite) {
                        rawWeights[neighbor.row][neighbor.col] += 120.0
                    }
                }
            }
        }

        // Normalize to 0.0 ... 1.0 for visualization and ranking
        let maxWeight = rawWeights.flatMap { $0 }.max() ?? 1.0
        guard maxWeight > 0 else { return rawWeights }

        var normalized = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        for r in 0..<size {
            for c in 0..<size {
                normalized[r][c] = rawWeights[r][c] / maxWeight
            }
        }
        return normalized
    }

    /// Selects the next target coordinate for the AI based on the chosen difficulty.
    public static func selectTarget(
        on playerBoard: NavalBoard,
        difficulty: AIDifficulty
    ) -> Coordinate {
        var untargeted: [Coordinate] = []
        for r in 0..<Coordinate.gridSize {
            for c in 0..<Coordinate.gridSize {
                let coord = Coordinate(row: r, col: c)
                if playerBoard.shots[coord] == nil {
                    untargeted.append(coord)
                }
            }
        }
        guard !untargeted.isEmpty else {
            return Coordinate(row: 0, col: 0)
        }

        switch difficulty {
        case .cadet:
            return selectCadetTarget(on: playerBoard, untargeted: untargeted)
        case .commander:
            return selectCommanderTarget(on: playerBoard, untargeted: untargeted)
        case .admiral:
            return selectAdmiralTarget(on: playerBoard, untargeted: untargeted)
        }
    }

    private static func selectCadetTarget(
        on board: NavalBoard,
        untargeted: [Coordinate]
    ) -> Coordinate {
        // 45% chance to follow up on an existing hit, otherwise random unexplored cell
        let activeHits = board.shots.filter { $0.value == .hit }.map(\.key)
        if !activeHits.isEmpty && Double.random(in: 0...1) < 0.45 {
            let candidates = activeHits
                .flatMap(\.orthogonalNeighbors)
                .filter { board.shots[$0] == nil }
            if let pick = candidates.randomElement() {
                return pick
            }
        }
        return untargeted.randomElement()!
    }

    private static func selectCommanderTarget(
        on board: NavalBoard,
        untargeted: [Coordinate]
    ) -> Coordinate {
        let activeHits = Set(board.shots.filter { $0.value == .hit }.map(\.key))

        if !activeHits.isEmpty {
            // Check for collinear hits first
            var lineCandidates: [Coordinate] = []
            for hit in activeHits {
                for neighbor in hit.orthogonalNeighbors where board.shots[neighbor] == nil {
                    let dr = neighbor.row - hit.row
                    let dc = neighbor.col - hit.col
                    let opposite = Coordinate(row: hit.row - dr, col: hit.col - dc)
                    if activeHits.contains(opposite) {
                        lineCandidates.append(neighbor)
                    }
                }
            }
            if let linePick = lineCandidates.randomElement() {
                return linePick
            }

            // Otherwise pick any orthogonal neighbor of an active hit
            let neighborCandidates = activeHits
                .flatMap(\.orthogonalNeighbors)
                .filter { board.shots[$0] == nil }
            if let neighborPick = neighborCandidates.randomElement() {
                return neighborPick
            }
        }

        // In hunt mode, Commander uses parity (checkerboard) 70% of the time
        let minShipSize = board.ships.filter { !$0.isSunk }.map(\.type.length).min() ?? 2
        let parityCells = untargeted.filter { ($0.row + $0.col) % minShipSize == 0 }
        if !parityCells.isEmpty && Double.random(in: 0...1) < 0.70 {
            return parityCells.randomElement()!
        }
        return untargeted.randomElement()!
    }

    private static func selectAdmiralTarget(
        on board: NavalBoard,
        untargeted: [Coordinate]
    ) -> Coordinate {
        let probMap = computeProbabilityMap(for: board)
        var bestScore = -1.0
        var topCandidates: [Coordinate] = []

        for coord in untargeted {
            let score = probMap[coord.row][coord.col]
            if score > bestScore + 0.001 {
                bestScore = score
                topCandidates = [coord]
            } else if abs(score - bestScore) <= 0.001 {
                topCandidates.append(coord)
            }
        }

        return topCandidates.randomElement() ?? untargeted.randomElement()!
    }
}
