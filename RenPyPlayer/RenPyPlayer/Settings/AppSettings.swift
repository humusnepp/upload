import Foundation

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

    private enum Keys {
        static let screenScale = "settings.screenScale"
        static let textSpeed = "settings.textSpeed"
        static let skipMode = "settings.skipMode"
        static let fillScreen = "settings.fillScreen"
    }

    init() {
        let defaults = UserDefaults.standard
        screenScale = defaults.object(forKey: Keys.screenScale) as? Float ?? 1.0
        textSpeedOverride = defaults.object(forKey: Keys.textSpeed) as? Double ?? 1.0
        skipModeEnabled = defaults.bool(forKey: Keys.skipMode)
        // Default to true so game fills the phone's full screen edge-to-edge
        fillScreen = defaults.object(forKey: Keys.fillScreen) as? Bool ?? true
    }
}
