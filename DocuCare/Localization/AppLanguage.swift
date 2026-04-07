import Foundation

/// Supported app languages (ISO-style codes used as keys in `L10n`).
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case hindi = "hi"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case portugueseBrazil = "pt-BR"

    var id: String { rawValue }

    /// Shown in the signup language picker (native name).
    var pickerTitle: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .hindi: return "हिन्दी"
        case .japanese: return "日本語"
        case .chineseSimplified: return "简体中文"
        case .portugueseBrazil: return "Português (Brasil)"
        }
    }

    /// Used in Gemini instructions (English name of the target language).
    var englishNameForAI: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .hindi: return "Hindi"
        case .japanese: return "Japanese"
        case .chineseSimplified: return "Simplified Chinese"
        case .portugueseBrazil: return "Brazilian Portuguese"
        }
    }

    static func from(code: String) -> AppLanguage {
        AppLanguage(rawValue: code) ?? .english
    }

    /// Best match from the user's system preferred languages (before any account exists).
    static func bestMatchForSystem() -> AppLanguage {
        for id in Locale.preferredLanguages {
            let lower = id.lowercased()
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("fr") { return .french }
            if lower.hasPrefix("de") { return .german }
            if lower.hasPrefix("hi") { return .hindi }
            if lower.hasPrefix("ja") { return .japanese }
            if lower.hasPrefix("zh-hans") || lower == "zh-cn" { return .chineseSimplified }
            if lower.hasPrefix("zh") { return .chineseSimplified }
            if lower.hasPrefix("pt") { return .portugueseBrazil }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }

    /// `Locale` identifier (underscores where needed).
    static func localeIdentifier(from code: String) -> String {
        switch code {
        case "zh-Hans": return "zh_Hans"
        case "pt-BR": return "pt_BR"
        default: return code
        }
    }

    /// Best-effort BCP-47 tag for AVSpeechSynthesisVoice.
    static func speechLanguageIdentifier(from code: String) -> String {
        switch AppLanguage.from(code: code) {
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .hindi: return "hi-IN"
        case .japanese: return "ja-JP"
        case .chineseSimplified: return "zh-CN"
        case .portugueseBrazil: return "pt-BR"
        }
    }
}
