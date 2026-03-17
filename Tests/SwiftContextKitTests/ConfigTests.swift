import Foundation
import Testing
@testable import SwiftContextKit

struct ConfigTests {
    @Test
    func loadsConfigAndAppliesConventionOverrides() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let config = """
        conventions:
          viewModelSuffix: VM
          testSuffix: Specs
        analysis:
          parallelism: 2
        moduleOverrides:
          AppCore:
            viewModelSuffix: FeatureModel
        """

        let configURL = root.appendingPathComponent(".swiftcontext.yml")
        try config.write(to: configURL, atomically: true, encoding: .utf8)

        let resolved = try SwiftContextConfigLoader.load(projectRoot: root.path, explicitPath: nil)
        #expect(resolved.path == configURL.path)
        #expect(resolved.config.analysis.parallelism == 2)

        let module = ModuleInfo(
            name: "AppCore",
            sourceFileCount: 1,
            imports: ["Foundation"],
            types: [
                TypeInfo(name: "HomeView", kind: .struct, accessLevel: nil, conformances: ["View"], filePath: "/tmp/HomeView.swift")
            ]
        )

        let conventions = ConventionInferenceEngine.infer(modules: [module], config: resolved.config)
        let appCore = try #require(conventions.first)
        #expect(appCore.naming.viewModelSuffix == "FeatureModel")
        #expect(appCore.naming.testSuffix == "Specs")
    }

    @Test
    func reportsInvalidConfigWithLineInformation() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let config = """
        conventions
          viewModelSuffix: ViewModel
        """

        let configURL = root.appendingPathComponent(".swiftcontext.yml")
        try config.write(to: configURL, atomically: true, encoding: .utf8)

        do {
            _ = try SwiftContextConfigLoader.load(projectRoot: root.path, explicitPath: nil)
            Issue.record("Expected config parsing to fail")
        } catch let error as SwiftContextError {
            guard case .invalidConfig(let path, let line, _) = error else {
                Issue.record("Expected invalidConfig error")
                return
            }
            #expect(path == configURL.path)
            #expect(line == 1)
        }
    }

    @Test
    func reportsMissingExplicitConfigPath() {
        let missingPath = "/tmp/does-not-exist-\(UUID().uuidString).yml"

        do {
            _ = try SwiftContextConfigLoader.load(projectRoot: "/tmp", explicitPath: missingPath)
            Issue.record("Expected explicit missing config to fail")
        } catch let error as SwiftContextError {
            guard case .configNotFound(let path) = error else {
                Issue.record("Expected configNotFound error")
                return
            }
            #expect(path == missingPath)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("swiftcontext-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
