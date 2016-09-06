//
//  PartialsTests.swift
//  Mustache
//
//  Created by Dan Appel on 9/2/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache
import JSON

/**
Partial tags are used to expand an external template into the current
template.

The tag's content MUST be a non-whitespace character sequence NOT containing
the current closing delimiter.

This tag's content names the partial to inject.  Set Delimiter tags MUST NOT
affect the parsing of a partial.  The partial MUST be rendered against the
context stack local to the tag.  If the named partial cannot be found, the
empty string SHOULD be used instead, as in interpolations.

Partial tags SHOULD be treated as standalone when appropriate.  If this tag
is used standalone, any whitespace preceding the tag should treated as
indentation, and prepended to each line of the partial before rendering.

 */
final class PartialsTests: XCTestCase {
    func testBasicBehavior() throws {
        let template = "\"{{>text}}\""
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "text": try compile(tokens: parse(reader: Reader("from partial")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"from partial\"", "The greater-than operator should expand to the named partial.")
    }

    func testFailedLookup() throws {
        let template = "\"{{>text}}\""
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "The empty string should be used when the named partial is not found.")
    }

    func testContext() throws {
        let template = "\"{{>partial}}\""
        let contextJSONString = "{\"text\":\"content\"}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader("*{{text}}*")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"*content*\"", "The greater-than operator should operate within the current context.")
    }

//    func testRecursion() throws {
//        let template = "{{>node}}"
//        let contextJSONString = "{\"content\":\"X\",\"nodes\":[{\"content\":\"Y\",\"nodes\":[]}]}"
//        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
//        let context = Context(from: contextJSON)
//
//        let partials = [
//            "node": "{{content}}<{{#nodes}}{{>node}}{{/nodes}}>"
//        ]
//
//        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
//        let rendered = render(ast: ast, context: context)
//
//        XCTAssertEqual(rendered, "X<Y<>>", "The greater-than operator should properly recurse.")
//    }

    func testSurroundingWhitespace() throws {
        let template = "| {{>partial}} |"
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader("\t|\t")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| \t|\t |", "The greater-than operator should not alter surrounding whitespace.")
    }

    func testInlineIndentation() throws {
        let template = "  {{data}}  {{> partial}}\n"
        let contextJSONString = "{\"data\":\"|\"}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader(">\n>")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  |  >\n>\n", "Whitespace should be left untouched.")
    }

    func testStandaloneLineEndings() throws {
        let template = "|\r\n{{>partial}}\r\n|"
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader(">")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|\r\n>|", "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let template = "  {{>partial}}\n>"
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader(">\n>")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  >\n  >>", "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let template = ">\n  {{>partial}}"
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader(">\n>")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, ">\n  >\n  >", "Standalone tags should not require a newline to follow them.")
    }

//    func testStandaloneIndentation() throws {
//        let template = "\\\n {{>partial}}\n/\n"
//        let contextJSONString = "{\"content\":\"<\n->\"}"
//        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
//        let context = Context(from: contextJSON)
//
//        let partials = [
//            "partial": try compile(tokens: parse(reader: Reader("|\n{{{content}}}\n|\n")))
//        ]
//
//        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
//        let rendered = render(ast: ast, context: context)
//
//        XCTAssertEqual(rendered, "\\\n |\n <\n->\n |\n/\n", "Each line of the partial should be indented before rendering.")
//    }

    func testPaddingWhitespace() throws {
        let template = "|{{> partial }}|"
        let contextJSONString = "{\"boolean\":true}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let partials = [
            "partial": try compile(tokens: parse(reader: Reader("[]")))
        ]

        let ast = try compile(tokens: parse(reader: Reader(template)), partials: partials)
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|[]|", "Superfluous in-tag whitespace should be ignored.")
    }
}
