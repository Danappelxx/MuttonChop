//
//  SpecTests.swift
//  SpecTests
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
import Axis
@testable import MuttonChop
#if os(Linux)
    import Glibc
#endif

extension Context {
    init(from json: String) throws {
        self = try Context.clean(JSONMapParser.parse(json.buffer))
    }

    static func clean(_ map: Map) -> Map {
        switch map {
        case .array(let array):
            return Map(array.map(Context.clean))
        case .dictionary(let dictionary):
            return Map(dictionary.mapValues(Context.clean))
        case .double(let double) where floor(double) == double:
            return .int(Int(double))
        default:
            return map
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

    init(map: Map) throws {
        name = try (map.get("name") as String)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "")


        description = try (map.get("desc") as String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")

        partials = try map["partials"].asDictionary()
            .mapValues { try $0.asString() }
            .mapValues { $0
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n") }

        contextJSON = try String(buffer: JSONMapSerializer.serialize(.dictionary(map["data"].asDictionary())))
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        template = try (map.get("template") as String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        expected = try (map.get("expected") as String)
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
            .flatMap({ $0.url(forResource: suite, withExtension: "map") })
            .first else {
                fatalError()
        }
        let data = try Data(contentsOf: file)

        let map = try JSONMapParser().parse(Buffer(Array(data)))!
        let overview = (try? map["overview"].asString()) ?? ""
        let testsJSON = try map.get("tests") as [Map]

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
