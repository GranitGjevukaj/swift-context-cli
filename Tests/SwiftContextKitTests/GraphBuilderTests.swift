import Testing
@testable import SwiftContextKit

struct GraphBuilderTests {
    @Test
    func buildsNavigationAndDependencyGraphs() {
        let source = """
        import SwiftUI

        protocol Coordinator {}
        protocol AuthService {}

        final class LiveAuthService: AuthService {}

        final class ChildCoordinator: Coordinator {}

        final class AppCoordinator: Coordinator {
            let child: ChildCoordinator

            init(child: ChildCoordinator) {
                self.child = child
            }

            func start() {}
        }

        struct HomeView: View {
            @State private var path = NavigationPath()

            var body: some View {
                NavigationStack {
                    Text("Home")
                        .sheet(isPresented: .constant(false)) { Text("Sheet") }
                        .fullScreenCover(isPresented: .constant(false)) { Text("Fullscreen") }
                }
            }
        }
        """

        let analysis = FileAnalyzer.analyze(source: source, path: "/tmp/GraphFixture.swift")
        let module = ModuleInfo(
            name: "GraphFixture",
            sourceFileCount: 1,
            imports: analysis.imports,
            types: analysis.types
        )

        let navigationGraph = NavigationGraphBuilder.build(modules: [module])
        #expect(navigationGraph.coordinators.contains(where: { $0.name == "AppCoordinator" }))
        #expect(navigationGraph.coordinators.contains(where: { $0.name == "ChildCoordinator" }))
        #expect(navigationGraph.edges.contains(where: { $0.from == "AppCoordinator" && $0.to == "ChildCoordinator" }))

        let homeViewSurface = navigationGraph.viewSurfaces.first(where: { $0.viewType == "HomeView" })
        #expect(homeViewSurface?.apis.contains("NavigationStack") == true)
        #expect(homeViewSurface?.apis.contains("NavigationPath") == true)
        #expect(homeViewSurface?.apis.contains("sheet") == true)
        #expect(homeViewSurface?.apis.contains("fullScreenCover") == true)

        let dependencyGraph = DependencyGraphBuilder.build(modules: [module])
        #expect(dependencyGraph.edges.contains(where: {
            $0.protocolType == "AuthService" && $0.concreteType == "LiveAuthService"
        }))
    }

    @Test
    func emitsMermaidForNavigationAndDependencyGraphs() {
        let navigation = NavigationGraph(
            coordinators: [
                CoordinatorInfo(module: "Core", name: "AppCoordinator", heuristics: ["name-suffix"], childCoordinators: ["HomeCoordinator"]),
                CoordinatorInfo(module: "Core", name: "HomeCoordinator", heuristics: ["name-suffix"], childCoordinators: []),
            ],
            edges: [
                NavigationEdge(module: "Core", from: "AppCoordinator", to: "HomeCoordinator", relation: "childCoordinator")
            ],
            viewSurfaces: [
                ViewNavigationSurface(module: "Core", viewType: "HomeView", apis: ["NavigationStack", "sheet"])
            ]
        )

        let dependency = DependencyGraph(
            edges: [
                DependencyEdge(module: "Core", protocolType: "AuthService", concreteType: "LiveAuthService")
            ]
        )

        let navigationMermaid = MermaidEmitter.emitNavigation(graph: navigation)
        #expect(navigationMermaid.contains("graph TD"))
        #expect(navigationMermaid.contains("AppCoordinator"))
        #expect(navigationMermaid.contains("childCoordinator"))

        let dependencyMermaid = MermaidEmitter.emitDependency(graph: dependency)
        #expect(dependencyMermaid.contains("graph LR"))
        #expect(dependencyMermaid.contains("AuthService"))
        #expect(dependencyMermaid.contains("LiveAuthService"))
    }
}
