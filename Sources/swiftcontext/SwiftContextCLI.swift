import ArgumentParser
import Foundation
import SwiftContextKit

@main
struct SwiftContextCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftcontext",
        abstract: "Generate AI agent context from Swift projects",
        version: "0.3.0",
        subcommands: [Analyze.self, Graph.self, Preview.self, Export.self],
        defaultSubcommand: Analyze.self
    )
}

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze a Swift project and generate context manifest"
    )

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Option(name: .long, help: "Output directory")
    var output: String?

    @Option(name: .long, help: "Output format: json, markdown, both")
    var format: OutputFormatOption = .both

    func run() throws {
        let options = AnalyzeOptions(
            projectPath: project,
            outputPath: output,
            format: format.asOutputFormat
        )

        let result = try SwiftContextAnalyzer().analyze(options: options)
        for artifact in result.artifacts {
            print("Wrote \(artifact.path)")
        }
        print("Analyzed \(result.manifest.modules.count) module(s).")
    }
}

struct Graph: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Generate project graph output")

    @Option(name: .long, help: "Path to .xcodeproj or Package.swift directory")
    var project: String?

    @Option(name: .long, help: "Graph type: navigation, dependency, binding")
    var type: GraphTypeOption = .navigation

    @Option(name: .long, help: "Output format: json, mermaid")
    var format: GraphFormatOption = .json

    func run() throws {
        let output = try SwiftContextAnalyzer().graph(
            projectPath: project,
            type: type.asGraphType,
            format: format.asGraphFormat
        )
        print(output, terminator: "")
    }
}

struct Preview: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Preview context for a specific module")

    @Argument(help: "Module name")
    var moduleName: String

    func run() throws {
        _ = moduleName
        throw ValidationError("The 'preview' subcommand is not implemented yet.")
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export context for agent-specific formats")

    func run() throws {
        throw ValidationError("The 'export' subcommand is not implemented yet.")
    }
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
