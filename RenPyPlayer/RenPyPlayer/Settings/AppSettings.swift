import Foundation

enum DisplayScalingMode: String, CaseIterable, Identifiable {
    case edgeToEdge = "edgeToEdge"  // 100% full screen, ignores all safe areas
    case fit16x9 = "fit16x9"        // Exact 16:9 ratio with pillarbox
    case stretch = "stretch"        // Stretches to fill entire display

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edgeToEdge: return "Full Screen (Edge-to-Edge)"
        case .fit16x9: return "16:9 Fit (Pillarbox)"
        case .stretch: return "Stretch to Fill"
        }
    }

    var icon: String {
        switch self {
        case .edgeToEdge: return "arrow.up.left.and.arrow.down.right"
        case .fit16x9: return "aspectratio"
        case .stretch: return "arrow.left.and.right"
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var screenScale: Float {
        didSet { UserDefaults.standard.set(screenScale, forKey: Keys.screenScale) }
    }
    @Published var textSpeedOverride: Double {
        didSet { UserDefaults.standard.set(textSpeedOverride, forKey: Keys.textSpeed) }
    }
    @Published var skipModeEnabled: Bool {
        didSet { UserDefaults.standard.set(skipModeEnabled, forKey: Keys.skipMode) }
    }
    @Published var fillScreen: Bool {
        didSet { UserDefaults.standard.set(fillScreen, forKey: Keys.fillScreen) }
    }
    @Published var displayMode: DisplayScalingMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    private enum Keys {
        static let screenScale = "settings.screenScale"
        static let textSpeed = "settings.textSpeed"
        static let skipMode = "settings.skipMode"
        static let fillScreen = "settings.fillScreen"
        static let displayMode = "settings.displayMode"
    }

    init() {
        let defaults = UserDefaults.standard
        screenScale = defaults.object(forKey: Keys.screenScale) as? Float ?? 1.0
        textSpeedOverride = defaults.object(forKey: Keys.textSpeed) as? Double ?? 1.0
        skipModeEnabled = defaults.bool(forKey: Keys.skipMode)
        fillScreen = defaults.object(forKey: Keys.fillScreen) as? Bool ?? true

        let rawMode = defaults.string(forKey: Keys.displayMode) ?? DisplayScalingMode.edgeToEdge.rawValue
        displayMode = DisplayScalingMode(rawValue: rawMode) ?? .edgeToEdge
    }
}
