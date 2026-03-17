import Foundation

public enum FileAnalyzer {
    private static let importRegex = try! NSRegularExpression(
        pattern: #"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_\.]*)"#
    )

    private static let typeRegex = try! NSRegularExpression(
        pattern: #"(?m)^\s*(?:(public|internal|private|fileprivate|open)\s+)?(?:final\s+)?(class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*([^\{]+))?"#
    )

    public static func analyze(fileAt path: String) throws -> FileAnalysis {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        return analyze(source: source, path: path)
    }

    public static func analyze(source: String, path: String = "<memory>") -> FileAnalysis {
        let nsrange = NSRange(source.startIndex..<source.endIndex, in: source)

        let importMatches: [NSTextCheckingResult] = importRegex.matches(in: source, range: nsrange)
        var imports: [String] = []
        imports.reserveCapacity(importMatches.count)
        for match in importMatches {
            guard let range = Range(match.range(at: 1), in: source) else { continue }
            imports.append(String(source[range]))
        }

        let typeMatches: [NSTextCheckingResult] = typeRegex.matches(in: source, range: nsrange)
        var types: [TypeInfo] = []
        types.reserveCapacity(typeMatches.count)
        for match in typeMatches {
            guard
                let kindRange = Range(match.range(at: 2), in: source),
                let nameRange = Range(match.range(at: 3), in: source)
            else {
                continue
            }

            let accessLevel: String?
            if let accessRange = Range(match.range(at: 1), in: source) {
                accessLevel = String(source[accessRange])
            } else {
                accessLevel = nil
            }

            guard let kind = TypeKind(rawValue: String(source[kindRange])) else {
                continue
            }

            let conformances: [String]
            if let inheritanceRange = Range(match.range(at: 4), in: source) {
                conformances = String(source[inheritanceRange])
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            } else {
                conformances = []
            }

            types.append(TypeInfo(
                name: String(source[nameRange]),
                kind: kind,
                accessLevel: accessLevel,
                conformances: conformances,
                filePath: path
            ))
        }

        return FileAnalysis(
            path: path,
            imports: Array(Set(imports)).sorted(),
            types: types
        )
    }
}
