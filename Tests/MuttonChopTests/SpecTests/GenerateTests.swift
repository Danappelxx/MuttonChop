//
//  SpecTests.swift
//  SpecTests
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
import Zewo
@testable import MuttonChop
#if os(Linux)
    import Glibc
#endif
/*
extension Context {
    init(from json: String) throws {
        self = try Context.clean(JSON(from:json.buffer, deadline: .never))
    }

    static func clean(_ map: JSON) -> JSON {
        switch map {
        case .array(let array):
            return JSON(arrayLiteral: map)
        case .object(let dictionary):
            return JSON(dictionaryLiteral: map)
        case .double(let double) where floor(double) == double:
            return .int(Int(double))
        default:
            return map
        }
    }
}
 */

#if os(OSX)
    struct Test: Decodable {
    let name: String
    let description: String
    let partials: [String:String]?
    let contextJSON: String
    let template: String
    let expected: String
    
    enum Key : String, CodingKey {
        case name
        case description
        case partials
        case contextJSON
        case template
        case expected
    }
    
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let n  = try container.decode(String.self, forKey: .name)
        name = n.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "")
        let d = try container.decode(String.self, forKey: .description)
        description = d.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let p: [String:String]? = try container.decode([String:String]?.self, forKey: .partials)
        if let p = p {
            partials = [:]
            for (k,v) in p {
                partials![k] = v.replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\t", with: "\\t")
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\n", with: "\\n")
            }
        } else {
            partials = p
        }
        let c = try container.decode(String.self, forKey: .contextJSON)
        contextJSON = c.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let t = try container.decode(String.self, forKey: .template)
        template = t.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let e = try container.decode(String.self, forKey: .expected)
        expected = e.replacingOccurrences(of: "\\\"", with: "\"")
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

    struct TestOverview: Decodable {
        var overview: String
        var testJSON: [Test]
    }
    
    
    func generateTestSuite(_ suite: String) throws -> String {

        guard let file = Bundle.allBundles
            .flatMap({ $0.url(forResource: suite, withExtension: "map") })
            .first else {
                fatalError()
        }
        //let data = try Data(contentsOf: file)

        let str = try String(contentsOf: file)
        
        let map = try str.withBuffer { (b) -> JSON in
            return try JSON(from: b, deadline: .never)
        }
        
        let testOverview = try TestOverview(from: map)
        
        let overview = testOverview.overview

        let tests = testOverview.testJSON
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
