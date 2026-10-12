import Foundation

/// The translatable text fields of feedback content.
///
/// Detection and translation are **per field**, never per item: a single feedback item can
/// legitimately hold two languages (an English title over a German description), and a
/// per-item source language would make the affordance lie about the source.
enum TranslatableField: String, Sendable, Hashable {
    case title
    case description
    case rejectionReason
    case commentText
}
