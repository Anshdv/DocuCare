import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.93, green: 0.96, blue: 1.0)
    static let backgroundBottom = Color(red: 0.98, green: 0.94, blue: 1.0)
    static let cardFill = Color.white.opacity(0.96)
    static let cardStroke = Color.white.opacity(0.92)
    static let accent = Color(red: 0.24, green: 0.45, blue: 0.95)
    static let accentSecondary = Color(red: 0.45, green: 0.30, blue: 0.88)
    static let softText = Color(red: 0.16, green: 0.19, blue: 0.24)
    static let secondaryText = Color(red: 0.34, green: 0.38, blue: 0.46)
    static let chipFill = Color.white.opacity(0.97)
    static let rowFill = Color.white.opacity(0.94)
}

struct AppBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Circle()
                .fill(AppTheme.accent.opacity(0.17))
                .blur(radius: 130)
                .offset(x: -170, y: -220)
        )
        .overlay(
            Circle()
                .fill(AppTheme.accentSecondary.opacity(0.15))
                .blur(radius: 145)
                .offset(x: 190, y: 250)
        )
        .ignoresSafeArea()
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.09), radius: 14, y: 6)
            .foregroundStyle(AppTheme.softText)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardModifier())
    }

    func appTextFieldStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.80, green: 0.84, blue: 0.93), lineWidth: 1)
            )
            .foregroundStyle(AppTheme.softText)
    }
}
