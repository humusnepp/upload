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

    private enum Keys {
        static let screenScale = "settings.screenScale"
        static let textSpeed = "settings.textSpeed"
        static let skipMode = "settings.skipMode"
    }

    init() {
        let defaults = UserDefaults.standard
        screenScale = defaults.object(forKey: Keys.screenScale) as? Float ?? 1.0
        textSpeedOverride = defaults.object(forKey: Keys.textSpeed) as? Double ?? 1.0
        skipModeEnabled = defaults.bool(forKey: Keys.skipMode)
    }
}
