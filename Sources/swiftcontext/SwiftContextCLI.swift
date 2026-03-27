import ArgumentParser
import Foundation
import SwiftContextKit

@main
struct SwiftContextCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftcontext",
        abstract: "Generate AI agent context from Swift projects",
        version: "0.6.0",
        subcommands: [Analyze.self, Graph.self, Preview.self, Export.self],
        defaultSubcommand: Analyze.self
    )
}

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze a Swift project and generate context manifest"
    )

    @OptionGroup var global: GlobalCLIOptions

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Option(name: .long, help: "Output directory")
    var output: String?

    @Option(name: .long, help: "Output format: json, markdown, both")
    var format: OutputFormatOption = .both

    func run() throws {
        let runtime = try global.runtimeOptions()

        try runWithErrorHandling {
            let options = AnalyzeOptions(
                projectPath: project,
                outputPath: output,
                format: format.asOutputFormat,
                runtime: runtime
            )

            let result = try SwiftContextAnalyzer().analyze(options: options)
            guard runtime.logLevel != .quiet else {
                return
            }

            for artifact in result.artifacts {
                print("Wrote \(renderFileLocation(artifact.path))")
            }
            print("Analyzed \(result.manifest.modules.count) module(s).")
        }
    }
}

struct Graph: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate project graph output")

    @OptionGroup var global: GlobalCLIOptions

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Option(name: .long, help: "Graph type: navigation, dependency, binding")
    var type: GraphTypeOption = .navigation

    @Option(name: .long, help: "Output format: json, mermaid")
    var format: GraphFormatOption = .json

    func run() throws {
        let runtime = try global.runtimeOptions()

        try runWithErrorHandling {
            let output = try SwiftContextAnalyzer().graph(
                projectPath: project,
                type: type.asGraphType,
                format: format.asGraphFormat,
                runtime: runtime
            )
            print(output, terminator: "")
        }
    }
}

struct Preview: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Preview context for a specific module")

    @OptionGroup var global: GlobalCLIOptions

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Argument(help: "Module name")
    var moduleName: String

    @Option(name: .long, help: "Preview format: markdown, json")
    var format: PreviewFormatOption = .markdown

    func run() throws {
        let runtime = try global.runtimeOptions()

        try runWithErrorHandling {
            let output = try SwiftContextAnalyzer().preview(
                projectPath: project,
                moduleName: moduleName,
                format: format.asPreviewFormat,
                runtime: runtime
            )
            print(output, terminator: "")
        }
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export context for agent-specific formats")

    @OptionGroup var global: GlobalCLIOptions

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Option(name: .long, help: "Export format: agents-md, claude-md, cursorrules")
    var format: ExportFormatOption = .agentsMD

    @Option(name: .long, help: "Optional output file path. Prints to stdout when omitted.")
    var output: String?

    func run() throws {
        let runtime = try global.runtimeOptions()

        try runWithErrorHandling {
            let content = try SwiftContextAnalyzer().export(
                projectPath: project,
                format: format.asExportFormat,
                runtime: runtime
            )

            if let output {
                let url = URL(fileURLWithPath: output)
                let directory = url.deletingLastPathComponent()
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    throw SwiftContextError.outputWriteFailed(path: url.path, underlying: error)
                }

                if runtime.logLevel != .quiet {
                    print("Wrote \(renderFileLocation(url.path))")
                }
            } else {
                print(content, terminator: "")
            }
        }
    }
}

struct GlobalCLIOptions: ParsableArguments {
    @Flag(name: .long, help: "Enable verbose diagnostics")
    var verbose = false

    @Flag(name: .long, help: "Suppress non-error output")
    var quiet = false

    @Option(name: .long, help: "Path to .swiftcontext.yml config file")
    var config: String?

    func runtimeOptions() throws -> RuntimeOptions {
        if verbose && quiet {
            throw SwiftContextError.invalidLogLevelConfiguration
        }

        let level: LogLevel
        if quiet {
            level = .quiet
        } else if verbose {
            level = .verbose
        } else {
            level = .normal
        }

        return RuntimeOptions(logLevel: level, configPath: config)
    }
}

private func runWithErrorHandling(_ operation: () throws -> Void) throws {
    do {
        try operation()
    } catch {
        writeError(error)
        throw ExitCode.failure
    }
}

private func writeError(_ error: Error) {
    let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    let suggestion = (error as? LocalizedError)?.recoverySuggestion

    var lines = ["Error: \(description)"]
    if let suggestion, !suggestion.isEmpty {
        lines.append("Hint: \(suggestion)")
    }

    let message = lines.joined(separator: "\n") + "\n"
    FileHandle.standardError.write(Data(message.utf8))
}

private func renderFileLocation(_ path: String) -> String {
    let url = URL(fileURLWithPath: path).standardizedFileURL.absoluteString
    return "\(path) (\(url))"
}

enum OutputFormatOption: String, CaseIterable, ExpressibleByArgument {
    case json
    case markdown
    case both

    var asOutputFormat: OutputFormat {
        switch self {
        case .json:
            return .json
        case .markdown:
            return .markdown
        case .both:
            return .both
        }
    }
}

enum GraphTypeOption: String, CaseIterable, ExpressibleByArgument {
    case navigation
    case dependency
    case binding

    var asGraphType: GraphType {
        switch self {
        case .navigation:
            return .navigation
        case .dependency:
            return .dependency
        case .binding:
            return .binding
        }
    }
}

enum GraphFormatOption: String, CaseIterable, ExpressibleByArgument {
    case json
    case mermaid

    var asGraphFormat: GraphFormat {
        switch self {
        case .json:
            return .json
        case .mermaid:
            return .mermaid
        }
    }
}

enum PreviewFormatOption: String, CaseIterable, ExpressibleByArgument {
    case markdown
    case json

    var asPreviewFormat: PreviewFormat {
        switch self {
        case .markdown:
            return .markdown
        case .json:
            return .json
        }
    }
}

enum ExportFormatOption: String, CaseIterable, ExpressibleByArgument {
    case agentsMD = "agents-md"
    case claudeMD = "claude-md"
    case cursorRules = "cursorrules"

    var asExportFormat: ExportFormat {
        switch self {
        case .agentsMD:
            return .agentsMD
        case .claudeMD:
            return .claudeMD
        case .cursorRules:
            return .cursorRules
        }
    }
}
