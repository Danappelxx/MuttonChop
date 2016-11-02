public enum TemplateCollectionError: Error {
    case noSuchTemplate(named: String)
}

public struct TemplateCollection {
    public var templates: [String: Template]

    public init(templates: [String: Template] = [:]) {
        self.templates = templates
    }

    public func get(template name: String) throws -> Template {
        guard let template = templates[name] else {
            throw TemplateCollectionError.noSuchTemplate(named: name)
        }
        return template
    }

    public func render(template name: String, with context: Context = .array([])) throws -> String {
        return try get(template: name).render(with: context, partials: self.templates)
    }
}

// MARK: IO
import Foundation
extension TemplateCollection {
    public init(basePath: String = FileManager.default.currentDirectoryPath, directory: String, fileExtensions: [String] = ["mustache"]) throws {
        let path = basePath + directory
        let files = try FileManager.default.contentsOfDirectory(atPath: path)
            .map { NSString(string: $0) }

        var templates = [String: Template]()

        for file in files where fileExtensions.contains(file.pathExtension) {

            guard
                let handle = FileHandle(forReadingAtPath: "\(path)/\(file)"),
                let contents = String(data: handle.readDataToEndOfFile(), encoding: .utf8)
                else {
                continue
            }

            let template = try Template(contents)
            templates[file.deletingPathExtension] = template
        }

        self.templates = templates
    }
}
