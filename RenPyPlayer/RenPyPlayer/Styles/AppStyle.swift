import SwiftUI

/// Shared visual language for the app's own chrome (library, import, and
/// settings screens). Deliberately not applied to `GamePlayerView` /
/// `SDLGameView`, which render the actual game content edge-to-edge.
enum AppStyle {
    static let accent = LinearGradient(
        colors: [Color(red: 0.42, green: 0.36, blue: 0.98), Color(red: 0.65, green: 0.32, blue: 0.86)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 20
}

/// Soft full-screen gradient wash used behind the library/import/settings
/// screens instead of a flat system background.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color(red: 0.42, green: 0.36, blue: 0.98).opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// A rounded, elevated card container for grouping content, replacing the
/// default `Form`/`List` inset-grouped look with something a bit softer.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppStyle.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

/// A bold, pill-shaped, gradient-filled button for primary actions.
struct ProminentGradientButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isEnabled {
                        AppStyle.accent
                    } else {
                        Color.gray.opacity(0.4)
                    }
                },
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
