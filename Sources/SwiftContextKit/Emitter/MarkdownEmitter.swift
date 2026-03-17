import Foundation

public enum MarkdownEmitter {
    public static func emit(manifest: ContextManifest) -> String {
        var lines: [String] = []
        lines.append("# Project Context: \(manifest.project.name)")
        lines.append("")
        lines.append("## Overview")
        lines.append("- Kind: \(manifest.project.kind)")
        lines.append("- Root: \(manifest.project.rootPath)")
        lines.append("- Generated: \(manifest.project.generatedAt)")

        if let minimum = manifest.project.minimumDeploymentTarget {
            lines.append("- Minimum Deployment Target: \(minimum)")
        }

        lines.append("- Modules: \(manifest.modules.count)")
        lines.append("")
        lines.append("## Module Structure")

        if manifest.modules.isEmpty {
            lines.append("No modules detected.")
        } else {
            for module in manifest.modules {
                lines.append("### \(module.name)")
                lines.append("- Source files: \(module.sourceFileCount)")
                if module.imports.isEmpty {
                    lines.append("- Imports: none")
                } else {
                    lines.append("- Imports: \(module.imports.joined(separator: ", "))")
                }

                if module.types.isEmpty {
                    lines.append("- Types: none")
                    lines.append("")
                    continue
                }

                let grouped = groupedTypes(module.types)
                lines.append("- Type Groups:")
                appendTypeGroup(named: "Views", types: grouped.views, to: &lines)
                appendTypeGroup(named: "ViewModels", types: grouped.viewModels, to: &lines)
                appendTypeGroup(named: "Coordinators", types: grouped.coordinators, to: &lines)
                appendTypeGroup(named: "Services", types: grouped.services, to: &lines)
                appendTypeGroup(named: "Protocols", types: grouped.protocols, to: &lines)
                appendTypeGroup(named: "Other Types", types: grouped.others, to: &lines)
                lines.append("")
            }
        }

        lines.append("## View ↔ ViewModel Bindings")
        if manifest.viewBindings.isEmpty {
            lines.append("No bindings detected.")
        } else {
            for binding in manifest.viewBindings {
                let published = binding.publishedProperties.isEmpty
                    ? "none"
                    : binding.publishedProperties.joined(separator: ", ")
                lines.append("- [\(binding.module)] \(binding.viewType) ← \(binding.viewModelType) via @\(binding.wrapper) (@Published: \(published))")
            }
        }

        lines.append("")
        lines.append("## Navigation Graph")
        if manifest.navigationGraph.coordinators.isEmpty, manifest.navigationGraph.viewSurfaces.isEmpty {
            lines.append("No navigation graph data detected.")
        } else {
            for coordinator in manifest.navigationGraph.coordinators {
                if coordinator.childCoordinators.isEmpty {
                    lines.append("- [\(coordinator.module)] \(coordinator.name)")
                } else {
                    lines.append("- [\(coordinator.module)] \(coordinator.name) → \(coordinator.childCoordinators.joined(separator: ", "))")
                }
            }
            for surface in manifest.navigationGraph.viewSurfaces {
                lines.append("- [\(surface.module)] \(surface.viewType) uses \(surface.apis.joined(separator: ", "))")
            }
        }

        lines.append("")
        lines.append("## Dependency Graph")
        if manifest.dependencyGraph.edges.isEmpty {
            lines.append("No protocol-to-concrete mappings detected.")
        } else {
            for edge in manifest.dependencyGraph.edges {
                lines.append("- [\(edge.module)] \(edge.protocolType) → \(edge.concreteType)")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func appendTypeGroup(named name: String, types: [TypeInfo], to lines: inout [String]) {
        guard !types.isEmpty else { return }
        lines.append("  - \(name) (\(types.count)):")
        for type in types.sorted(by: { $0.name < $1.name }) {
            lines.append("    - \(formatted(type: type))")
        }
    }

    private static func formatted(type: TypeInfo) -> String {
        let conformanceSuffix = type.conformances.isEmpty
            ? ""
            : " : \(type.conformances.joined(separator: ", "))"

        let wrapperSurface = Array(
            Set(type.properties.flatMap(\.wrappers))
        ).sorted()
        let wrapperSuffix = wrapperSurface.isEmpty
            ? ""
            : " [wrappers: \(wrapperSurface.joined(separator: ", "))]"

        let methodSuffix = type.methods.isEmpty
            ? ""
            : " [methods: \(type.methods.count)]"

        return "\(type.kind.rawValue) \(type.name)\(conformanceSuffix)\(wrapperSuffix)\(methodSuffix)"
    }

    private static func groupedTypes(_ types: [TypeInfo]) -> (
        views: [TypeInfo],
        viewModels: [TypeInfo],
        coordinators: [TypeInfo],
        services: [TypeInfo],
        protocols: [TypeInfo],
        others: [TypeInfo]
    ) {
        var views: [TypeInfo] = []
        var viewModels: [TypeInfo] = []
        var coordinators: [TypeInfo] = []
        var services: [TypeInfo] = []
        var protocols: [TypeInfo] = []
        var others: [TypeInfo] = []

        for type in types {
            if type.kind == .protocol {
                protocols.append(type)
                continue
            }
            if isView(type) {
                views.append(type)
                continue
            }
            if isViewModel(type) {
                viewModels.append(type)
                continue
            }
            if isCoordinator(type) {
                coordinators.append(type)
                continue
            }
            if isService(type) {
                services.append(type)
                continue
            }
            others.append(type)
        }

        return (views, viewModels, coordinators, services, protocols, others)
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

    private static func isService(_ type: TypeInfo) -> Bool {
        type.name.hasSuffix("Service") ||
            type.name.hasSuffix("Repository") ||
            type.name.hasSuffix("Client")
    }
}
