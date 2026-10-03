import SwiftUI

public enum NavalTheme {
    // Abyssal Command Palette
    public static let bgDeep = Color(red: 0.024, green: 0.051, blue: 0.094)       // #060D18
    public static let bgPanel = Color(red: 0.047, green: 0.090, blue: 0.157)      // #0C1728
    public static let bgPanelElevated = Color(red: 0.071, green: 0.129, blue: 0.216) // #122137
    public static let gridWater = Color(red: 0.035, green: 0.082, blue: 0.149)    // #091526
    public static let gridLine = Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.18)

    // Tactical Accents
    public static let sonarCyan = Color(red: 0.0, green: 0.92, blue: 1.0)         // #00EBFF
    public static let radarEmerald = Color(red: 0.06, green: 0.85, blue: 0.56)    // #10D98F
    public static let threatCrimson = Color(red: 1.0, green: 0.23, blue: 0.19)    // #FF3B30
    public static let warningAmber = Color(red: 1.0, green: 0.72, blue: 0.0)      // #FFB800
    public static let hullSteel = Color(red: 0.36, green: 0.52, blue: 0.68)
    public static let hullOutline = Color(red: 0.58, green: 0.82, blue: 0.98)

    // Text Hierarchy
    public static let textPrimary = Color(red: 0.91, green: 0.96, blue: 1.0)
    public static let textSecondary = Color(red: 0.55, green: 0.69, blue: 0.84)
    public static let textMuted = Color(red: 0.36, green: 0.48, blue: 0.62)

    public static let monoFont = Font.system(.caption, design: .monospaced)
    public static let monoHeader = Font.system(.subheadline, design: .monospaced).weight(.bold)
}
