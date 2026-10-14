import Foundation

/// A country flag for a language row.
///
/// A language that already names a region uses that region (`pt-BR` is Brazil).
/// Otherwise one primary region stands in for the language. Traditional Chinese
/// uses Taiwan; every other Chinese script uses China.
public enum LanguageFlag {
    public static func emoji(for language: Locale.Language) -> String? {
        if let region = language.region?.identifier, let flag = flag(forRegionCode: region) {
            return flag
        }
        let code = language.languageCode?.identifier.lowercased() ?? ""
        if code == "zh" {
            let region = language.script?.identifier == "Hant" ? "TW" : "CN"
            return flag(forRegionCode: region)
        }
        guard let region = defaultRegion[code] else { return nil }
        return flag(forRegionCode: region)
    }

    /// The name with its flag in front, or the name alone when no flag exists.
    public static func labeled(_ name: String, language: Locale.Language) -> String {
        guard let flag = emoji(for: language) else { return name }
        return "\(flag) \(name)"
    }

    public static func flag(forRegionCode regionCode: String) -> String? {
        let letters = regionCode.uppercased()
        guard letters.count == 2 else { return nil }
        var output = ""
        for scalar in letters.unicodeScalars {
            guard (65...90).contains(scalar.value) else { return nil }
            guard let regional = UnicodeScalar(127397 + scalar.value) else { return nil }
            output.unicodeScalars.append(regional)
        }
        return output
    }

    private static let defaultRegion: [String: String] = [
        "ar": "SA",
        "de": "DE",
        "en": "US",
        "es": "ES",
        "fr": "FR",
        "it": "IT",
        "ja": "JP",
        "ko": "KR",
        "nl": "NL",
        "pt": "PT",
        "ru": "RU",
        "zh": "CN",
    ]
}
