import Testing

/// `FEEDBACK01` §12.3 — every key the Showcase list and the Sort & Filter menu add is present,
/// non-empty, in all eleven locales; format keys keep their placeholders.
@Suite("Feedback list catalog")
struct FeedbackListCatalogTests {

    static let locales: Set<String> = ["en", "ar", "de", "es", "fr", "it", "ja", "ko", "pt-BR", "ru", "zh-Hans"]

    static let plainKeys = [
        "menu.sortBy",
        "menu.filter",
        "toolbar.category",
        "filter.allStatuses",
        "filter.allCategories",
        "filter.clearFilters",
        "category.plural.featureRequest",
        "category.plural.bugReport",
        "category.plural.improvement",
        "category.plural.other",
        "filter.summary.clear",
        "filter.empty.title",
        "filter.empty.description",
        "accessibility.filter.clearAction",
        "accessibility.vote.lockedHint",
    ]

    /// Key and the placeholders every locale must keep.
    static let formatKeys: [(key: String, placeholders: [String])] = [
        ("filter.summary.filteredBy", ["%@"]),
        ("filter.summary.join", ["%1$@", "%2$@"]),
        ("accessibility.filter.filteredBy", ["%@"]),
        ("accessibility.filter.join", ["%1$@", "%2$@"]),
    ]

    @Test("Every new plain key has a non-empty value in all eleven locales", arguments: FeedbackListCatalogTests.plainKeys)
    func plainKeyIsComplete(_ key: String) throws {
        let values = try StringCatalogReader.allValues(for: key)
        #expect(Set(values.keys) == Self.locales, "\(key) locales: \(values.keys.sorted())")
        for (locale, strings) in values {
            #expect(!strings.isEmpty && strings.allSatisfy { !$0.isEmpty }, "\(key) is empty in \(locale)")
        }
    }

    @Test("Every new format key keeps its placeholders in all eleven locales", arguments: FeedbackListCatalogTests.formatKeys)
    func formatKeyKeepsPlaceholders(_ row: (key: String, placeholders: [String])) throws {
        let values = try StringCatalogReader.allValues(for: row.key)
        #expect(Set(values.keys) == Self.locales, "\(row.key) locales: \(values.keys.sorted())")
        for (locale, strings) in values {
            for value in strings {
                for placeholder in row.placeholders {
                    #expect(value.contains(placeholder), "\(row.key) in \(locale) lost \(placeholder): \(value)")
                }
            }
        }
    }

    @Test("TestFlight is never translated in any locale")
    func testFlightIsUntranslated() throws {
        let values = try StringCatalogReader.allValues(for: "status.testflight")
        #expect(values.count == Self.locales.count)
        for (locale, strings) in values {
            #expect(strings.allSatisfy { $0 == "TestFlight" }, "status.testflight in \(locale): \(strings)")
        }
    }

    @Test("A wrapped Filtered by row never starts a line with the separator")
    func summaryJoinSeparatorDoesNotLeadALine() throws {
        let values = try StringCatalogReader.allValues(for: "filter.summary.join")
        for (locale, strings) in values {
            for value in strings {
                #expect(!value.contains(" ·"), "filter.summary.join in \(locale) can break before the separator: \(value)")
            }
        }
    }

    @Test("The plural category names are not the singular names in English")
    func pluralsDifferFromSingulars() throws {
        for (plural, singular) in [
            ("category.plural.featureRequest", "category.featureRequest"),
            ("category.plural.bugReport", "category.bugReport"),
            ("category.plural.improvement", "category.improvement"),
        ] {
            #expect(try StringCatalogReader.englishValue(for: plural) != StringCatalogReader.englishValue(for: singular))
        }
    }
}
