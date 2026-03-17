import Foundation
import Testing
@testable import SwiftContextKit

struct ProjectParserTests {
    @Test
    func detectsSPMProjectAndTargets() throws {
        let fixtureRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("SimplePackage")

        let project = try ProjectLocator.resolve(from: fixtureRoot.path)

        #expect(project.kind == .spm)
        #expect(project.targets.contains(where: { $0.name == "AppCore" }))
        #expect(project.targets.contains(where: { $0.name == "AppCoreTests" }))

        let appCore = try #require(project.targets.first(where: { $0.name == "AppCore" }))
        #expect(appCore.sourceFiles.count == 1)
    }
}
