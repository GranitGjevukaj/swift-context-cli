import Foundation

public enum ArchitecturePatternDetector {
    public static func detect(modules: [ModuleInfo], viewBindings: [ViewBinding], navigationGraph: NavigationGraph) -> [ModulePattern] {
        modules.map { module in
            detect(module: module, viewBindings: viewBindings, navigationGraph: navigationGraph)
        }
    }

    private static func detect(module: ModuleInfo, viewBindings: [ViewBinding], navigationGraph: NavigationGraph) -> ModulePattern {
        let moduleBindings = viewBindings.filter { $0.module == module.name }
        let moduleCoordinators = navigationGraph.coordinators.filter { $0.module == module.name }
        let moduleImports = Set(module.imports)

        let hasViews = module.types.contains { isView($0) }
        let hasViewModels = module.types.contains { isViewModel($0) }
        let hasCoordinator = !moduleCoordinators.isEmpty || module.types.contains { isCoordinator($0) }

        let hasTCAImport = moduleImports.contains("ComposableArchitecture")
        let hasReducerConformance = module.types.contains { $0.conformances.contains("Reducer") }
        let usesStore = module.types.contains { type in
            type.properties.contains { ($0.typeName ?? "").contains("Store") } ||
                type.methods.contains { method in method.parameters.contains { $0.typeName.contains("Store") } }
        }

        if hasTCAImport || hasReducerConformance {
            return ModulePattern(
                module: module.name,
                pattern: .tca,
                confidence: confidence(hasTCAImport: hasTCAImport, hasReducerConformance: hasReducerConformance, usesStore: usesStore),
                reasons: reasonsForTCA(hasTCAImport: hasTCAImport, hasReducerConformance: hasReducerConformance, usesStore: usesStore)
            )
        }

        if hasViews, hasViewModels, hasCoordinator {
            return ModulePattern(
                module: module.name,
                pattern: .mvvmC,
                confidence: confidenceFrom(base: 0.62, bonus: moduleBindings.isEmpty ? 0.06 : 0.18),
                reasons: ["views-and-viewmodels", "coordinator-detected"] + (moduleBindings.isEmpty ? [] : ["view-bindings-detected"])
            )
        }

        if hasViews, hasViewModels {
            return ModulePattern(
                module: module.name,
                pattern: .mvvm,
                confidence: confidenceFrom(base: 0.58, bonus: moduleBindings.isEmpty ? 0.08 : 0.2),
                reasons: ["views-and-viewmodels"] + (moduleBindings.isEmpty ? [] : ["view-bindings-detected"])
            )
        }

        return ModulePattern(
            module: module.name,
            pattern: .unknown,
            confidence: 0.3,
            reasons: ["insufficient-signals"]
        )
    }

    private static func isView(_ type: TypeInfo) -> Bool {
        type.conformances.contains("View") || type.name.hasSuffix("View")
    }

    private static func isViewModel(_ type: TypeInfo) -> Bool {
        type.conformances.contains("ObservableObject") ||
            type.name.hasSuffix("ViewModel") ||
            type.name.hasSuffix("VM")
    }

    private static func isCoordinator(_ type: TypeInfo) -> Bool {
        type.conformances.contains("Coordinator") || type.name.hasSuffix("Coordinator")
    }

    private static func reasonsForTCA(hasTCAImport: Bool, hasReducerConformance: Bool, usesStore: Bool) -> [String] {
        var reasons: [String] = []
        if hasTCAImport { reasons.append("composable-architecture-import") }
        if hasReducerConformance { reasons.append("reducer-conformance") }
        if usesStore { reasons.append("store-usage") }
        return reasons
    }

    private static func confidence(hasTCAImport: Bool, hasReducerConformance: Bool, usesStore: Bool) -> Double {
        var score = 0.45
        if hasTCAImport { score += 0.25 }
        if hasReducerConformance { score += 0.2 }
        if usesStore { score += 0.1 }
        return min(score, 0.98)
    }

    private static func confidenceFrom(base: Double, bonus: Double) -> Double {
        min(base + bonus, 0.98)
    }
}
