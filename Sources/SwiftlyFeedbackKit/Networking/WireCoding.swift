import Foundation

/// The JSON strategies every SDK request and response uses.
///
/// `APIClient` installs these rather than a second copy. Dates accept the server's
/// whole-second ISO-8601 (`2023-11-14T22:13:20Z`) and the same instant with fractional
/// seconds. Unknown object keys stay ignored by `Codable`.
enum WireCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(decodeISO8601)
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decodeISO8601(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = parseISO8601(string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized ISO-8601 date"
        )
    }

    /// Fresh formatters per string. A stored `ISO8601DateFormatter` is shared by every
    /// `APIClient`, and `date(from:)` mutates the instance while it parses.
    private static func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        return internet.date(from: string)
    }
}
