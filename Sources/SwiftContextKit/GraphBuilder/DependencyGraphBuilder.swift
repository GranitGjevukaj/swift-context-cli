import Foundation

public enum DependencyGraphBuilder {
    public static func build(modules: [ModuleInfo]) -> DependencyGraph {
        var protocolNamesByModule: [String: Set<String>] = [:]

        for module in modules {
            protocolNamesByModule[module.name] = Set(
                module.types
                    .filter { $0.kind == .protocol }
                    .map(\.name)
            )
        }

        var edges: Set<String> = []
        var resolvedEdges: [DependencyEdge] = []

        for module in modules {
            let localProtocols = protocolNamesByModule[module.name] ?? []

            for type in module.types where type.kind != .protocol {
                for conformance in type.conformances {
                    guard localProtocols.contains(conformance) else { continue }
                    let key = "\(module.name)::\(conformance)->\(type.name)"
                    guard !edges.contains(key) else { continue }
                    edges.insert(key)
                    resolvedEdges.append(
                        DependencyEdge(
                            module: module.name,
                            protocolType: conformance,
                            concreteType: type.name
                        )
                    )
                }
            }
        }

        return DependencyGraph(
            edges: resolvedEdges.sorted {
                if $0.module != $1.module { return $0.module < $1.module }
                if $0.protocolType != $1.protocolType { return $0.protocolType < $1.protocolType }
                return $0.concreteType < $1.concreteType
            }
        )
    }
}
