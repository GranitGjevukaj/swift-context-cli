import Foundation

public enum NavigationGraphBuilder {
    public static func build(modules: [ModuleInfo]) -> NavigationGraph {
        let coordinators = CoordinatorDetector.detect(in: modules)

        var edges: [NavigationEdge] = []
        for coordinator in coordinators {
            for child in coordinator.childCoordinators {
                edges.append(
                    NavigationEdge(
                        module: coordinator.module,
                        from: coordinator.name,
                        to: child,
                        relation: "childCoordinator"
                    )
                )
            }
        }

        let viewSurfaces = modules.flatMap { module in
            module.types.compactMap { type -> ViewNavigationSurface? in
                guard isView(type), !type.navigationSignals.isEmpty else { return nil }
                return ViewNavigationSurface(
                    module: module.name,
                    viewType: type.name,
                    apis: type.navigationSignals.sorted()
                )
            }
        }
        .sorted {
            if $0.module != $1.module { return $0.module < $1.module }
            return $0.viewType < $1.viewType
        }

        return NavigationGraph(
            coordinators: coordinators,
            edges: edges.sorted {
                if $0.module != $1.module { return $0.module < $1.module }
                if $0.from != $1.from { return $0.from < $1.from }
                return $0.to < $1.to
            },
            viewSurfaces: viewSurfaces
        )
    }

    private static func isView(_ type: TypeInfo) -> Bool {
        type.conformances.contains("View") || type.name.hasSuffix("View")
    }
}
