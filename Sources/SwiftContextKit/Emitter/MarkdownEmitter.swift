import Foundation

public enum MarkdownEmitter {
    public static func emit(manifest: ContextManifest) -> String {
        var lines: [String] = []
        lines.append("# Project Context: \(manifest.project.name)")
        lines.append("")
        lines.append("## Overview")
        lines.append("- Kind: \(manifest.project.kind)")
        lines.append("- Root: \(manifest.project.rootPath)")
        lines.append("- Generated: \(manifest.project.generatedAt)")

        if let minimum = manifest.project.minimumDeploymentTarget {
            lines.append("- Minimum Deployment Target: \(minimum)")
        }

        lines.append("- Modules: \(manifest.modules.count)")
        lines.append("")
        lines.append("## Module Structure")

        if manifest.modules.isEmpty {
            lines.append("No modules detected.")
        } else {
            for module in manifest.modules {
                lines.append("### \(module.name)")
                lines.append("- Source files: \(module.sourceFileCount)")
                if module.imports.isEmpty {
                    lines.append("- Imports: none")
                } else {
                    lines.append("- Imports: \(module.imports.joined(separator: ", "))")
                }

                if module.types.isEmpty {
                    lines.append("- Types: none")
                } else {
                    lines.append("- Types:")
                    for type in module.types.sorted(by: { $0.name < $1.name }) {
                        let conformanceSuffix = type.conformances.isEmpty
                            ? ""
                            : " : \(type.conformances.joined(separator: ", "))"
                        lines.append("  - \(type.kind.rawValue) \(type.name)\(conformanceSuffix)")
                    }
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
