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
    private static let trackedWrappers = Set([
        "Published",
        "State",
        "StateObject",
        "ObservedObject",
        "EnvironmentObject",
        "Binding",
        "Environment",
    ])

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
            makeTypeInfo(
                name: node.name.text,
                kind: .class,
                modifiers: node.modifiers,
                inheritanceClause: node.inheritanceClause,
                memberBlock: node.memberBlock
            )
        )
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            makeTypeInfo(
                name: node.name.text,
                kind: .struct,
                modifiers: node.modifiers,
                inheritanceClause: node.inheritanceClause,
                memberBlock: node.memberBlock
            )
        )
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            makeTypeInfo(
                name: node.name.text,
                kind: .enum,
                modifiers: node.modifiers,
                inheritanceClause: node.inheritanceClause,
                memberBlock: node.memberBlock
            )
        )
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            makeTypeInfo(
                name: node.name.text,
                kind: .protocol,
                modifiers: node.modifiers,
                inheritanceClause: node.inheritanceClause,
                memberBlock: node.memberBlock
            )
        )
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        types.append(
            makeTypeInfo(
                name: node.name.text,
                kind: .actor,
                modifiers: node.modifiers,
                inheritanceClause: node.inheritanceClause,
                memberBlock: node.memberBlock
            )
        )
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let typeName = extensionTypeName(from: node.extendedType.trimmedDescription)
        guard let index = types.firstIndex(where: { $0.name == typeName }) else {
            return .skipChildren
        }

        let existing = types[index]
        let additionalConformances = conformances(from: node.inheritanceClause)
        let extensionProperties = properties(from: node.memberBlock)
        let extensionMethods = methods(from: node.memberBlock)
        let extensionSignals = navigationSignals(from: node.memberBlock)

        var mergedConformances = existing.conformances
        for conformance in additionalConformances where !mergedConformances.contains(conformance) {
            mergedConformances.append(conformance)
        }

        var mergedProperties = existing.properties
        for property in extensionProperties where !contains(property: property, in: mergedProperties) {
            mergedProperties.append(property)
        }

        var mergedMethods = existing.methods
        for method in extensionMethods where !contains(method: method, in: mergedMethods) {
            mergedMethods.append(method)
        }

        var mergedSignals = existing.navigationSignals
        for signal in extensionSignals where !mergedSignals.contains(signal) {
            mergedSignals.append(signal)
        }

        types[index] = TypeInfo(
            name: existing.name,
            kind: existing.kind,
            accessLevel: existing.accessLevel,
            conformances: mergedConformances,
            properties: mergedProperties,
            methods: mergedMethods,
            navigationSignals: mergedSignals,
            filePath: existing.filePath
        )
        return .skipChildren
    }

    private func makeTypeInfo(
        name: String,
        kind: TypeKind,
        modifiers: DeclModifierListSyntax,
        inheritanceClause: InheritanceClauseSyntax?,
        memberBlock: MemberBlockSyntax
    ) -> TypeInfo {
        TypeInfo(
            name: name,
            kind: kind,
            accessLevel: accessLevel(from: modifiers),
            conformances: conformances(from: inheritanceClause),
            properties: properties(from: memberBlock),
            methods: methods(from: memberBlock),
            navigationSignals: navigationSignals(from: memberBlock),
            filePath: filePath
        )
    }

    private func properties(from memberBlock: MemberBlockSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in memberBlock.members {
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            let wrappers = propertyWrappers(from: variableDecl.attributes)
            let access = accessLevel(from: variableDecl.modifiers)

            for binding in variableDecl.bindings {
                guard let name = propertyName(from: binding.pattern) else {
                    continue
                }

                let declaredType = binding.typeAnnotation?.type.trimmedDescription
                let inferredType = inferredTypeName(fromInitializer: binding.initializer?.value)
                let typeName = normalizeTypeName(declaredType ?? inferredType)

                properties.append(
                    PropertyInfo(
                        name: name,
                        typeName: typeName,
                        accessLevel: access,
                        wrappers: wrappers
                    )
                )
            }
        }

        return properties
    }

    private func methods(from memberBlock: MemberBlockSyntax) -> [MethodInfo] {
        var methods: [MethodInfo] = []

        for member in memberBlock.members {
            guard let functionDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }

            let parameters = functionDecl.signature.parameterClause.parameters.map { parameter in
                let firstName = parameter.firstName.text
                let secondName = parameter.secondName?.text
                let externalName = firstName == "_" ? nil : firstName
                let localName = secondName ?? firstName
                return MethodParameterInfo(
                    externalName: externalName,
                    localName: localName,
                    typeName: parameter.type.trimmedDescription
                )
            }

            let effectSpecifiers = functionDecl.signature.effectSpecifiers
            let method = MethodInfo(
                name: functionDecl.name.text,
                parameters: parameters,
                returnType: functionDecl.signature.returnClause?.type.trimmedDescription,
                isAsync: effectSpecifiers?.asyncSpecifier != nil,
                isThrowing: effectSpecifiers?.throwsClause != nil,
                accessLevel: accessLevel(from: functionDecl.modifiers)
            )
            methods.append(method)
        }

        return methods
    }

    private func propertyWrappers(from attributes: AttributeListSyntax) -> [String] {
        var wrappers: [String] = []
        for attributeElement in attributes {
            guard let attribute = attributeElement.as(AttributeSyntax.self) else {
                continue
            }

            let rawName = attribute.attributeName.trimmedDescription
            let wrapperName = rawName.split(separator: ".").last.map(String.init) ?? rawName
            guard Self.trackedWrappers.contains(wrapperName) else {
                continue
            }
            wrappers.append(wrapperName)
        }
        return wrappers
    }

    private func propertyName(from pattern: PatternSyntax) -> String? {
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            return identifier.identifier.text
        }

        if let valueBinding = pattern.as(ValueBindingPatternSyntax.self),
           let identifier = valueBinding.pattern.as(IdentifierPatternSyntax.self) {
            return identifier.identifier.text
        }

        let raw = pattern.trimmedDescription
        guard !raw.isEmpty else { return nil }
        return raw
    }

    private func inferredTypeName(fromInitializer expression: ExprSyntax?) -> String? {
        guard let expression else { return nil }
        var value = expression.trimmedDescription

        while value.hasPrefix("try ") || value.hasPrefix("await ") {
            if value.hasPrefix("try ") {
                value = String(value.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if value.hasPrefix("await ") {
                value = String(value.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let openParen = value.firstIndex(of: "(") {
            value = String(value[..<openParen])
        }

        if value.hasPrefix(".") {
            return nil
        }

        return normalizeTypeName(value)
    }

    private func normalizeTypeName(_ value: String?) -> String? {
        guard var value else { return nil }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        while value.hasSuffix("?") || value.hasSuffix("!") {
            value.removeLast()
        }

        if value.hasPrefix("some ") {
            value = String(value.dropFirst(5))
        }
        if value.hasPrefix("any ") {
            value = String(value.dropFirst(4))
        }

        if let genericStart = value.firstIndex(of: "<") {
            value = String(value[..<genericStart])
        }

        if let last = value.split(separator: ".").last {
            value = String(last)
        }

        return value.isEmpty ? nil : value
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

    private func extensionTypeName(from description: String) -> String {
        let noGeneric = description.split(separator: "<", maxSplits: 1).first.map(String.init) ?? description
        let stripped = noGeneric.trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.split(separator: ".").last.map(String.init) ?? stripped
    }

    private func navigationSignals(from memberBlock: MemberBlockSyntax) -> [String] {
        let text = memberBlock.trimmedDescription
        var signals: [String] = []
        if text.contains("NavigationStack") { signals.append("NavigationStack") }
        if text.contains("NavigationPath") { signals.append("NavigationPath") }
        if text.contains(".sheet(") || text.contains(".sheet ") { signals.append("sheet") }
        if text.contains("fullScreenCover") { signals.append("fullScreenCover") }
        return signals
    }

    private func contains(property: PropertyInfo, in properties: [PropertyInfo]) -> Bool {
        properties.contains {
            $0.name == property.name &&
                $0.typeName == property.typeName &&
                $0.wrappers == property.wrappers
        }
    }

    private func contains(method: MethodInfo, in methods: [MethodInfo]) -> Bool {
        methods.contains {
            $0.name == method.name &&
                $0.parameters.map(\.typeName) == method.parameters.map(\.typeName)
        }
    }
}
