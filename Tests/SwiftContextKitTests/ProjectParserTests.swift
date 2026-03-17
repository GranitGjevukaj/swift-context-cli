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

    @Test
    func detectsXcodeProjectTargetsAndSourceMembership() throws {
        let fixtureRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("SimpleXcodeProject")

        let project = try ProjectLocator.resolve(from: fixtureRoot.path)

        #expect(project.kind == .xcodeproj)
        #expect(project.minimumDeploymentTarget == "17.0")
        #expect(project.targets.contains(where: { $0.name == "DemoApp" }))
        #expect(project.targets.contains(where: { $0.name == "DemoAppTests" }))

        let appTarget = try #require(project.targets.first(where: { $0.name == "DemoApp" }))
        #expect(appTarget.sourceFiles.count == 1)
        #expect(appTarget.sourceFiles[0].hasSuffix("/Sources/DemoApp/AppModel.swift"))

        let testTarget = try #require(project.targets.first(where: { $0.name == "DemoAppTests" }))
        #expect(testTarget.sourceFiles.count == 1)
        #expect(testTarget.sourceFiles[0].hasSuffix("/Tests/DemoAppTests/AppModelTests.swift"))
    }
}
