import AVFoundation
import Foundation

@MainActor
public final class SoundEngine: ObservableObject {
    public static let shared = SoundEngine()

    @Published public var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "com.battleship.command.muted")
        }
    }

    private var activePlayers: [AVAudioPlayer] = []
    private var cachedAudioData: [SoundEffect: Data] = [:]

    public enum SoundEffect: CaseIterable {
        case sonarPing
        case targetClick
        case torpedoLaunch
        case explosionHit
        case shipSunk
        case waterSplash
        case victoryFanfare
        case defeatAlarm
    }

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "com.battleship.command.muted")
        preloadAll()
    }

    private func preloadAll() {
        for effect in SoundEffect.allCases {
            cachedAudioData[effect] = synthesizeWAV(for: effect)
        }
    }

    public func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        let data = cachedAudioData[effect] ?? synthesizeWAV(for: effect)
        guard let player = try? AVAudioPlayer(data: data) else { return }
        activePlayers.removeAll { !$0.isPlaying }
        activePlayers.append(player)
        player.play()
    }

    // MARK: - Procedural Naval Audio Synthesis

    private func synthesizeWAV(for effect: SoundEffect) -> Data {
        let sampleRate = 44100.0
        let duration: Double
        switch effect {
        case .sonarPing: duration = 0.65
        case .targetClick: duration = 0.08
        case .torpedoLaunch: duration = 0.28
        case .explosionHit: duration = 0.55
        case .shipSunk: duration = 1.05
        case .waterSplash: duration = 0.38
        case .victoryFanfare: duration = 1.15
        case .defeatAlarm: duration = 0.95
        }

        let numSamples = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: numSamples)

        var noiseSeed: UInt64 = 0xCAFE_BABE_1234_5678
        func nextWhiteNoise() -> Double {
            noiseSeed = noiseSeed &* 6364136223846793005 &+ 1442695040888963407
            let normalized = Double((noiseSeed >> 32) & 0xFFFF_FFFF) / Double(UInt32.max)
            return normalized * 2.0 - 1.0
        }

        var lowpassState = 0.0

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var signal = 0.0

            switch effect {
            case .sonarPing:
                // Classic 1320Hz oceanic sonar ping with harmonic shimmer and exponential decay
                let env = exp(-t * 5.8) * min(1.0, t / 0.008)
                let primary = sin(2.0 * .pi * 1320.0 * t)
                let overtone = 0.25 * sin(2.0 * .pi * 2640.0 * t) * exp(-t * 10.0)
                let echo = t > 0.22 ? 0.28 * exp(-(t - 0.22) * 7.5) * sin(2.0 * .pi * 1320.0 * (t - 0.22)) : 0.0
                signal = (primary + overtone + echo) * env * 0.45

            case .targetClick:
                let env = exp(-t * 45.0)
                signal = (sin(2.0 * .pi * 1850.0 * t) + 0.5 * sin(2.0 * .pi * 920.0 * t)) * env * 0.30

            case .torpedoLaunch:
                // Compressed-air tube launch + rising hydro-propulsion whoosh
                let env = sin(.pi * (t / duration))
                let sweepFreq = 260.0 + 620.0 * (t / duration)
                let noise = nextWhiteNoise()
                lowpassState = lowpassState * 0.82 + noise * 0.18
                signal = (0.55 * lowpassState + 0.45 * sin(2.0 * .pi * sweepFreq * t)) * env * 0.40

            case .explosionHit:
                // Heavy sub-bass concussion + filtered crunch
                let env = exp(-t * 5.2)
                let bassFreq = max(42.0, 145.0 * exp(-t * 8.0))
                let subBass = sin(2.0 * .pi * bassFreq * t)
                let noise = nextWhiteNoise()
                lowpassState = lowpassState * 0.78 + noise * 0.22
                signal = tanh((subBass * 1.1 + lowpassState * 0.95) * 1.8) * env * 0.65

            case .shipSunk:
                // Dual-tone naval klaxon + deep secondary hull implosion
                let klaxonFreq = (Int(t * 6.0) % 2 == 0) ? 520.0 : 390.0
                let klaxonEnv = t < 0.75 ? 0.35 : 0.0
                let klaxon = sin(2.0 * .pi * klaxonFreq * t) * klaxonEnv
                let boomEnv = exp(-t * 2.9)
                let subBoom = sin(2.0 * .pi * max(36.0, 110.0 * exp(-t * 4.5)) * t)
                let noise = nextWhiteNoise()
                lowpassState = lowpassState * 0.85 + noise * 0.15
                signal = tanh((klaxon + (subBoom + lowpassState * 0.8) * boomEnv) * 1.6) * 0.65

            case .waterSplash:
                // Hydro splash noise + descending bubble bloop
                let env = exp(-t * 8.5)
                let noise = nextWhiteNoise()
                lowpassState = lowpassState * 0.70 + noise * 0.30
                let bubbleFreq = 480.0 - 260.0 * (t / duration)
                let bubble = sin(2.0 * .pi * bubbleFreq * t) * exp(-t * 12.0)
                signal = (lowpassState * 0.55 + bubble * 0.45) * env * 0.42

            case .victoryFanfare:
                // Rising major triad arpeggio (C5 - E5 - G5 - C6)
                let notes = [523.25, 659.25, 783.99, 1046.50]
                let step = min(notes.count - 1, Int((t / duration) * Double(notes.count)))
                let localT = t - (Double(step) * (duration / Double(notes.count)))
                let env = exp(-localT * 4.2)
                let freq = notes[step]
                signal = (sin(2.0 * .pi * freq * t) + 0.35 * sin(2.0 * .pi * freq * 2.0 * t)) * env * 0.38

            case .defeatAlarm:
                // Descending minor sonar fade
                let notes = [440.0, 392.0, 349.23, 293.66]
                let step = min(notes.count - 1, Int((t / duration) * Double(notes.count)))
                let localT = t - (Double(step) * (duration / Double(notes.count)))
                let env = exp(-localT * 4.5)
                let freq = notes[step]
                signal = sin(2.0 * .pi * freq * t) * env * 0.36
            }

            let clamped = max(-1.0, min(1.0, signal))
            samples[i] = Int16(clamped * Double(Int16.max))
        }

        return encodePCM16WAV(samples: samples, sampleRate: Int(sampleRate))
    }

    private func encodePCM16WAV(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: littleEndianBytes(chunkSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: littleEndianBytes(UInt32(16))) // PCM header size
        data.append(contentsOf: littleEndianBytes(UInt16(1)))  // AudioFormat = 1 (PCM)
        data.append(contentsOf: littleEndianBytes(numChannels))
        data.append(contentsOf: littleEndianBytes(UInt32(sampleRate)))
        data.append(contentsOf: littleEndianBytes(byteRate))
        data.append(contentsOf: littleEndianBytes(blockAlign))
        data.append(contentsOf: littleEndianBytes(bitsPerSample))
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: littleEndianBytes(dataSize))

        samples.withUnsafeBufferPointer { buffer in
            data.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }
        return data
    }

    private func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
}
