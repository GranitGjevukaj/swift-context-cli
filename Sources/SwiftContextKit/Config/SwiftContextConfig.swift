import Foundation

public struct NamingConventionOverrides: Codable, Sendable, Equatable {
    public let viewModelSuffix: String?
    public let coordinatorSuffix: String?
    public let testSuffix: String?
    public let mockPrefix: String?

    public init(
        viewModelSuffix: String? = nil,
        coordinatorSuffix: String? = nil,
        testSuffix: String? = nil,
        mockPrefix: String? = nil
    ) {
        self.viewModelSuffix = viewModelSuffix
        self.coordinatorSuffix = coordinatorSuffix
        self.testSuffix = testSuffix
        self.mockPrefix = mockPrefix
    }

    public static let empty = NamingConventionOverrides()
}

public struct AnalysisConfig: Codable, Sendable, Equatable {
    public let parallelism: Int?

    public init(parallelism: Int? = nil) {
        self.parallelism = parallelism
    }

    public static let `default` = AnalysisConfig(parallelism: nil)
}

public struct SwiftContextConfig: Codable, Sendable, Equatable {
    public let conventions: NamingConventionOverrides
    public let moduleOverrides: [String: NamingConventionOverrides]
    public let analysis: AnalysisConfig

    public init(
        conventions: NamingConventionOverrides = .empty,
        moduleOverrides: [String: NamingConventionOverrides] = [:],
        analysis: AnalysisConfig = .default
    ) {
        self.conventions = conventions
        self.moduleOverrides = moduleOverrides
        self.analysis = analysis
    }

    public static let `default` = SwiftContextConfig()
}

public struct ResolvedConfig: Sendable {
    public let path: String?
    public let config: SwiftContextConfig

    public init(path: String?, config: SwiftContextConfig) {
        self.path = path
        self.config = config
    }
}
