import Foundation

public enum ProjectKind: String, Sendable {
    case xcodeproj
    case spm
}

public struct ProjectTarget: Sendable {
    public let name: String
    public let sourceFiles: [String]

    public init(name: String, sourceFiles: [String]) {
        self.name = name
        self.sourceFiles = sourceFiles
    }
}

public struct ProjectModel: Sendable {
    public let name: String
    public let kind: ProjectKind
    public let rootPath: String
    public let minimumDeploymentTarget: String?
    public let targets: [ProjectTarget]

    public init(
        name: String,
        kind: ProjectKind,
        rootPath: String,
        minimumDeploymentTarget: String?,
        targets: [ProjectTarget]
    ) {
        self.name = name
        self.kind = kind
        self.rootPath = rootPath
        self.minimumDeploymentTarget = minimumDeploymentTarget
        self.targets = targets
    }
}
