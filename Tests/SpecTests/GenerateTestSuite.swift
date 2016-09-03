//
//  SpecTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
import JSON
@testable import Mustache

extension Context {
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

func generateTestCase(name: String, description: String, contextJSON: String, template: String, expected: String) -> String {
    return [
        "    func test\(name)() throws {",
        "        let template = \"\(template)\"",
        "        let contextJSONString = \"\(contextJSON)\"",
        "        let contextJSON = try JSONParser().parse(data: contextJSONString.data)",
        "        let context = Context(from: contextJSON)",
        "",
        "        let ast = try compile(tokens: parse(reader: Reader(template)))",
        "        let rendered = render(ast: ast, context: context)",
        "",
        "        XCTAssertEqual(rendered, \"\(expected)\", \"\(description)\")",
        "    }",
    ].joined(separator: "\n")
}

func generateTestSuite(_ suite: String) throws -> String {

    guard let file = Bundle.allBundles
        .flatMap({ $0.url(forResource: suite, withExtension: "json") })
        .first else {
            fatalError()
    }
    let data = try Data(contentsOf: file)
    
    let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
    let overview = json["overview"]! as! String
    let tests = json["tests"]! as! [[String:Any]]

    let generated = tests.map { test in

        let name = (test["name"] as! String)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "")

        let description = (test["desc"] as! String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let contextJSON = try! String(data: JSONSerialization.data(withJSONObject: test["data"]!, options: []), encoding: String.Encoding.utf8)!
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        let template = (test["template"] as! String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        let expected = (test["expected"] as! String)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        return generateTestCase(name: name, description: description, contextJSON: contextJSON, template: template, expected: expected)
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

func generateTestSuites() throws -> [String] {
    return try ["Sections", "Interpolation", "Inverted", "Comments", "Partials"].map(generateTestSuite)
}

class GenerateTests: XCTestCase {
    func testGenerate() throws {
//        for suite in try generateTestSuites() {
//            for _ in 0..<25 {
//                print()
//            }
//            print(suite)
//            for _ in 0..<25 {
//                print()
//            }
//        }
    }
}
