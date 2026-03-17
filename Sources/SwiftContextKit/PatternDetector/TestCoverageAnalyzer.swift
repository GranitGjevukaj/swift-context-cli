import Foundation

public enum TestCoverageAnalyzer {
    public static func analyze(targetSourceFilesByModule: [String: [String]], modules: [ModuleInfo]) -> [ModuleTestCoverage] {
        let testModules = modules.filter { isTestModule($0.name) }
        let testTypeNamesByModule: [String: Set<String>] = Dictionary(
            uniqueKeysWithValues: testModules.map { module in
                let typeNames = Set(module.types.map(\.name))
                return (module.name, typeNames)
            }
        )

        return modules
            .filter { !isTestModule($0.name) }
            .map { module in
                let candidateTestModules = relatedTestModules(for: module.name, availableTestModules: testModules.map(\.name))
                let testedNames = Set(
                    candidateTestModules
                        .flatMap { testTypeNamesByModule[$0] ?? [] }
                        .map { strippedTestSuffix($0) }
                )

                let sourceTypeNames = module.types
                    .filter { !isTestType($0) }
                    .map(\.name)

                let testedTypes = sourceTypeNames.filter { testedNames.contains($0) }.sorted()
                let untestedTypes = sourceTypeNames.filter { !testedNames.contains($0) }.sorted()

                let sourceFiles = targetSourceFilesByModule[module.name] ?? []
                let candidateTestFiles = candidateTestModules.flatMap { targetSourceFilesByModule[$0] ?? [] }
                let testFileSet = Set(candidateTestFiles.map { URL(fileURLWithPath: $0).lastPathComponent })

                let fileMatches = sourceFiles.map { sourceFile -> FileCoverageMatch in
                    let basename = URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
                    let expected = basename + "Tests.swift"
                    let matched = candidateTestFiles.first {
                        URL(fileURLWithPath: $0).lastPathComponent == expected
                    }
                    return FileCoverageMatch(sourceFile: sourceFile, expectedTestFile: expected, matchedTestFile: matched ?? (testFileSet.contains(expected) ? expected : nil))
                }

                return ModuleTestCoverage(
                    module: module.name,
                    testedTypes: testedTypes,
                    untestedTypes: untestedTypes,
                    fileMatches: fileMatches.sorted { $0.sourceFile < $1.sourceFile }
                )
            }
            .sorted { $0.module < $1.module }
    }

    private static func isTestModule(_ name: String) -> Bool {
        name.lowercased().contains("test")
    }

    private static func strippedTestSuffix(_ name: String) -> String {
        if name.hasSuffix("Tests") {
            return String(name.dropLast("Tests".count))
        }
        if name.hasSuffix("Test") {
            return String(name.dropLast("Test".count))
        }
        return name
    }

    private static func isTestType(_ type: TypeInfo) -> Bool {
        type.name.hasSuffix("Test") || type.name.hasSuffix("Tests") || type.conformances.contains("XCTestCase")
    }

    private static func relatedTestModules(for sourceModule: String, availableTestModules: [String]) -> [String] {
        let lower = sourceModule.lowercased()
        return availableTestModules.filter { candidate in
            let candidateLower = candidate.lowercased()
            return candidateLower.contains(lower) || lower.contains(candidateLower.replacingOccurrences(of: "tests", with: ""))
        }
    }
}
