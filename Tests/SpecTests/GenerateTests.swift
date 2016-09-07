//
//  SpecTests.swift
//  SpecTests
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
import JSON
@testable import MuttonChop

extension Context {
    init(from json: String) throws {
        try self.init(from: JSONParser().parse(data: json.data))
    }

    init(from json: JSON) {
        switch json {
        case let .array(array):
            self = .array(array.map(Context.init(from:)))
        case let .object(dictionary):
            self = .dictionary(dictionary.reduce([String:Context](), { dict, pair in
                var dict = dict
                dict[pair.key] = Context(from: pair.value)
                return dict
            }))
        case let .number(number):
            switch number {
            case let .double(double) where floor(double) == double:
                self = .int(Int(double))
            case let .double(double):
                self = .double(double)
            case let .integer(int):
                self = .int(int)
            case let .unsignedInteger(int):
                self = .int(Int(int))
            }
        case let .boolean(boolean):
            self = .bool(boolean)
        case let .string(string):
            self = .string(string)
        case .null:
            fatalError("null is not supported")
        }
    }
}

class GenerateTests: XCTestCase {
    let enabled = false
    let suites = ["Sections", "Interpolation", "Inverted", "Comments", "Partials", "Delimiters"]

    func testGenerate() throws {
        guard enabled else { return }

        for suite in suites {
            let suite = try generateTestSuite(suite)
            print()
            print(suite)
            print()
        }
    }

    func generateTestSuite(_ suite: String) throws -> String {

        guard let file = Bundle.allBundles
            .flatMap({ $0.url(forResource: suite, withExtension: "json") })
            .first else {
                fatalError()
        }
        let data = try Data(contentsOf: file)

        let json = try JSONParser().parse(data: C7.Data(Array(data)))
        let overview = try json.get("overview") as String
        let tests = try json.get("tests") as [JSON]

        let generated = try tests.map { test in

            let name = try (test.get("name") as String)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: "(", with: "_")
                .replacingOccurrences(of: ")", with: "")

            let description = try (test.get("desc") as String)
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")

            let partials = try test["partials"]?.asDictionary()
                .mapValues { try $0.asString() }
                .mapValues { $0
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\t", with: "\\t")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\n", with: "\\n") }

            let contextJSON = try JSONSerializer().serializeToString(json: .object(test.get("data")))
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n")

            let template = try (test.get("template") as String)
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n")

            let expected = try (test.get("expected") as String)
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n")

            return generateTestCase(name: name, description: description, contextJSON: contextJSON, template: template, expected: expected, partials: partials)
        } as [String]

        return [
            "/**",
            "\(overview)",
            " */",
            "final class \(suite)Tests: XCTestCase {",
            generated.joined(separator: "\n\n"),
            "}",
        ].joined(separator: "\n")
    }

    func generateTestCase(name: String, description: String, contextJSON: String, template: String, expected: String, partials: [String:String]? = nil) -> String {
        return [
            "    func test\(name)() throws {",
            "        let templateString = \"\(template)\"",
            "        let contextJSON = \"\(contextJSON)\"",
            "        let expected = \"\(expected)\"",
            (partials?.isEmpty ?? true
                ? ""
                : "        let partials = try [\n" + partials!.map { key, value in
                    "            \"\(key)\": Template(\"\(value)\")"
                    }.joined(separator: ",\n") + "\n        ]\n"
            ),
            "        let context = try Context(from: contextJSON)",
            (partials?.isEmpty ?? true
                ? "        let template = try Template(templateString)"
                : "        let template = try Template(templateString, partials: partials)"
            ),
            "        let rendered = template.render(with: context)",
            "",
            "        XCTAssertEqual(rendered, expected, \"\(description)\")",
            "    }",
        ].joined(separator: "\n")
    }
}
