import Testing
@testable import SwiftContextKit

struct ViewBindingGraphBuilderTests {
    @Test
    func buildsViewModelBindingsAndReactiveSurface() {
        let source = """
        import SwiftUI
        import Combine

        final class DashboardViewModel: ObservableObject {
            @Published var isLoading = false
            @Published var title = "Demo"
        }

        struct DashboardView: View {
            @StateObject private var viewModel = DashboardViewModel()
            var body: some View { Text(viewModel.title) }
        }

        struct DetailsView: View {
            @ObservedObject var viewModel: DashboardViewModel
            var body: some View { Text(viewModel.title) }
        }
        """

        let analysis = FileAnalyzer.analyze(source: source, path: "/tmp/Dashboard.swift")
        let module = ModuleInfo(
            name: "Dashboard",
            sourceFileCount: 1,
            imports: analysis.imports,
            types: analysis.types
        )

        let bindings = ViewBindingGraphBuilder.build(modules: [module])
        #expect(bindings.count == 2)

        let dashboardBinding = bindings.first { $0.viewType == "DashboardView" }
        #expect(dashboardBinding?.viewModelType == "DashboardViewModel")
        #expect(dashboardBinding?.wrapper == "StateObject")
        #expect(dashboardBinding?.publishedProperties == ["isLoading", "title"])

        let detailsBinding = bindings.first { $0.viewType == "DetailsView" }
        #expect(detailsBinding?.viewModelType == "DashboardViewModel")
        #expect(detailsBinding?.wrapper == "ObservedObject")
    }
}
