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
}
