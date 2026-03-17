import Foundation

public enum LogLevel: String, Sendable {
    case quiet
    case normal
    case verbose
}

public struct RuntimeOptions: Sendable {
    public let logLevel: LogLevel
    public let configPath: String?

    public init(logLevel: LogLevel = .quiet, configPath: String? = nil) {
        self.logLevel = logLevel
        self.configPath = configPath
    }

    public static let `default` = RuntimeOptions()
}

public struct Diagnostics: Sendable {
    public let level: LogLevel
    private let sink: @Sendable (String) -> Void

    public init(level: LogLevel, sink: @escaping @Sendable (String) -> Void = { _ in }) {
        self.level = level
        self.sink = sink
    }

    public func info(_ message: String) {
        guard level != .quiet else { return }
        sink(message)
    }

    public func verbose(_ message: String) {
        guard level == .verbose else { return }
        sink(message)
    }

    public static let silent = Diagnostics(level: .quiet)
}
