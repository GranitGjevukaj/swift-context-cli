import Foundation
import SwiftContextKit

enum CLIError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case unsupportedSubcommand(String)

    var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .unsupportedSubcommand(let command):
            return "Subcommand '\(command)' is not implemented yet. Use 'analyze'."
        }
    }
}

@main
struct SwiftContextCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        if arguments.isEmpty {
            try runAnalyze(arguments: [])
            return
        }

        if arguments.contains("--version") || arguments.contains("-v") {
            print("swiftcontext 0.1.0")
            return
        }

        let subcommand = arguments.first ?? "analyze"
        switch subcommand {
        case "analyze":
            try runAnalyze(arguments: Array(arguments.dropFirst()))
        case "graph", "preview", "export":
            throw CLIError.unsupportedSubcommand(subcommand)
        default:
            throw CLIError.invalidArguments(usage)
        }
    }

    private static func runAnalyze(arguments: [String]) throws {
        var projectPath: String?
        var outputPath: String?
        var format: OutputFormat = .both

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--project":
                index += 1
                guard index < arguments.count else { throw CLIError.invalidArguments("Missing value for --project") }
                projectPath = arguments[index]
            case "--output":
                index += 1
                guard index < arguments.count else { throw CLIError.invalidArguments("Missing value for --output") }
                outputPath = arguments[index]
            case "--format":
                index += 1
                guard index < arguments.count else { throw CLIError.invalidArguments("Missing value for --format") }
                guard let parsed = OutputFormat(rawValue: arguments[index]) else {
                    throw CLIError.invalidArguments("Invalid --format value '\(arguments[index])'. Use json, markdown, or both.")
                }
                format = parsed
            case "--help", "-h":
                print(usage)
                return
            default:
                throw CLIError.invalidArguments("Unknown argument '\(arg)'.\n\n\(usage)")
            }
            index += 1
        }

        let options = AnalyzeOptions(
            projectPath: projectPath,
            outputPath: outputPath,
            format: format
        )
        let result = try SwiftContextAnalyzer().analyze(options: options)

        for artifact in result.artifacts {
            print("Wrote \(artifact.path)")
        }
        print("Analyzed \(result.manifest.modules.count) module(s).")
    }

    private static let usage = """
    swiftcontext — Generate AI agent context from Swift projects

    Usage:
      swiftcontext analyze [--project <path>] [--output <path>] [--format <json|markdown|both>]
      swiftcontext --version

    Defaults:
      subcommand: analyze
      --project: current directory (auto-detects .xcodeproj or Package.swift)
      --output: current directory
      --format: both
    """
}
