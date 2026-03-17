import Foundation

public enum XcodeProjectParser {
    public static func parse(projectFile: URL) -> ProjectModel {
        let root = projectFile.deletingLastPathComponent()
        let projectName = projectFile.deletingPathExtension().lastPathComponent
        let swiftFiles = collectSwiftFiles(in: root)

        return ProjectModel(
            name: projectName,
            kind: .xcodeproj,
            rootPath: root.path,
            minimumDeploymentTarget: nil,
            targets: [ProjectTarget(name: projectName, sourceFiles: swiftFiles)]
        )
    }

    private static func collectSwiftFiles(in root: URL) -> [String] {
        let excluded = Set([".git", ".build", "Pods", "Carthage", "DerivedData"])
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: [String] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if excluded.contains(fileURL.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            guard fileURL.pathExtension == "swift" else { continue }
            files.append(fileURL.path)
        }
        return files.sorted()
    }
}
