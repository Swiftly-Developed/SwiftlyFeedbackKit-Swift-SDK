import Testing
@testable import SwiftlyFeedbackKit

@Suite("Vote button chrome")
struct VoteButtonChromeTests {

    @Test("A placeholder is a gray block with no stroke and no solid fill")
    func placeholderIsABlock() {
        let chrome = VoteButtonChrome.resolve(isPlaceholder: true, hasVoted: false)
        #expect(chrome.fill == .placeholder)
        #expect(chrome.showsStroke == false)
        #expect(chrome.usesSolidLabelFill == false)
    }

    @Test("A voted control is a tint wash with a stroke, never a solid fill")
    func votedIsAWash() {
        let chrome = VoteButtonChrome.resolve(isPlaceholder: false, hasVoted: true)
        #expect(chrome.fill == .tintWash)
        #expect(chrome.showsStroke == true)
        #expect(chrome.usesSolidLabelFill == false)
    }

    @Test("An unvoted control is a border only")
    func unvotedIsABorder() {
        let chrome = VoteButtonChrome.resolve(isPlaceholder: false, hasVoted: false)
        #expect(chrome.fill == .clear)
        #expect(chrome.showsStroke == true)
        #expect(chrome.usesSolidLabelFill == false)
    }

    @Test("A placeholder wins over a voted flag")
    func placeholderWins() {
        let chrome = VoteButtonChrome.resolve(isPlaceholder: true, hasVoted: true)
        #expect(chrome.fill == .placeholder)
        #expect(chrome.showsStroke == false)
    }
}
