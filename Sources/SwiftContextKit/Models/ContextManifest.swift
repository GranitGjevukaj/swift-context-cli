import Foundation

public struct ProjectOverview: Codable, Sendable {
    public let name: String
    public let kind: String
    public let rootPath: String
    public let minimumDeploymentTarget: String?
    public let generatedAt: String

    public init(
        name: String,
        kind: String,
        rootPath: String,
        minimumDeploymentTarget: String?,
        generatedAt: String
    ) {
        self.name = name
        self.kind = kind
        self.rootPath = rootPath
        self.minimumDeploymentTarget = minimumDeploymentTarget
        self.generatedAt = generatedAt
    }
}

public struct ContextManifest: Codable, Sendable {
    public let version: String
    public let project: ProjectOverview
    public let modules: [ModuleInfo]
    public let viewBindings: [ViewBinding]
    public let navigationGraph: NavigationGraph
    public let dependencyGraph: DependencyGraph

    public init(
        version: String,
        project: ProjectOverview,
        modules: [ModuleInfo],
        viewBindings: [ViewBinding] = [],
        navigationGraph: NavigationGraph = .empty,
        dependencyGraph: DependencyGraph = .empty
    ) {
        self.version = version
        self.project = project
        self.modules = modules
        self.viewBindings = viewBindings
        self.navigationGraph = navigationGraph
        self.dependencyGraph = dependencyGraph
    }
}
