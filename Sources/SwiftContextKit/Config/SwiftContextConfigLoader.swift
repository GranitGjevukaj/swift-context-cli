import Foundation

public enum SwiftContextConfigLoader {
    public static func load(projectRoot: String, explicitPath: String?) throws -> ResolvedConfig {
        if let explicitPath {
            let url = URL(fileURLWithPath: explicitPath).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SwiftContextError.configNotFound(path: url.path)
            }
            return try ResolvedConfig(path: url.path, config: parseConfig(at: url))
        }

        let defaultURL = URL(fileURLWithPath: projectRoot)
            .standardizedFileURL
            .appendingPathComponent(".swiftcontext.yml")

        guard FileManager.default.fileExists(atPath: defaultURL.path) else {
            return ResolvedConfig(path: nil, config: .default)
        }

        return try ResolvedConfig(path: defaultURL.path, config: parseConfig(at: defaultURL))
    }

    private static func parseConfig(at url: URL) throws -> SwiftContextConfig {
        let raw: String
        do {
            raw = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw SwiftContextError.fileReadFailed(path: url.path, underlying: error)
        }

        var conventions = NamingConventionOverrides.empty
        var moduleOverrides: [String: NamingConventionOverrides] = [:]
        var analysis = AnalysisConfig.default

        enum Section {
            case none
            case conventions
            case moduleOverrides
            case analysis
        }

        var section: Section = .none
        var currentModule: String?

        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            let withoutComment = stripComment(from: rawLine)
            if withoutComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let indent = withoutComment.prefix(while: { $0 == " " }).count
            let trimmed = withoutComment.trimmingCharacters(in: .whitespaces)

            guard indent % 2 == 0 else {
                throw SwiftContextError.invalidConfig(
                    path: url.path,
                    line: lineNumber,
                    reason: "Indentation must use multiples of 2 spaces."
                )
            }

            if indent == 0 {
                currentModule = nil
                guard trimmed.hasSuffix(":") else {
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Top-level keys must be section headers ending with ':'."
                    )
                }

                let topLevelKey = String(trimmed.dropLast())
                switch topLevelKey {
                case "conventions":
                    section = .conventions
                case "moduleOverrides", "overrides":
                    section = .moduleOverrides
                case "analysis":
                    section = .analysis
                default:
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Unknown top-level key '\(topLevelKey)'. Supported: conventions, moduleOverrides, analysis."
                    )
                }
                continue
            }

            switch section {
            case .none:
                throw SwiftContextError.invalidConfig(
                    path: url.path,
                    line: lineNumber,
                    reason: "Nested content must be inside a known section."
                )

            case .conventions:
                guard indent == 2 else {
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Conventions entries must be indented by 2 spaces."
                    )
                }
                let (key, value) = try parseKeyValue(trimmed, path: url.path, line: lineNumber)
                try assignNamingValue(
                    key: key,
                    value: value,
                    destination: &conventions,
                    path: url.path,
                    line: lineNumber
                )

            case .analysis:
                guard indent == 2 else {
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Analysis entries must be indented by 2 spaces."
                    )
                }
                let (key, value) = try parseKeyValue(trimmed, path: url.path, line: lineNumber)
                switch key {
                case "parallelism":
                    analysis = AnalysisConfig(parallelism: try parseParallelism(value, path: url.path, line: lineNumber))
                default:
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Unknown analysis key '\(key)'. Supported: parallelism."
                    )
                }

            case .moduleOverrides:
                if indent == 2 {
                    guard trimmed.hasSuffix(":") else {
                        throw SwiftContextError.invalidConfig(
                            path: url.path,
                            line: lineNumber,
                            reason: "Module override headers must end with ':'."
                        )
                    }

                    let moduleName = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                    guard !moduleName.isEmpty else {
                        throw SwiftContextError.invalidConfig(
                            path: url.path,
                            line: lineNumber,
                            reason: "Module override name cannot be empty."
                        )
                    }
                    currentModule = moduleName
                    if moduleOverrides[moduleName] == nil {
                        moduleOverrides[moduleName] = .empty
                    }
                    continue
                }

                guard indent == 4 else {
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Module override values must be indented by 4 spaces."
                    )
                }
                guard let currentModule else {
                    throw SwiftContextError.invalidConfig(
                        path: url.path,
                        line: lineNumber,
                        reason: "Module override entry found before module name."
                    )
                }

                let (key, value) = try parseKeyValue(trimmed, path: url.path, line: lineNumber)
                var override = moduleOverrides[currentModule] ?? .empty
                try assignNamingValue(
                    key: key,
                    value: value,
                    destination: &override,
                    path: url.path,
                    line: lineNumber
                )
                moduleOverrides[currentModule] = override
            }
        }

        return SwiftContextConfig(
            conventions: conventions,
            moduleOverrides: moduleOverrides,
            analysis: analysis
        )
    }

    private static func parseKeyValue(_ line: String, path: String, line number: Int) throws -> (String, String?) {
        guard let separator = line.firstIndex(of: ":") else {
            throw SwiftContextError.invalidConfig(
                path: path,
                line: number,
                reason: "Expected key/value format 'key: value'."
            )
        }

        let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

        guard !key.isEmpty else {
            throw SwiftContextError.invalidConfig(
                path: path,
                line: number,
                reason: "Configuration key cannot be empty."
            )
        }

        if rawValue.isEmpty {
            return (key, nil)
        }

        return (key, decodeScalar(rawValue))
    }

    private static func parseParallelism(_ rawValue: String?, path: String, line: Int) throws -> Int? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        let value = rawValue.lowercased()
        if value == "auto" {
            return nil
        }

        guard let integer = Int(value), integer > 0 else {
            throw SwiftContextError.invalidConfig(
                path: path,
                line: line,
                reason: "'analysis.parallelism' must be a positive integer or 'auto'."
            )
        }
        return integer
    }

    private static func assignNamingValue(
        key: String,
        value: String?,
        destination: inout NamingConventionOverrides,
        path: String,
        line: Int
    ) throws {
        switch key {
        case "viewModelSuffix":
            destination = NamingConventionOverrides(
                viewModelSuffix: value,
                coordinatorSuffix: destination.coordinatorSuffix,
                testSuffix: destination.testSuffix,
                mockPrefix: destination.mockPrefix
            )
        case "coordinatorSuffix":
            destination = NamingConventionOverrides(
                viewModelSuffix: destination.viewModelSuffix,
                coordinatorSuffix: value,
                testSuffix: destination.testSuffix,
                mockPrefix: destination.mockPrefix
            )
        case "testSuffix":
            destination = NamingConventionOverrides(
                viewModelSuffix: destination.viewModelSuffix,
                coordinatorSuffix: destination.coordinatorSuffix,
                testSuffix: value,
                mockPrefix: destination.mockPrefix
            )
        case "mockPrefix":
            destination = NamingConventionOverrides(
                viewModelSuffix: destination.viewModelSuffix,
                coordinatorSuffix: destination.coordinatorSuffix,
                testSuffix: destination.testSuffix,
                mockPrefix: value
            )
        default:
            throw SwiftContextError.invalidConfig(
                path: path,
                line: line,
                reason: "Unknown naming key '\(key)'. Supported: viewModelSuffix, coordinatorSuffix, testSuffix, mockPrefix."
            )
        }
    }

    private static func decodeScalar(_ raw: String) -> String? {
        let lowered = raw.lowercased()
        if lowered == "null" || lowered == "nil" || lowered == "~" {
            return nil
        }

        if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
            return String(raw.dropFirst().dropLast())
        }
        if raw.hasPrefix("'") && raw.hasSuffix("'") && raw.count >= 2 {
            return String(raw.dropFirst().dropLast())
        }
        return raw
    }

    private static func stripComment(from line: String) -> String {
        guard let hash = line.firstIndex(of: "#") else {
            return line
        }
        return String(line[..<hash])
    }
}
