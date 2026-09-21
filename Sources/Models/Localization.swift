import SwiftUI

/// The POC ships English first. Arabic is present because the research is
/// explicit that designing English-first with Arabic "considered" is how RTL
/// products break — so the layout is exercised against real Arabic strings and
/// a real `layoutDirection` flip while it is still cheap to change.
///
/// Per Recommendation 05, Journey Home and the shared chrome are fully
/// translated; deeper screens fall back to English and are flagged as such in
/// Settings. Every string here is a real translation, never a placeholder,
/// because bidirectional text only misbehaves with real strings.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english
    case arabic

    var id: String { rawValue }

    var code: String {
        switch self {
        case .english: "en"
        case .arabic:  "ar"
        }
    }

    /// Endonym — a language picker that names languages in English only is a
    /// picker you cannot use if you do not read English.
    var endonym: String {
        switch self {
        case .english: "English"
        case .arabic:  "العربية"
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .english: .leftToRight
        case .arabic:  .rightToLeft
        }
    }

    var locale: Locale {
        switch self {
        case .english: Locale(identifier: "en_GB")
        case .arabic:  Locale(identifier: "ar_SA")
        }
    }
}

/// Inline two-language lookup.
///
/// This is deliberately not a `.xcstrings` catalogue yet: at POC stage the
/// English and Arabic need to sit side by side in the source so a reviewer can
/// see instantly which strings have been translated and which have not. The
/// call shape (`tr("English", "عربي")`) maps one-to-one onto a string catalogue
/// key when this graduates.
struct Translator: Sendable {
    var language: AppLanguage = .english

    func callAsFunction(_ english: String, _ arabic: String? = nil) -> String {
        guard language == .arabic, let arabic else { return english }
        return arabic
    }

    /// Formats a clock time in the active locale. Arabic-Indic digits are a
    /// live question for the region; `ar_SA` gives Western digits by default,
    /// which is what Saudi carriers ship, so we follow the locale.
    func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(language.locale))
    }
}

extension EnvironmentValues {
    @Entry var tr = Translator()
}
