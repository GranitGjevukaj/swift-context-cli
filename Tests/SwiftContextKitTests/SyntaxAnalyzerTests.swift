import Testing
@testable import SwiftContextKit

struct SyntaxAnalyzerTests {
    @Test
    func collectsImportsAndTypes() {
        let source = """
        import Foundation
        import SwiftUI

        public struct HomeView: View {
            var body: some View { Text("Hello") }
        }

        final class HomeViewModel: ObservableObject {
            let title = "Welcome"
        }
        """

        let analysis = FileAnalyzer.analyze(source: source)

        #expect(analysis.imports == ["Foundation", "SwiftUI"])
        #expect(analysis.types.count == 2)

        let first = analysis.types[0]
        #expect(first.name == "HomeView")
        #expect(first.kind == .struct)
        #expect(first.conformances == ["View"])

        let second = analysis.types[1]
        #expect(second.name == "HomeViewModel")
        #expect(second.kind == .class)
        #expect(second.conformances == ["ObservableObject"])
    }

    @Test
    func collectsNestedTypesAndAdditionalKinds() {
        let source = """
        struct Root {
            struct Nested {}
            actor Worker {}
        }

        protocol DataProvider {
            associatedtype Output
            func load() -> Output
        }
        """

        let analysis = FileAnalyzer.analyze(source: source)

        #expect(analysis.types.contains(where: { $0.name == "Root" && $0.kind == .struct }))
        #expect(analysis.types.contains(where: { $0.name == "Nested" && $0.kind == .struct }))
        #expect(analysis.types.contains(where: { $0.name == "Worker" && $0.kind == .actor }))
        #expect(analysis.types.contains(where: { $0.name == "DataProvider" && $0.kind == .protocol }))
    }

    @Test
    func mergesExtensionConformances() throws {
        let source = """
        struct Item {}
        extension Item: Codable, Hashable {
            func refresh() {}
        }
        """

        let analysis = FileAnalyzer.analyze(source: source)
        let item = try #require(analysis.types.first(where: { $0.name == "Item" }))

        #expect(item.conformances == ["Codable", "Hashable"])
        #expect(item.methods.contains(where: { $0.name == "refresh" }))
    }

    @Test
    func detectsPropertyWrappersAndMethodSignatures() throws {
        let source = """
        import SwiftUI
        import Combine

        final class HomeViewModel: ObservableObject {
            @Published private(set) var items: [String] = []

            public func fetch(id: Int) async throws -> String {
                "ok"
            }
        }

        struct HomeView: View {
            @StateObject private var viewModel = HomeViewModel()
            @Environment(\\.dismiss) private var dismiss
            @Binding var count: Int

            var body: some View { Text("\\(count)") }
        }
        """

        let analysis = FileAnalyzer.analyze(source: source)
        let viewModel = try #require(analysis.types.first(where: { $0.name == "HomeViewModel" }))
        let view = try #require(analysis.types.first(where: { $0.name == "HomeView" }))

        let publishedProperty = try #require(viewModel.properties.first(where: { $0.name == "items" }))
        #expect(publishedProperty.wrappers.contains("Published"))
        #expect(publishedProperty.accessLevel == "private")

        let fetchMethod = try #require(viewModel.methods.first(where: { $0.name == "fetch" }))
        #expect(fetchMethod.parameters.count == 1)
        #expect(fetchMethod.parameters[0].localName == "id")
        #expect(fetchMethod.parameters[0].typeName == "Int")
        #expect(fetchMethod.returnType == "String")
        #expect(fetchMethod.isAsync)
        #expect(fetchMethod.isThrowing)
        #expect(fetchMethod.accessLevel == "public")

        let stateObject = try #require(view.properties.first(where: { $0.wrappers.contains("StateObject") }))
        #expect(stateObject.typeName == "HomeViewModel")

        #expect(view.properties.contains(where: { $0.wrappers.contains("Environment") && $0.name == "dismiss" }))
        #expect(view.properties.contains(where: { $0.wrappers.contains("Binding") && $0.name == "count" }))
    }
}
