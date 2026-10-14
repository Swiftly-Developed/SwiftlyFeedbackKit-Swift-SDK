//  URLQueryEncoding.swift
//  SwiftlyFeedbackKit
//
//  The one place this package turns query items into a query string.
//
//  It lives beside `APIClient` rather than inside it so the rule has a single home and can
//  be exercised without the transport. `docs/standards/API-DESIGN.md` §9 asks for exactly
//  this: query building through `URLComponents`, never string interpolation.
//
//  Three steps, each measured and each load-bearing (12 hostile values, round-tripped
//  through the server's own `URLEncodedFormParser` semantics):
//
//    1. Interpolating the values into a joined string scores  7/12 — `&` injects a
//       parameter, `#` truncates the request, `+` decodes to a space, and a literal `%`
//       double-decodes.
//    2. `URLComponents` + `URLQueryItem` alone scores 11/12.
//    3. Escaping `+` to `%2B` afterwards scores 12/12. `URLQueryItem` leaves a literal `+`
//       unescaped, and Vapor's parser rewrites `+` to a space before it decodes anything
//       (`URLEncodedFormParser.swift:6`), so an event name containing a plus arrives with
//       that plus silently turned into a space.
//
//  The `+` step is why `percentEncodedQuery` is read back rather than `query`: `query`
//  returns the DECODED form, and writing that back would undo step 2 as well.

import Foundation

enum URLQueryEncoding {

    /// Percent-encodes `items` into a query string a Vapor `URLEncodedFormParser` peer
    /// decodes back to exactly the values given.
    ///
    /// - Returns: `nil` for an empty item list, so a query-less call produces a URL that is
    ///   byte-identical to one built without this function — no trailing `?`.
    static func query(_ items: [URLQueryItem]) -> String? {
        guard !items.isEmpty else { return nil }

        var components = URLComponents()
        components.queryItems = items

        guard let encoded = components.percentEncodedQuery else { return nil }

        // `URLQueryItem` treats `+` as a legal query character; Vapor plus-decodes it.
        return encoded.replacingOccurrences(of: "+", with: "%2B")
    }
}
