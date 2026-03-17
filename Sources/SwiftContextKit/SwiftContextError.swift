import Foundation

public enum SwiftContextError: Error, LocalizedError {
    case projectNotFound(path: String)
    case directoryListingFailed(path: String, underlying: Error)
    case jsonEncodingFailed
    case moduleNotFound(name: String)
    case invalidExportFormat(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let path):
            return "Could not find a .xcodeproj or Package.swift at \(path)."
        case .directoryListingFailed(let path, let underlying):
            return "Failed to read directory at \(path): \(underlying.localizedDescription)"
        case .jsonEncodingFailed:
            return "Failed to encode manifest as UTF-8 JSON."
        case .moduleNotFound(let name):
            return "Module '\(name)' was not found in this project."
        case .invalidExportFormat(let format):
            return "Unsupported export format '\(format)'."
        }
    }
}
