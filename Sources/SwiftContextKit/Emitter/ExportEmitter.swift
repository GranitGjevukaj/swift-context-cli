import Foundation

public enum ExportFormat: String, Sendable {
    case agentsMD = "agents-md"
    case claudeMD = "claude-md"
    case cursorRules = "cursorrules"
}

public enum ExportEmitter {
    public static func emit(manifest: ContextManifest, format: ExportFormat) -> String {
        switch format {
        case .agentsMD:
            return MarkdownEmitter.emit(manifest: manifest)
        case .claudeMD:
            return emitClaudeMarkdown(manifest: manifest)
        case .cursorRules:
            return emitCursorRules(manifest: manifest)
        }
    }

    private static func emitClaudeMarkdown(manifest: ContextManifest) -> String {
        var lines: [String] = []
        lines.append("# CLAUDE.md")
        lines.append("")
        lines.append("## Project")
        lines.append("- Name: \(manifest.project.name)")
        lines.append("- Architecture signals: \(manifest.patterns.map { "\($0.module): \($0.pattern.rawValue)" }.joined(separator: "; "))")
        lines.append("- Modules: \(manifest.modules.map(\.name).joined(separator: ", "))")
        lines.append("")
        lines.append("## Coding Conventions")
        for convention in manifest.conventions {
            let naming = convention.naming
            var parts: [String] = []
            if let vm = naming.viewModelSuffix { parts.append("ViewModel suffix: \(vm)") }
            if let coord = naming.coordinatorSuffix { parts.append("Coordinator suffix: \(coord)") }
            if let test = naming.testSuffix { parts.append("Test suffix: \(test)") }
            if let mock = naming.mockPrefix { parts.append("Mock prefix: \(mock)") }
            lines.append("- [\(convention.module)] \(parts.isEmpty ? "No strong naming convention detected" : parts.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("## View Bindings")
        if manifest.viewBindings.isEmpty {
            lines.append("- None detected")
        } else {
            for binding in manifest.viewBindings {
                lines.append("- [\(binding.module)] \(binding.viewType) uses \(binding.viewModelType) via @\(binding.wrapper)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func emitCursorRules(manifest: ContextManifest) -> String {
        var lines: [String] = []
        lines.append("# .cursorrules")
        lines.append("")
        lines.append("- Follow existing architecture per module before adding new patterns.")

        for pattern in manifest.patterns where pattern.pattern != .unknown {
            lines.append("- In module \(pattern.module), prefer \(pattern.pattern.rawValue) structure.")
        }

        for convention in manifest.conventions {
            if let suffix = convention.naming.viewModelSuffix {
                lines.append("- In module \(convention.module), name view models with suffix '\(suffix)'.")
            }
            if let suffix = convention.naming.coordinatorSuffix {
                lines.append("- In module \(convention.module), name coordinators with suffix '\(suffix)'.")
            }
        }

        if !manifest.viewBindings.isEmpty {
            lines.append("- Keep View ↔ ViewModel bindings aligned with detected wrappers (@StateObject/@ObservedObject/@EnvironmentObject).")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
