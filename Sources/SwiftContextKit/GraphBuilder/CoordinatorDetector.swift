import Foundation

public enum CoordinatorDetector {
    public static func detect(in modules: [ModuleInfo]) -> [CoordinatorInfo] {
        var detected: [CoordinatorInfo] = []

        for module in modules {
            let moduleTypeNames = Set(module.types.map(\.name))

            for type in module.types {
                guard isCoordinator(type) else { continue }

                let children = childCoordinators(for: type, availableTypeNames: moduleTypeNames)
                let heuristics = heuristics(for: type)

                detected.append(
                    CoordinatorInfo(
                        module: module.name,
                        name: type.name,
                        heuristics: heuristics,
                        childCoordinators: children.sorted()
                    )
                )
            }
        }

        return detected.sorted {
            if $0.module != $1.module { return $0.module < $1.module }
            return $0.name < $1.name
        }
    }

    private static func isCoordinator(_ type: TypeInfo) -> Bool {
        if type.name.hasSuffix("Coordinator") { return true }
        if type.conformances.contains("Coordinator") { return true }

        let navigationMethodNames = Set(["start", "show", "route", "navigate", "present", "push", "pop"])
        if type.methods.contains(where: { navigationMethodNames.contains($0.name.lowercased()) }) {
            return true
        }

        if type.properties.contains(where: { ($0.typeName ?? "").contains("Coordinator") }) {
            return true
        }

        return false
    }

    private static func heuristics(for type: TypeInfo) -> [String] {
        var reasons: [String] = []
        if type.name.hasSuffix("Coordinator") {
            reasons.append("name-suffix")
        }
        if type.conformances.contains("Coordinator") {
            reasons.append("coordinator-conformance")
        }
        if type.properties.contains(where: { ($0.typeName ?? "").contains("Coordinator") }) {
            reasons.append("coordinator-properties")
        }
        return reasons
    }

    private static func childCoordinators(for type: TypeInfo, availableTypeNames: Set<String>) -> [String] {
        var children: Set<String> = []
        for property in type.properties {
            guard let rawType = property.typeName else { continue }
            for candidate in coordinatorCandidates(from: rawType) {
                guard candidate != type.name else { continue }
                if candidate.hasSuffix("Coordinator") || availableTypeNames.contains(candidate) {
                    children.insert(candidate)
                }
            }
        }
        return children.sorted()
    }

    private static func coordinatorCandidates(from rawType: String) -> [String] {
        var text = rawType
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "any ", with: "")
            .replacingOccurrences(of: "some ", with: "")

        if let genericStart = text.firstIndex(of: "<") {
            text = String(text[..<genericStart])
        }

        let tokens = text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "_" })
            .map(String.init)

        return tokens
            .map { token in token.split(separator: ".").last.map(String.init) ?? token }
            .filter { !$0.isEmpty }
    }
}
