import Foundation
import Testing
@testable import SwiftContextKit

struct PatternAndExportTests {
    @Test
    func detectsMVVM_MVVMC_andTCA() {
        let mvvmModule = ModuleInfo(
            name: "MVVMModule",
            sourceFileCount: 2,
            imports: ["SwiftUI", "Combine"],
            types: [
                TypeInfo(name: "HomeView", kind: .struct, accessLevel: nil, conformances: ["View"], filePath: "/tmp/HomeView.swift"),
                TypeInfo(name: "HomeViewModel", kind: .class, accessLevel: nil, conformances: ["ObservableObject"], filePath: "/tmp/HomeViewModel.swift"),
            ]
        )

        let mvvmcModule = ModuleInfo(
            name: "MVVMCModule",
            sourceFileCount: 3,
            imports: ["SwiftUI"],
            types: [
                TypeInfo(name: "SettingsView", kind: .struct, accessLevel: nil, conformances: ["View"], filePath: "/tmp/SettingsView.swift"),
                TypeInfo(name: "SettingsViewModel", kind: .class, accessLevel: nil, conformances: ["ObservableObject"], filePath: "/tmp/SettingsViewModel.swift"),
                TypeInfo(name: "AppCoordinator", kind: .class, accessLevel: nil, conformances: ["Coordinator"], filePath: "/tmp/AppCoordinator.swift"),
            ]
        )

        let tcaModule = ModuleInfo(
            name: "TCAModule",
            sourceFileCount: 1,
            imports: ["ComposableArchitecture"],
            types: [
                TypeInfo(name: "FeatureReducer", kind: .struct, accessLevel: nil, conformances: ["Reducer"], filePath: "/tmp/FeatureReducer.swift")
            ]
        )

        let bindings = [
            ViewBinding(module: "MVVMModule", viewType: "HomeView", viewModelType: "HomeViewModel", wrapper: "StateObject", publishedProperties: []),
            ViewBinding(module: "MVVMCModule", viewType: "SettingsView", viewModelType: "SettingsViewModel", wrapper: "ObservedObject", publishedProperties: []),
        ]

        let navGraph = NavigationGraph(
            coordinators: [
                CoordinatorInfo(module: "MVVMCModule", name: "AppCoordinator", heuristics: ["name-suffix"], childCoordinators: [])
            ],
            edges: [],
            viewSurfaces: []
        )

        let patterns = ArchitecturePatternDetector.detect(
            modules: [mvvmModule, mvvmcModule, tcaModule],
            viewBindings: bindings,
            navigationGraph: navGraph
        )

        #expect(patterns.first(where: { $0.module == "MVVMModule" })?.pattern == .mvvm)
        #expect(patterns.first(where: { $0.module == "MVVMCModule" })?.pattern == .mvvmC)
        #expect(patterns.first(where: { $0.module == "TCAModule" })?.pattern == .tca)
    }

    @Test
    func infersConventionsAndCoverage() {
        let sourceModule = ModuleInfo(
            name: "AppCore",
            sourceFileCount: 2,
            imports: ["Foundation"],
            types: [
                TypeInfo(name: "HomeViewModel", kind: .class, accessLevel: nil, conformances: [], filePath: "/repo/Sources/AppCore/HomeViewModel.swift"),
                TypeInfo(name: "DataService", kind: .class, accessLevel: nil, conformances: [], filePath: "/repo/Sources/AppCore/DataService.swift"),
            ]
        )

        let testModule = ModuleInfo(
            name: "AppCoreTests",
            sourceFileCount: 1,
            imports: ["Testing"],
            types: [
                TypeInfo(name: "HomeViewModelTests", kind: .class, accessLevel: nil, conformances: ["XCTestCase"], filePath: "/repo/Tests/AppCoreTests/HomeViewModelTests.swift"),
            ]
        )

        let conventions = ConventionInferenceEngine.infer(modules: [sourceModule, testModule])
        let appCoreConventions = conventions.first(where: { $0.module == "AppCore" })
        #expect(appCoreConventions?.naming.viewModelSuffix == "ViewModel")

        let coverage = TestCoverageAnalyzer.analyze(
            targetSourceFilesByModule: [
                "AppCore": [
                    "/repo/Sources/AppCore/HomeViewModel.swift",
                    "/repo/Sources/AppCore/DataService.swift",
                ],
                "AppCoreTests": [
                    "/repo/Tests/AppCoreTests/HomeViewModelTests.swift",
                ],
            ],
            modules: [sourceModule, testModule]
        )

        let appCoreCoverage = coverage.first(where: { $0.module == "AppCore" })
        #expect(appCoreCoverage?.testedTypes == ["HomeViewModel"])
        #expect(appCoreCoverage?.untestedTypes == ["DataService"])
    }

    @Test
    func supportsPreviewAndExport() throws {
        let fixtureRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("SimplePackage")

        let analyzer = SwiftContextAnalyzer()

        let preview = try analyzer.preview(
            projectPath: fixtureRoot.path,
            moduleName: "AppCore",
            format: .markdown
        )
        #expect(preview.contains("# Module Preview: AppCore"))
        #expect(preview.contains("## Bindings"))

        let exportClaude = try analyzer.export(
            projectPath: fixtureRoot.path,
            format: .claudeMD
        )
        #expect(exportClaude.contains("# CLAUDE.md"))
        #expect(exportClaude.contains("AppCore"))

        let exportCursor = try analyzer.export(
            projectPath: fixtureRoot.path,
            format: .cursorRules
        )
        #expect(exportCursor.contains("# .cursorrules"))
    }
}
