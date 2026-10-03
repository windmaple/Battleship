import XCTest
@testable import Battleship

final class BattleshipTests: XCTestCase {
    func testCoordinateNotationAndPatterns() {
        let origin = Coordinate(row: 0, col: 0)
        XCTAssertTrue(origin.isValid)
        XCTAssertEqual(origin.compactNotation, "A1")
        XCTAssertEqual(origin.notation, "A-01")
        XCTAssertEqual(origin.orthogonalNeighbors.count, 2)
        XCTAssertEqual(origin.surrounding3x3.count, 4)

        let center = Coordinate(row: 4, col: 4)
        XCTAssertEqual(center.compactNotation, "E5")
        XCTAssertEqual(center.orthogonalNeighbors.count, 4)
        XCTAssertEqual(center.surrounding3x3.count, 9)
        XCTAssertEqual(center.crossPattern.count, 5)
        XCTAssertEqual(center.lineSegment(orientation: .horizontal, length: 3).count, 3)
        XCTAssertEqual(center.lineSegment(orientation: .vertical, length: 3).count, 3)
    }

    func testShipPlacementAndCollision() {
        var board = NavalBoard()
        // Place Carrier horizontally at A1..A5
        XCTAssertTrue(board.placeShip(type: .carrier, origin: Coordinate(row: 0, col: 0), orientation: .horizontal))
        XCTAssertEqual(board.ships.count, 1)

        // Overlapping vertical Battleship at A3 should fail
        XCTAssertFalse(board.canPlaceShip(type: .battleship, origin: Coordinate(row: 0, col: 2), orientation: .vertical))

        // Out-of-bounds placement should fail
        XCTAssertFalse(board.canPlaceShip(type: .battleship, origin: Coordinate(row: 0, col: 8), orientation: .horizontal))

        // Valid non-overlapping placement at B1 should succeed
        XCTAssertTrue(board.placeShip(type: .battleship, origin: Coordinate(row: 1, col: 0), orientation: .horizontal))
        XCTAssertEqual(board.ships.count, 2)

        // Re-placing Carrier at a new position should move it, not duplicate it
        XCTAssertTrue(board.placeShip(type: .carrier, origin: Coordinate(row: 5, col: 0), orientation: .horizontal))
        XCTAssertEqual(board.ships.count, 2)
        XCTAssertEqual(board.ship(ofType: .carrier)?.origin, Coordinate(row: 5, col: 0))
    }

    func testRandomizeFleetCompleteness() {
        var board = NavalBoard()
        board.randomizeFleet(preferSpaced: true)
        XCTAssertTrue(board.isFleetComplete)
        XCTAssertEqual(board.ships.count, 5)

        let allCoords = board.ships.flatMap(\.coordinates)
        XCTAssertEqual(allCoords.count, 17) // 5 + 4 + 3 + 3 + 2
        XCTAssertEqual(Set(allCoords).count, 17) // No overlaps
    }

    func testShotResolutionAndSinking() {
        var board = NavalBoard()
        board.placeShip(type: .destroyer, origin: Coordinate(row: 2, col: 3), orientation: .horizontal)

        // Miss
        let missResult = board.receiveShot(at: Coordinate(row: 0, col: 0))
        XCTAssertEqual(missResult, .miss(Coordinate(row: 0, col: 0)))

        // Duplicate shot
        let dupResult = board.receiveShot(at: Coordinate(row: 0, col: 0))
        XCTAssertEqual(dupResult, .alreadyTargeted(Coordinate(row: 0, col: 0)))

        // First hit on Destroyer
        let hit1 = board.receiveShot(at: Coordinate(row: 2, col: 3))
        XCTAssertEqual(hit1, .hit(Coordinate(row: 2, col: 3), .destroyer))
        XCTAssertFalse(board.allShipsSunk)

        // Second hit sinks Destroyer
        let hit2 = board.receiveShot(at: Coordinate(row: 2, col: 4))
        if case .sunk(let coord, let sunkShip) = hit2 {
            XCTAssertEqual(coord, Coordinate(row: 2, col: 4))
            XCTAssertEqual(sunkShip.type, .destroyer)
            XCTAssertTrue(sunkShip.isSunk)
        } else {
            XCTFail("Expected destroyer to sink on second hit")
        }
        XCTAssertTrue(board.allShipsSunk)
    }

    func testSonarScanAndAIProbability() {
        var board = NavalBoard()
        board.placeShip(type: .cruiser, origin: Coordinate(row: 4, col: 3), orientation: .horizontal) // E4, E5, E6

        let contacts = board.performSonarScan(center: Coordinate(row: 4, col: 4))
        XCTAssertEqual(contacts.count, 9)
        XCTAssertEqual(contacts[Coordinate(row: 4, col: 3)], true)
        XCTAssertEqual(contacts[Coordinate(row: 4, col: 4)], true)
        XCTAssertEqual(contacts[Coordinate(row: 4, col: 5)], true)
        XCTAssertEqual(contacts[Coordinate(row: 3, col: 3)], false)

        // Hit E5 and verify Admiral AI prioritizes E4 or E6
        _ = board.receiveShot(at: Coordinate(row: 4, col: 4))
        let probMap = NavalAI.computeProbabilityMap(for: board)
        XCTAssertGreaterThan(probMap[4][3], probMap[0][0])
        XCTAssertGreaterThan(probMap[4][5], probMap[0][0])

        let admiralChoice = NavalAI.selectTarget(on: board, difficulty: .admiral)
        XCTAssertTrue(
            [
                Coordinate(row: 4, col: 3),
                Coordinate(row: 4, col: 5),
                Coordinate(row: 3, col: 4),
                Coordinate(row: 5, col: 4)
            ].contains(admiralChoice)
        )
    }
}
