import SwiftUI

/// Sort, filter, and translation controls for the feedback list toolbar.
///
/// While a status or category filter is active the button fills its glyph and takes the
/// prominent style, and its accessibility value names the filter.
struct FeedbackListSortFilterMenu: View {
    @Binding var selectedSort: FeedbackSortOption
    @Binding var filter: FeedbackListFilter
    let showsStatusFilter: Bool
    let showsCategoryFilter: Bool
    let orderedTargets: [Locale.Language]
    @Binding var chosenTarget: Locale.Language?
    let displayLocale: Locale
    let tint: Color

    var body: some View {
        let menu = Menu {
            // The host tint is for the toolbar button only; menu rows keep the label colour.
            Group {
                Picker(selection: $selectedSort) {
                    ForEach(FeedbackSortOption.allCases, id: \.self) { option in
                        Label(option.localizedName, systemImage: option.systemImage)
                            .tag(option)
                    }
                } label: {
                    Text(String(localized: .menuSortBy))
                }
                .pickerStyle(.inline)

                if showsStatusFilter || showsCategoryFilter {
                    Section {
                        if showsStatusFilter {
                            Picker(selection: $filter.status) {
                                Text(String(localized: .filterAllStatuses))
                                    .tag(FeedbackStatus?.none)
                                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                    Label(
                                        status.localizedDisplayName,
                                        systemImage: FeedbackStatusGlyphShape(status: status).menuSymbolName
                                    )
                                    .tag(FeedbackStatus?.some(status))
                                }
                            } label: {
                                Label(String(localized: .toolbarStatus), systemImage: "circle.dotted.circle")
                            }
                            .pickerStyle(.menu)
                        }

                        if showsCategoryFilter {
                            Picker(selection: $filter.category) {
                                Text(String(localized: .filterAllCategories))
                                    .tag(FeedbackCategory?.none)
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    Label(category.localizedPluralName, systemImage: category.iconName)
                                        .tag(FeedbackCategory?.some(category))
                                }
                            } label: {
                                Label(String(localized: .toolbarCategory), systemImage: "tag")
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text(String(localized: .menuFilter))
                    }
                }

                TranslationTargetPicker(
                    targets: orderedTargets,
                    selection: $chosenTarget,
                    displayLocale: displayLocale
                )

                if filter.isActive {
                    Section {
                        Button(role: .destructive) {
                            filter.clear()
                        } label: {
                            Label(String(localized: .filterClearFilters), systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .tint(Color.primary)
        } label: {
            Label(
                String(localized: .toolbarSortAndFilter),
                systemImage: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease"
            )
        }
        .tint(tint)
        .accessibilityValue(filter.menuAccessibilityValue(sort: selectedSort))
        .accessibilityIdentifier("fbk-sort-filter-menu")

        if filter.isActive {
            #if os(iOS) || os(macOS)
            menu.buttonStyle(.glassProminent)
            #elseif os(visionOS)
            menu.buttonStyle(.borderedProminent)
            #endif
        } else {
            menu
        }
    }
}
