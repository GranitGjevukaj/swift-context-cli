import Foundation

public enum SwiftContextError: Error, LocalizedError {
    case projectNotFound(path: String)
    case pathDoesNotExist(path: String)
    case directoryListingFailed(path: String, underlying: Error)
    case fileReadFailed(path: String, underlying: Error)
    case fileAnalysisFailed(path: String, underlying: Error)
    case outputWriteFailed(path: String, underlying: Error)
    case jsonEncodingFailed
    case moduleNotFound(name: String)
    case invalidExportFormat(String)
    case invalidLogLevelConfiguration
    case configNotFound(path: String)
    case invalidConfig(path: String, line: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let path):
            return "Could not find a .xcodeproj or Package.swift at \(path)."
        case .pathDoesNotExist(let path):
            return "Path does not exist: \(path)."
        case .directoryListingFailed(let path, let underlying):
            return "Failed to read directory at \(path): \(underlying.localizedDescription)"
        case .fileReadFailed(let path, let underlying):
            return "Failed to read file at \(path): \(underlying.localizedDescription)"
        case .fileAnalysisFailed(let path, let underlying):
            return "Failed to analyze Swift file \(path): \(underlying.localizedDescription)"
        case .outputWriteFailed(let path, let underlying):
            return "Failed to write output at \(path): \(underlying.localizedDescription)"
        case .jsonEncodingFailed:
            return "Failed to encode manifest as UTF-8 JSON."
        case .moduleNotFound(let name):
            return "Module '\(name)' was not found in this project."
        case .invalidExportFormat(let format):
            return "Unsupported export format '\(format)'."
        case .invalidLogLevelConfiguration:
            return "Cannot combine --verbose and --quiet."
        case .configNotFound(let path):
            return "Config file not found at \(path)."
        case .invalidConfig(let path, let line, let reason):
            return "Invalid config at \(path):\(line) - \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .projectNotFound:
            return "Pass --project with a directory containing Package.swift or a .xcodeproj file."
        case .pathDoesNotExist:
            return "Double-check the provided path and try again."
        case .moduleNotFound:
            return "Run analyze first to inspect module names, then retry with an exact match."
        case .invalidLogLevelConfiguration:
            return "Use only one of --verbose or --quiet."
        case .configNotFound:
            return "Create .swiftcontext.yml or pass a valid --config path."
        case .invalidConfig:
            return "Fix the line noted above. Supported sections: conventions, moduleOverrides, analysis."
        case .outputWriteFailed:
            return "Confirm the output directory exists and is writable."
        case .fileReadFailed, .fileAnalysisFailed, .directoryListingFailed, .jsonEncodingFailed, .invalidExportFormat:
            return nil
        }
    }
}
