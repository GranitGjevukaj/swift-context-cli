import Foundation

public enum SPMManifestParser {
    public static func parse(projectRoot: URL) throws -> ProjectModel {
        // TODO(v0.2): Parse Package.swift target declarations directly to support
        // custom target paths and platform/deployment settings.
        // Current implementation follows conventional Sources/ and Tests/ layout.
        let sourcesURL = projectRoot.appendingPathComponent("Sources")
        let testsURL = projectRoot.appendingPathComponent("Tests")

        var targets: [ProjectTarget] = []

        if FileManager.default.fileExists(atPath: sourcesURL.path) {
            let moduleNames: [String]
            do {
                moduleNames = try FileManager.default.contentsOfDirectory(atPath: sourcesURL.path)
            } catch {
                throw SwiftContextError.directoryListingFailed(path: sourcesURL.path, underlying: error)
            }

            for moduleName in moduleNames.sorted() {
                let moduleURL = sourcesURL.appendingPathComponent(moduleName)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: moduleURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                let swiftFiles = collectSwiftFiles(in: moduleURL)
                targets.append(ProjectTarget(name: moduleName, sourceFiles: swiftFiles))
            }
        }

        if FileManager.default.fileExists(atPath: testsURL.path) {
            let testNames: [String]
            do {
                testNames = try FileManager.default.contentsOfDirectory(atPath: testsURL.path)
            } catch {
                throw SwiftContextError.directoryListingFailed(path: testsURL.path, underlying: error)
            }

            for testName in testNames.sorted() {
                let testURL = testsURL.appendingPathComponent(testName)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: testURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                let swiftFiles = collectSwiftFiles(in: testURL)
                targets.append(ProjectTarget(name: testName, sourceFiles: swiftFiles))
            }
        }

        return ProjectModel(
            name: projectRoot.lastPathComponent,
            kind: .spm,
            rootPath: projectRoot.path,
            minimumDeploymentTarget: nil,
            targets: targets
        )
    }

    private static func collectSwiftFiles(in root: URL) -> [String] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var files: [String] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            files.append(fileURL.path)
        }
        return files.sorted()
    }
}
