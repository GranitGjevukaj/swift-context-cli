import Foundation
import SwiftParser
import SwiftSyntax

public enum FileAnalyzer {
    public static func analyze(fileAt path: String) throws -> FileAnalysis {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        return analyze(source: source, path: path)
    }

    public static func analyze(source: String, path: String = "<memory>") -> FileAnalysis {
        let syntax = Parser.parse(source: source)
        let visitor = AnalyzerVisitor(filePath: path)
        visitor.walk(syntax)

        return FileAnalysis(
            path: path,
            imports: Array(Set(visitor.imports)).sorted(),
            types: visitor.types
        )
    }
}

private final class AnalyzerVisitor: SyntaxVisitor {
    var imports: [String] = []
    var types: [TypeInfo] = []

    private let filePath: String

    init(filePath: String) {
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.append(node.path.trimmedDescription)
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            TypeInfo(
                name: node.name.text,
                kind: .class,
                accessLevel: accessLevel(from: node.modifiers),
                conformances: conformances(from: node.inheritanceClause),
                filePath: filePath
            )
        )
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            TypeInfo(
                name: node.name.text,
                kind: .struct,
                accessLevel: accessLevel(from: node.modifiers),
                conformances: conformances(from: node.inheritanceClause),
                filePath: filePath
            )
        )
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            TypeInfo(
                name: node.name.text,
                kind: .enum,
                accessLevel: accessLevel(from: node.modifiers),
                conformances: conformances(from: node.inheritanceClause),
                filePath: filePath
            )
        )
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            TypeInfo(
                name: node.name.text,
                kind: .protocol,
                accessLevel: accessLevel(from: node.modifiers),
                conformances: conformances(from: node.inheritanceClause),
                filePath: filePath
            )
        )
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            TypeInfo(
                name: node.name.text,
                kind: .actor,
                accessLevel: accessLevel(from: node.modifiers),
                conformances: conformances(from: node.inheritanceClause),
                filePath: filePath
            )
        )
        return .visitChildren
    }

    private func accessLevel(from modifiers: DeclModifierListSyntax) -> String? {
        for modifier in modifiers {
            let name = modifier.name.text
            if name == "public" || name == "internal" || name == "private" || name == "fileprivate" || name == "open" {
                return name
            }
        }
        return nil
    }

    private func conformances(from inheritanceClause: InheritanceClauseSyntax?) -> [String] {
        guard let inheritanceClause else { return [] }
        return inheritanceClause.inheritedTypes.map { inheritedType in
            inheritedType.type.trimmedDescription
        }
    }
}
