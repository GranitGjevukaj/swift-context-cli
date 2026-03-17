import Foundation

public enum OutputFormat: String, Sendable {
    case json
    case markdown
    case both
}

public enum GraphType: String, Sendable {
    case navigation
    case dependency
    case binding
}

public enum GraphFormat: String, Sendable {
    case json
    case mermaid
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
        let manifest = try buildManifest(projectPath: options.projectPath)

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

    public func graph(projectPath: String?, type: GraphType, format: GraphFormat) throws -> String {
        let manifest = try buildManifest(projectPath: projectPath)

        switch (type, format) {
        case (.navigation, .json):
            return try encodeJSON(manifest.navigationGraph)
        case (.navigation, .mermaid):
            return MermaidEmitter.emitNavigation(graph: manifest.navigationGraph)

        case (.dependency, .json):
            return try encodeJSON(manifest.dependencyGraph)
        case (.dependency, .mermaid):
            return MermaidEmitter.emitDependency(graph: manifest.dependencyGraph)

        case (.binding, .json):
            return try encodeJSON(manifest.viewBindings)
        case (.binding, .mermaid):
            return MermaidEmitter.emitBindings(bindings: manifest.viewBindings)
        }
    }

    public func buildManifest(projectPath: String?) throws -> ContextManifest {
        let project = try ProjectLocator.resolve(from: projectPath)

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

        let viewBindings = ViewBindingGraphBuilder.build(modules: modules)
        let navigationGraph = NavigationGraphBuilder.build(modules: modules)
        let dependencyGraph = DependencyGraphBuilder.build(modules: modules)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        return ContextManifest(
            version: "0.3.0",
            project: ProjectOverview(
                name: project.name,
                kind: project.kind.rawValue,
                rootPath: project.rootPath,
                minimumDeploymentTarget: project.minimumDeploymentTarget,
                generatedAt: timestamp
            ),
            modules: modules,
            viewBindings: viewBindings,
            navigationGraph: navigationGraph,
            dependencyGraph: dependencyGraph
        )
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard let output = String(data: data, encoding: .utf8) else {
            throw SwiftContextError.jsonEncodingFailed
        }
        return output + "\n"
    }
}
