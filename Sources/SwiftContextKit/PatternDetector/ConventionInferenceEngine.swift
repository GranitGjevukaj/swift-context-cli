import Foundation

public enum ConventionInferenceEngine {
    public static func infer(modules: [ModuleInfo], config: SwiftContextConfig = .default) -> [ModuleConvention] {
        modules.map { module in
            let names = module.types.map(\.name)

            let inferredNaming = NamingConventions(
                viewModelSuffix: dominantSuffix(in: names, candidates: ["ViewModel", "VM"]),
                coordinatorSuffix: dominantSuffix(in: names, candidates: ["Coordinator"]),
                testSuffix: dominantSuffix(in: names, candidates: ["Tests", "Test"]),
                mockPrefix: dominantPrefix(in: names, candidates: ["Mock"])
            )

            let moduleOverride = config.moduleOverrides[module.name]
            let naming = applyOverrides(
                inferred: inferredNaming,
                global: config.conventions,
                module: moduleOverride
            )

            var hints: [String] = []
            if hasFeatureFolders(module) {
                hints.append("feature-folder-layout")
            }
            if hasViewModelPairing(module) {
                hints.append("view-viewmodel-pairs")
            }
            if hasTestMirrorHint(module) {
                hints.append("test-file-mirroring")
            }

            return ModuleConvention(
                module: module.name,
                naming: naming,
                fileOrganizationHints: hints.sorted()
            )
        }
    }

    private static func applyOverrides(
        inferred: NamingConventions,
        global: NamingConventionOverrides,
        module: NamingConventionOverrides?
    ) -> NamingConventions {
        NamingConventions(
            viewModelSuffix: module?.viewModelSuffix ?? global.viewModelSuffix ?? inferred.viewModelSuffix,
            coordinatorSuffix: module?.coordinatorSuffix ?? global.coordinatorSuffix ?? inferred.coordinatorSuffix,
            testSuffix: module?.testSuffix ?? global.testSuffix ?? inferred.testSuffix,
            mockPrefix: module?.mockPrefix ?? global.mockPrefix ?? inferred.mockPrefix
        )
    }

    private static func dominantSuffix(in names: [String], candidates: [String]) -> String? {
        var winner: (suffix: String, count: Int)?
        for suffix in candidates {
            let count = names.filter { $0.hasSuffix(suffix) }.count
            if count == 0 { continue }
            if winner == nil || count > winner!.count {
                winner = (suffix, count)
            }
        }
        return winner?.suffix
    }

    private static func dominantPrefix(in names: [String], candidates: [String]) -> String? {
        var winner: (prefix: String, count: Int)?
        for prefix in candidates {
            let count = names.filter { $0.hasPrefix(prefix) }.count
            if count == 0 { continue }
            if winner == nil || count > winner!.count {
                winner = (prefix, count)
            }
        }
        return winner?.prefix
    }

    private static func hasFeatureFolders(_ module: ModuleInfo) -> Bool {
        let folders = Set(
            module.types.map { URL(fileURLWithPath: $0.filePath).deletingLastPathComponent().lastPathComponent }
        )
        return folders.count >= 2
    }

    private static func hasViewModelPairing(_ module: ModuleInfo) -> Bool {
        let viewNames = Set(module.types.filter { $0.name.hasSuffix("View") }.map { String($0.name.dropLast("View".count)) })
        let viewModelNames = Set(
            module.types
                .filter { $0.name.hasSuffix("ViewModel") }
                .map { String($0.name.dropLast("ViewModel".count)) }
        )
        return !viewNames.intersection(viewModelNames).isEmpty
    }

    private static func hasTestMirrorHint(_ module: ModuleInfo) -> Bool {
        module.name.lowercased().contains("test") || module.types.contains { $0.name.hasSuffix("Tests") }
    }
}
