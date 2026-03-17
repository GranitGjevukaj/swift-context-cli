import Foundation

public enum OutputFormat: String, Sendable {
    case json
    case markdown
    case both
}

public struct AnalyzeOptions: Sendable {
    public let projectPath: String?
    public let outputPath: String?
    public let format: OutputFormat

    public init(projectPath: String?, outputPath: String?, format: OutputFormat) {
        self.projectPath = projectPath
        self.outputPath = outputPath
        self.format = format
    }
}

public struct GeneratedArtifact: Sendable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

public struct AnalyzeResult: Sendable {
    public let manifest: ContextManifest
    public let artifacts: [GeneratedArtifact]

    public init(manifest: ContextManifest, artifacts: [GeneratedArtifact]) {
        self.manifest = manifest
        self.artifacts = artifacts
    }
}

public struct SwiftContextAnalyzer: Sendable {
    public init() {}

    public func analyze(options: AnalyzeOptions) throws -> AnalyzeResult {
        let project = try ProjectLocator.resolve(from: options.projectPath)

        let modules: [ModuleInfo] = try project.targets.map { target in
            var collectedImports: Set<String> = []
            var collectedTypes: [TypeInfo] = []

            for sourceFile in target.sourceFiles {
                let fileAnalysis = try FileAnalyzer.analyze(fileAt: sourceFile)
                collectedImports.formUnion(fileAnalysis.imports)
                collectedTypes.append(contentsOf: fileAnalysis.types)
            }

            return ModuleInfo(
                name: target.name,
                sourceFileCount: target.sourceFiles.count,
                imports: collectedImports.sorted(),
                types: collectedTypes
            )
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let manifest = ContextManifest(
            version: "0.1.0",
            project: ProjectOverview(
                name: project.name,
                kind: project.kind.rawValue,
                rootPath: project.rootPath,
                minimumDeploymentTarget: project.minimumDeploymentTarget,
                generatedAt: timestamp
            ),
            modules: modules
        )

        let outputDirectory = URL(fileURLWithPath: options.outputPath ?? FileManager.default.currentDirectoryPath)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var artifacts: [GeneratedArtifact] = []
        switch options.format {
        case .markdown:
            let markdown = MarkdownEmitter.emit(manifest: manifest)
            let path = outputDirectory.appendingPathComponent("AGENTS.md")
            try markdown.write(to: path, atomically: true, encoding: .utf8)
            artifacts.append(GeneratedArtifact(path: path.path))
        case .json:
            let json = try JSONEmitter.emit(manifest: manifest)
            let path = outputDirectory.appendingPathComponent(".swiftcontext.json")
            try json.write(to: path, atomically: true, encoding: .utf8)
            artifacts.append(GeneratedArtifact(path: path.path))
        case .both:
            let markdown = MarkdownEmitter.emit(manifest: manifest)
            let markdownPath = outputDirectory.appendingPathComponent("AGENTS.md")
            try markdown.write(to: markdownPath, atomically: true, encoding: .utf8)
            artifacts.append(GeneratedArtifact(path: markdownPath.path))

            let json = try JSONEmitter.emit(manifest: manifest)
            let jsonPath = outputDirectory.appendingPathComponent(".swiftcontext.json")
            try json.write(to: jsonPath, atomically: true, encoding: .utf8)
            artifacts.append(GeneratedArtifact(path: jsonPath.path))
        }

        return AnalyzeResult(manifest: manifest, artifacts: artifacts)
    }
}
