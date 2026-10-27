import Foundation

/// The server's acknowledgement that a report or a block was stored.
///
/// A repeated report or block for the same pair also returns this. The row
/// already existed; the call still succeeded.
public struct ModerationAcknowledgement: Codable, Sendable, Equatable {
    public let ok: Bool
}
