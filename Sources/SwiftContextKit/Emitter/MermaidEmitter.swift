import Foundation

public enum MermaidEmitter {
    public static func emitNavigation(graph: NavigationGraph) -> String {
        var lines: [String] = ["graph TD"]

        if graph.coordinators.isEmpty, graph.viewSurfaces.isEmpty {
            lines.append("  empty[\"No navigation signals detected\"]")
            return lines.joined(separator: "\n") + "\n"
        }

        for coordinator in graph.coordinators {
            let id = nodeID(module: coordinator.module, name: coordinator.name)
            lines.append("  \(id)[\"\(coordinator.name) (Coordinator)\"]")
        }

        for edge in graph.edges {
            let fromID = nodeID(module: edge.module, name: edge.from)
            let toID = nodeID(module: edge.module, name: edge.to)
            lines.append("  \(fromID) -->|\(edge.relation)| \(toID)")
        }

        for surface in graph.viewSurfaces {
            let id = nodeID(module: surface.module, name: surface.viewType)
            let apis = surface.apis.joined(separator: ", ")
            lines.append("  \(id)[\"\(surface.viewType)\\n\(apis)\"]")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func emitDependency(graph: DependencyGraph) -> String {
        var lines: [String] = ["graph LR"]

        if graph.edges.isEmpty {
            lines.append("  empty[\"No protocol-to-concrete mappings detected\"]")
            return lines.joined(separator: "\n") + "\n"
        }

        for edge in graph.edges {
            let protocolID = nodeID(module: edge.module, name: edge.protocolType)
            let concreteID = nodeID(module: edge.module, name: edge.concreteType)
            lines.append("  \(protocolID){\"\(edge.protocolType)\"}")
            lines.append("  \(concreteID)[\"\(edge.concreteType)\"]")
            lines.append("  \(protocolID) --> \(concreteID)")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func emitBindings(bindings: [ViewBinding]) -> String {
        var lines: [String] = ["graph LR"]

        if bindings.isEmpty {
            lines.append("  empty[\"No view bindings detected\"]")
            return lines.joined(separator: "\n") + "\n"
        }

        for binding in bindings {
            let viewID = nodeID(module: binding.module, name: binding.viewType)
            let vmID = nodeID(module: binding.module, name: binding.viewModelType)
            lines.append("  \(viewID)[\"\(binding.viewType)\"]")
            lines.append("  \(vmID)[\"\(binding.viewModelType)\"]")
            lines.append("  \(viewID) -->|@\(binding.wrapper)| \(vmID)")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func nodeID(module: String, name: String) -> String {
        let combined = "\(module)_\(name)"
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        return combined
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
    }
}
