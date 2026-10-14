# Battleship — Aegis Naval Command for macOS

**Live Website:** [https://battleship-aegis.web.app](https://battleship-aegis.web.app)

A native macOS (SwiftUI) tactical Battleship board game featuring a **Modern Naval Command Center** interface, animated radar sweeps, procedural naval audio synthesis, multi-difficulty AI with real-time probability density calculations, and 3 combat rule variants.

## Features

- **Modern Naval Command Center Aesthetic**:
  - Deep abyssal HUD with glowing cyan/emerald radar sweeps, animated shockwave explosions, water splash ripples, and custom vector warship silhouettes (`USS Enterprise CVN-65`, `USS Iowa BB-61`, `USS Ticonderoga CG-47`, `USS Seawolf SSN-21`, `USS Arleigh Burke DDG-51`).
- **Game Modes**:
  - **Single-Player vs. AI**:
    - **Ensign (Easy)**: Opportunistic patrol sweeps.
    - **Commander (Medium)**: Hunt & Target directional lock-on doctrine with parity filtering.
    - **Fleet Admiral (Hard)**: Full 10×10 combinatorial probability density matrix evaluation across all valid placements of surviving ships.
  - **2-Player Pass & Play (Hotseat)**: Classified command handoff lockout screen between turns so two players can battle on the same Mac.
- **3 Combat Rule Variants**:
  - **Classic**: 1 torpedo shot per turn.
  - **Salvo**: Number of shots per turn equals the number of surviving vessels in your fleet.
  - **Tactical Ops**: Standard torpedoes plus **Active Sonar Ping (3×3)**, **Harpoon Airstrike (1×3)**, and **Tomahawk Cross Barrage (5-cell)**.
- **Real-Time Probability Sensor Overlay**:
  - Toggle the **PROBABILITY** sensor button in the header to visualize the live mathematical likelihood of enemy hulls across unexplored sectors.
- **Procedural Naval Audio Engine**:
  - Zero-dependency in-memory WAV synthesis for sonar pings, compressed-air torpedo launches, hull explosions, sinking klaxons, and hydro splashes.

## Building & Running

```bash
./build_app.sh
open Battleship.app
```

Run the unit test suite with:

```bash
swift test
```
