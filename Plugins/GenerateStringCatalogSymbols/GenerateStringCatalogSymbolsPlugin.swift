// GenerateStringCatalogSymbolsPlugin.swift
// SwiftlyFeedbackKit - Swift SDK for FeedbackKit
// Copyright (c) 2025 Swiftly Developed - MIT License
//
// Generates typed Swift symbols for every entry in the target's String Catalogs,
// so a call site reads `Text(.feedbackListTitle)` instead of
// `String(localized: "feedback.list.title", bundle: #bundle)` — a missing key
// becomes a compile error rather than a raw key rendered on screen, and the
// bundle is resolved by the generated code instead of by every author.
//
// WHY A PLUGIN AND NOT THE BUILD SETTING
//
// Xcode ships this feature as the `STRING_CATALOG_GENERATE_SYMBOLS` build
// setting, which is how `SwiftlyFeedbackAdmin` (a real `.xcodeproj` target)
// turns it on. That mechanism is unavailable to us, for two independent
// reasons measured on Xcode 26.6:
//
//   1. There is nowhere git-trackable to put it. A local SwiftPM package has no
//      `.xcodeproj`, so no build configuration and no `.xcconfig`; Xcode exposes
//      no Build Settings editor for a package target; `.xcscheme` files carry no
//      build settings; and `.swiftpm/` is gitignored. The setting also does NOT
//      propagate from a consuming project into an embedded package target —
//      building `SwiftlyFeedbackAdmin`, which has it ON, leaves this target's
//      catalog compiling plain.
//
//   2. More decisively, `swift build` / `swift test` do not implement the
//      setting at all, under any value or environment variable. Since
//      SwiftlyFeedbackKit is a *published* SwiftPM package, a build-setting
//      approach would leave this package's own documented workflow — and every
//      downstream consumer — unable to compile sources that reference the
//      generated symbols.
//
// A build-tool plugin lives in the manifest, so it travels with the package and
// runs identically under `swift build`, `swift test`, and a plain `xcodebuild`
// workspace build with no command-line override.
//
// CONSUMER NOTE: Xcode asks for one-time confirmation before running a package
// plugin; CI invoking `xcodebuild` non-interactively passes
// `-skipPackagePluginValidation`.
//
// See docs/specs/LOCALIZATION01-PHASE-03-SDK-CORPUS-REPAIR-AND-KEY-MIGRATION.md
// and docs/standards/LOCALIZATION.md §1.

import Foundation
import PackagePlugin

@main
struct GenerateStringCatalogSymbolsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }

        let catalogs = sourceTarget.sourceFiles
            .map(\.url)
            .filter { $0.pathExtension == "xcstrings" }
            .sorted { $0.path() < $1.path() }

        guard !catalogs.isEmpty else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL
            .appending(path: "GeneratedStringSymbols")
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        // `xcstringstool` names each output after its catalog's basename, which
        // is what lets this be a `buildCommand` with declared inputs and
        // outputs rather than a `prebuildCommand`. That distinction is
        // load-bearing: a prebuild command carries no dependency edges, so the
        // build system will happily reuse a *stale* generated file after the
        // catalog changes — measured here, and it silently defeats the whole
        // point, since a key deleted from the catalog would keep compiling
        // against a symbol that no longer has a row behind it. Declaring
        // `inputFiles`/`outputFiles` makes the regeneration a tracked edge.
        let outputs = catalogs.map {
            outputDirectory.appending(
                path: "GeneratedStringSymbols_\($0.deletingPathExtension().lastPathComponent).swift"
            )
        }

        // `xcstringstool` is reached through `xcrun` rather than an absolute
        // path so the plugin follows the selected toolchain instead of pinning
        // one Xcode location.
        return [
            .buildCommand(
                displayName: "Generate String Catalog symbols for \(target.name)",
                executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: [
                    "xcstringstool", "generate-symbols",
                    "--language", "swift",
                    "--output-directory", outputDirectory.path()
                ] + catalogs.map { $0.path() },
                inputFiles: catalogs,
                outputFiles: outputs
            )
        ]
    }
}
