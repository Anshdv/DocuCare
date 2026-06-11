import SwiftUI

/// User-selectable text size. The raw value is persisted with the user's
/// account and converted to a SwiftUI `DynamicTypeSize` at render time so
/// the entire app scales together (titles, buttons, body text, Form rows…).
enum AppFontSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    /// Default for new accounts (matches the system's standard "Large" size).
    static let `default`: AppFontSize = .medium

    /// SwiftUI Dynamic Type size that the app environment should apply.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .medium: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }

    /// Localization key for the option's display label.
    var localizationKey: L10n.Key {
        switch self {
        case .small: return .fontSizeSmall
        case .medium: return .fontSizeMedium
        case .large: return .fontSizeLarge
        case .extraLarge: return .fontSizeExtraLarge
        }
    }

    /// Approximate point size used purely to preview each option in the picker.
    var previewPointSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 17
        case .large: return 20
        case .extraLarge: return 23
        }
    }

    static func from(rawValue: String?) -> AppFontSize {
        guard let rawValue, let value = AppFontSize(rawValue: rawValue) else {
            return .default
        }
        return value
    }
}
