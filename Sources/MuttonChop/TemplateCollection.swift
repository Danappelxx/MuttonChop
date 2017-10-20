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
    public init(directory: String, fileExtensions: [String] = ["mustache"]) throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: directory)
            .map { NSString(string: $0) }

        var templates = [String: Template]()

        for file in files where fileExtensions.contains(file.pathExtension) {
            let path = NSString(string: directory).appendingPathComponent(String(describing: file))
            guard
                let handle = FileHandle(forReadingAtPath: path),
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
