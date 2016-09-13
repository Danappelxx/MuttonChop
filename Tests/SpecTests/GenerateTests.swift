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
#if os(Linux)
    import Glibc
#endif

extension Context {
    init(from json: String) throws {
        try self.init(from: JSONParser().parse(data: json.data))
    }
    init(from json: JSON) {
        switch json {
        case let .array(array):
            self = .array(array.map(Context.init(from:)))
        case let .object(object):
            self = .dictionary(object.mapValues(Context.init(from:)))
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
        case let .boolean(bool):
            self = .bool(bool)
        case let .string(string):
            self = .string(string)
        case .null:
            fatalError("null is not supported")
        }
    }
}

#if os(OSX)
struct Test {
    let name: String
    let description: String
    let partials: [String:String]?
    let contextJSON: String
    let template: String
    let expected: String

    init(json: JSON) throws {
        name = try (json.get("name") as String)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "")


        description = try (json.get("desc") as String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")

        partials = try json["partials"]?.asDictionary()
            .mapValues { try $0.asString() }
            .mapValues { $0
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n") }

        contextJSON = try JSONSerializer().serializeToString(json: .object(json.get("data")))
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        template = try (json.get("template") as String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        expected = try (json.get("expected") as String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

class GenerateTests: XCTestCase {
    let enabled = false
    let suites = ["Sections", "Interpolation", "Inverted", "Comments", "Partials", "Delimiters", "Inheritance"]

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
        let overview = try json["overview"]?.asString() ?? ""
        let testsJSON = try json.get("tests") as [JSON]

        let tests = try testsJSON.map(Test.init)
        let testCases = tests.map(generateTestCase)

        let allTests = [
            "    static var allTests: [(String, (\(suite)Tests) -> () throws -> Void)] {",
            "        return [",
            (tests.map { test in
            "            (\"test\(test.name)\", test\(test.name)),"
            }.joined(separator: "\n")),
            "        ]",
            "    }"
        ].joined(separator: "\n")

        return [
            "/**",
            "\(overview)",
            " */",
            "final class \(suite)Tests: XCTestCase {",
            allTests,
            "",
            testCases.joined(separator: "\n\n"),
            "}",
        ].joined(separator: "\n")
    }

    func generateTestCase(test: Test) -> String {
        return [
            "    func test\(test.name)() throws {",
            "        let templateString = \"\(test.template)\"",
            "        let contextJSON = \"\(test.contextJSON)\"",
            "        let expected = \"\(test.expected)\"",
            (test.partials?.isEmpty ?? true
                ? ""
                : "        let partials = try [\n" + test.partials!.map { key, value in
                  "            \"\(key)\": Template(\"\(value)\")"
                    }.joined(separator: ",\n") + "\n        ]\n"
            ),
            "        let context = try Context(from: contextJSON)",
            "        let template = try Template(templateString)",
            (test.partials?.isEmpty ?? true
                ? "        let rendered = template.render(with: context)"
                : "        let rendered = template.render(with: context, partials: partials)"),
            "",
            "        XCTAssertEqual(rendered, expected, \"\(test.description)\")",
            "    }",
        ].joined(separator: "\n")
    }
}
#endif
