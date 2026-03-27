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

public enum PreviewFormat: String, Sendable {
    case markdown
    case json
}

public struct AnalyzeOptions: Sendable {
    public let projectPath: String?
    public let outputPath: String?
    public let format: OutputFormat
    public let runtime: RuntimeOptions

    public init(
        projectPath: String?,
        outputPath: String?,
        format: OutputFormat,
        runtime: RuntimeOptions = .default
    ) {
        self.projectPath = projectPath
        self.outputPath = outputPath
        self.format = format
        self.runtime = runtime
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
        let diagnostics = makeDiagnostics(runtime: options.runtime)
        let manifest = try buildManifest(projectPath: options.projectPath, runtime: options.runtime)

        let outputDirectory = URL(fileURLWithPath: options.outputPath ?? FileManager.default.currentDirectoryPath)
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            throw SwiftContextError.outputWriteFailed(path: outputDirectory.path, underlying: error)
        }

        var artifacts: [GeneratedArtifact] = []
        switch options.format {
        case .markdown:
            let markdown = MarkdownEmitter.emit(manifest: manifest)
            let path = outputDirectory.appendingPathComponent("AGENTS.md")
            try writeOutput(markdown, to: path)
            artifacts.append(GeneratedArtifact(path: path.path))

        case .json:
            let json = try JSONEmitter.emit(manifest: manifest)
            let path = outputDirectory.appendingPathComponent(".swiftcontext.json")
            try writeOutput(json, to: path)
            artifacts.append(GeneratedArtifact(path: path.path))

        case .both:
            let markdown = MarkdownEmitter.emit(manifest: manifest)
            let markdownPath = outputDirectory.appendingPathComponent("AGENTS.md")
            try writeOutput(markdown, to: markdownPath)
            artifacts.append(GeneratedArtifact(path: markdownPath.path))

            let json = try JSONEmitter.emit(manifest: manifest)
            let jsonPath = outputDirectory.appendingPathComponent(".swiftcontext.json")
            try writeOutput(json, to: jsonPath)
            artifacts.append(GeneratedArtifact(path: jsonPath.path))
        }

        diagnostics.verbose("Generated \(artifacts.count) artifact(s) in \(outputDirectory.path).")
        return AnalyzeResult(manifest: manifest, artifacts: artifacts)
    }

    public func graph(
        projectPath: String?,
        type: GraphType,
        format: GraphFormat,
        runtime: RuntimeOptions = .default
    ) throws -> String {
        let manifest = try buildManifest(projectPath: projectPath, runtime: runtime)

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

    public func preview(
        projectPath: String?,
        moduleName: String,
        format: PreviewFormat,
        runtime: RuntimeOptions = .default
    ) throws -> String {
        let manifest = try buildManifest(projectPath: projectPath, runtime: runtime)
        guard let module = manifest.modules.first(where: { $0.name == moduleName }) else {
            throw SwiftContextError.moduleNotFound(name: moduleName)
        }

        let modulePattern = manifest.patterns.first(where: { $0.module == moduleName })
        let moduleConvention = manifest.conventions.first(where: { $0.module == moduleName })
        let moduleBindings = manifest.viewBindings.filter { $0.module == moduleName }
        let moduleCoverage = manifest.testCoverage.first(where: { $0.module == moduleName })
        let moduleCoordinators = manifest.navigationGraph.coordinators.filter { $0.module == moduleName }
        let moduleViewSurfaces = manifest.navigationGraph.viewSurfaces.filter { $0.module == moduleName }
        let moduleDependencies = manifest.dependencyGraph.edges.filter { $0.module == moduleName }

        let preview = ModulePreview(
            module: module,
            pattern: modulePattern,
            convention: moduleConvention,
            viewBindings: moduleBindings,
            coordinators: moduleCoordinators,
            viewSurfaces: moduleViewSurfaces,
            dependencies: moduleDependencies,
            coverage: moduleCoverage
        )

        switch format {
        case .json:
            return try encodeJSON(preview)
        case .markdown:
            return renderPreviewMarkdown(preview)
        }
    }

    public func export(
        projectPath: String?,
        format: ExportFormat,
        runtime: RuntimeOptions = .default
    ) throws -> String {
        let manifest = try buildManifest(projectPath: projectPath, runtime: runtime)
        return ExportEmitter.emit(manifest: manifest, format: format)
    }

    public func buildManifest(projectPath: String?, runtime: RuntimeOptions = .default) throws -> ContextManifest {
        let diagnostics = makeDiagnostics(runtime: runtime)
        diagnostics.verbose("Resolving project path...")

        let project = try ProjectLocator.resolve(from: projectPath)
        diagnostics.verbose("Analyzing project '\(project.name)' (\(project.kind.rawValue)).")

        let resolvedConfig = try SwiftContextConfigLoader.load(
            projectRoot: project.rootPath,
            explicitPath: runtime.configPath
        )

        if let configPath = resolvedConfig.path {
            diagnostics.verbose("Using config file: \(configPath)")
        } else {
            diagnostics.verbose("No .swiftcontext.yml found; using defaults.")
        }

        let targetSourceFilesByModule = Dictionary(
            uniqueKeysWithValues: project.targets.map { ($0.name, $0.sourceFiles) }
        )

        let configuredParallelism = resolvedConfig.config.analysis.parallelism
            ?? ProcessInfo.processInfo.activeProcessorCount

        let modules: [ModuleInfo] = try project.targets.map { target in
            diagnostics.verbose("Analyzing target '\(target.name)' with \(target.sourceFiles.count) source file(s).")
            let analyses = try analyzeSourceFiles(
                target.sourceFiles,
                parallelism: max(1, configuredParallelism)
            )

            var collectedImports: Set<String> = []
            var collectedTypes: [TypeInfo] = []
            for analysis in analyses {
                collectedImports.formUnion(analysis.imports)
                collectedTypes.append(contentsOf: analysis.types)
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
        let patterns = ArchitecturePatternDetector.detect(
            modules: modules,
            viewBindings: viewBindings,
            navigationGraph: navigationGraph
        )
        let conventions = ConventionInferenceEngine.infer(
            modules: modules,
            config: resolvedConfig.config
        )
        let testCoverage = TestCoverageAnalyzer.analyze(
            targetSourceFilesByModule: targetSourceFilesByModule,
            modules: modules
        )

        let timestamp = ISO8601DateFormatter().string(from: Date())
        return ContextManifest(
            version: "0.6.0",
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
            dependencyGraph: dependencyGraph,
            patterns: patterns,
            conventions: conventions,
            testCoverage: testCoverage
        )
    }

    private func analyzeSourceFiles(_ sourceFiles: [String], parallelism: Int) throws -> [FileAnalysis] {
        let orderedFiles = sourceFiles.sorted()
        guard !orderedFiles.isEmpty else {
            return []
        }

        if orderedFiles.count == 1 || parallelism <= 1 {
            return try orderedFiles.map { path in
                do {
                    return try FileAnalyzer.analyze(fileAt: path)
                } catch {
                    throw SwiftContextError.fileAnalysisFailed(path: path, underlying: error)
                }
            }
        }

        let state = ParallelAnalysisState(count: orderedFiles.count)
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = min(parallelism, orderedFiles.count)

        for (index, path) in orderedFiles.enumerated() {
            queue.addOperation {
                if state.hasFailure {
                    return
                }

                do {
                    let analysis = try FileAnalyzer.analyze(fileAt: path)
                    state.store(analysis: analysis, at: index)
                } catch {
                    state.store(error: SwiftContextError.fileAnalysisFailed(path: path, underlying: error))
                    queue.cancelAllOperations()
                }
            }
        }

        queue.waitUntilAllOperationsAreFinished()

        if let failure = state.failure {
            throw failure
        }

        return state.compactedResults()
    }

    private func makeDiagnostics(runtime: RuntimeOptions) -> Diagnostics {
        guard runtime.logLevel != .quiet else {
            return .silent
        }

        return Diagnostics(level: runtime.logLevel) { message in
            let line = "[swiftcontext] \(message)\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
    }

    private func writeOutput(_ content: String, to url: URL) throws {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw SwiftContextError.outputWriteFailed(path: url.path, underlying: error)
        }
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

    private func renderPreviewMarkdown(_ preview: ModulePreview) -> String {
        var lines: [String] = []
        lines.append("# Module Preview: \(preview.module.name)")
        lines.append("")
        lines.append("- Source files: \(preview.module.sourceFileCount)")
        lines.append("- Imports: \(preview.module.imports.isEmpty ? "none" : preview.module.imports.joined(separator: ", "))")

        if let pattern = preview.pattern {
            lines.append("- Pattern: \(pattern.pattern.rawValue) (confidence \(String(format: "%.2f", pattern.confidence)))")
        }

        if let convention = preview.convention {
            var naming: [String] = []
            if let vm = convention.naming.viewModelSuffix { naming.append("ViewModel: \(vm)") }
            if let coord = convention.naming.coordinatorSuffix { naming.append("Coordinator: \(coord)") }
            if let test = convention.naming.testSuffix { naming.append("Test: \(test)") }
            if let mock = convention.naming.mockPrefix { naming.append("Mock: \(mock)") }
            if !naming.isEmpty {
                lines.append("- Naming: \(naming.joined(separator: ", "))")
            }
        }

        lines.append("")
        lines.append("## Bindings")
        if preview.viewBindings.isEmpty {
            lines.append("No view bindings detected.")
        } else {
            for binding in preview.viewBindings {
                lines.append("- \(binding.viewType) ← \(binding.viewModelType) via @\(binding.wrapper)")
            }
        }

        lines.append("")
        lines.append("## Navigation")
        if preview.coordinators.isEmpty, preview.viewSurfaces.isEmpty {
            lines.append("No navigation signals detected.")
        } else {
            for coordinator in preview.coordinators {
                lines.append("- Coordinator: \(coordinator.name)")
            }
            for surface in preview.viewSurfaces {
                lines.append("- View: \(surface.viewType) uses \(surface.apis.joined(separator: ", "))")
            }
        }

        lines.append("")
        lines.append("## Dependencies")
        if preview.dependencies.isEmpty {
            lines.append("No protocol-to-concrete mappings detected.")
        } else {
            for edge in preview.dependencies {
                lines.append("- \(edge.protocolType) → \(edge.concreteType)")
            }
        }

        lines.append("")
        lines.append("## Test Coverage")
        if let coverage = preview.coverage {
            lines.append("- Tested types: \(coverage.testedTypes.isEmpty ? "none" : coverage.testedTypes.joined(separator: ", "))")
            lines.append("- Untested types: \(coverage.untestedTypes.isEmpty ? "none" : coverage.untestedTypes.joined(separator: ", "))")
        } else {
            lines.append("No test coverage data detected for this module.")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}

private struct ModulePreview: Codable {
    let module: ModuleInfo
    let pattern: ModulePattern?
    let convention: ModuleConvention?
    let viewBindings: [ViewBinding]
    let coordinators: [CoordinatorInfo]
    let viewSurfaces: [ViewNavigationSurface]
    let dependencies: [DependencyEdge]
    let coverage: ModuleTestCoverage?
}

private final class ParallelAnalysisState: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [FileAnalysis?]
    private var firstError: Error?

    init(count: Int) {
        self.results = Array(repeating: nil, count: count)
    }

    var hasFailure: Bool {
        lock.lock()
        defer { lock.unlock() }
        return firstError != nil
    }

    var failure: Error? {
        lock.lock()
        defer { lock.unlock() }
        return firstError
    }

    func store(analysis: FileAnalysis, at index: Int) {
        lock.lock()
        results[index] = analysis
        lock.unlock()
    }

    func store(error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func compactedResults() -> [FileAnalysis] {
        lock.lock()
        defer { lock.unlock() }
        return results.compactMap { $0 }
    }
}
