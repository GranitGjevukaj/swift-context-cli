import Foundation

public enum ProjectLocator {
    public static func resolve(from inputPath: String?) throws -> ProjectModel {
        let root = URL(fileURLWithPath: inputPath ?? FileManager.default.currentDirectoryPath)
            .standardizedFileURL

        if let xcodeproj = try firstFile(endingWith: ".xcodeproj", in: root) {
            return try XcodeProjectParser.parse(projectFile: xcodeproj)
        }

        let packageSwift = root.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            return try SPMManifestParser.parse(projectRoot: root)
        }

        throw SwiftContextError.projectNotFound(path: root.path)
    }

    private static func firstFile(endingWith suffix: String, in directory: URL) throws -> URL? {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw SwiftContextError.directoryListingFailed(path: directory.path, underlying: error)
        }
        return contents.first(where: { $0.lastPathComponent.hasSuffix(suffix) })
    }
}
