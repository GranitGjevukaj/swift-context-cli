import Foundation

public enum ArchitecturePattern: String, Codable, Sendable {
    case mvvm = "MVVM"
    case mvvmC = "MVVM-C"
    case tca = "TCA"
    case unknown = "Unknown"
}

public struct ModulePattern: Codable, Sendable {
    public let module: String
    public let pattern: ArchitecturePattern
    public let confidence: Double
    public let reasons: [String]

    public init(module: String, pattern: ArchitecturePattern, confidence: Double, reasons: [String]) {
        self.module = module
        self.pattern = pattern
        self.confidence = confidence
        self.reasons = reasons
    }
}

public struct NamingConventions: Codable, Sendable {
    public let viewModelSuffix: String?
    public let coordinatorSuffix: String?
    public let testSuffix: String?
    public let mockPrefix: String?

    public init(viewModelSuffix: String?, coordinatorSuffix: String?, testSuffix: String?, mockPrefix: String?) {
        self.viewModelSuffix = viewModelSuffix
        self.coordinatorSuffix = coordinatorSuffix
        self.testSuffix = testSuffix
        self.mockPrefix = mockPrefix
    }
}

public struct ModuleConvention: Codable, Sendable {
    public let module: String
    public let naming: NamingConventions
    public let fileOrganizationHints: [String]

    public init(module: String, naming: NamingConventions, fileOrganizationHints: [String]) {
        self.module = module
        self.naming = naming
        self.fileOrganizationHints = fileOrganizationHints
    }
}

public struct FileCoverageMatch: Codable, Sendable {
    public let sourceFile: String
    public let expectedTestFile: String
    public let matchedTestFile: String?

    public init(sourceFile: String, expectedTestFile: String, matchedTestFile: String?) {
        self.sourceFile = sourceFile
        self.expectedTestFile = expectedTestFile
        self.matchedTestFile = matchedTestFile
    }
}

public struct ModuleTestCoverage: Codable, Sendable {
    public let module: String
    public let testedTypes: [String]
    public let untestedTypes: [String]
    public let fileMatches: [FileCoverageMatch]

    public init(module: String, testedTypes: [String], untestedTypes: [String], fileMatches: [FileCoverageMatch]) {
        self.module = module
        self.testedTypes = testedTypes
        self.untestedTypes = untestedTypes
        self.fileMatches = fileMatches
    }
}

