import SwiftUI

/// The board's published contact for reporting objectionable content.
struct BoardContactFooter: View {
    let address: String

    var body: some View {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let url = URL(string: "mailto:\(trimmed)") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    Text(String(localized: .moderationContactPrompt))
                    Link(trimmed, destination: url)
                }
                VStack(spacing: 2) {
                    Text(String(localized: .moderationContactPrompt))
                    Link(trimmed, destination: url)
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }
}
