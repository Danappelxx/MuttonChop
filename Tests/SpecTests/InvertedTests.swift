//
//  InvertedTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/31/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache
import JSON

/**
Inverted Section tags and End Section tags are used in combination to wrap a
section of the template.

These tags' content MUST be a non-whitespace character sequence NOT
containing the current closing delimiter; each Inverted Section tag MUST be
followed by an End Section tag with the same content within the same
section.

This tag's content names the data to replace the tag.  Name resolution is as
follows:
  1) Split the name on periods; the first part is the name to resolve, any
  remaining parts should be retained.
  2) Walk the context stack from top to bottom, finding the first context
  that is a) a hash containing the name as a key OR b) an object responding
  to a method with the given name.
  3) If the context is a hash, the data is the value associated with the
  name.
  4) If the context is an object and the method with the given name has an
  arity of 1, the method SHOULD be called with a String containing the
  unprocessed contents of the sections; the data is the value returned.
  5) Otherwise, the data is the value returned by calling the method with
  the given name.
  6) If any name parts were retained in step 1, each should be resolved
  against a context stack containing only the result from the former
  resolution.  If any part fails resolution, the result should be considered
  falsey, and should interpolate as the empty string.
If the data is not of a list type, it is coerced into a list as follows: if
the data is truthy (e.g. `!!data == true`), use a single-element list
containing the data, otherwise use an empty list.

This section MUST NOT be rendered unless the data list is empty.

Inverted Section and End Section tags SHOULD be treated as standalone when
appropriate.

 */
final class InvertedTests: XCTestCase {
    func testFalsey() throws {
        let template = "\"{{^boolean}}This should be rendered.{{/boolean}}\""
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"This should be rendered.\"", "Falsey sections should have their contents rendered.")
    }

    func testTruthy() throws {
        let template = "\"{{^boolean}}This should not be rendered.{{/boolean}}\""
        let contextJSONString = "{\"boolean\":true}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "Truthy sections should have their contents omitted.")
    }

    func testContext() throws {
        let template = "\"{{^context}}Hi {{name}}.{{/context}}\""
        let contextJSONString = "{\"context\":{\"name\":\"Joe\"}}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "Objects and hashes should behave like truthy values.")
    }

    func testList() throws {
        let template = "\"{{^list}}{{n}}{{/list}}\""
        let contextJSONString = "{\"list\":[{\"n\":1},{\"n\":2},{\"n\":3}]}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "Lists should behave like truthy values.")
    }

    func testEmptyList() throws {
        let template = "\"{{^list}}Yay lists!{{/list}}\""
        let contextJSONString = "{\"list\":[]}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Yay lists!\"", "Empty lists should behave like falsey values.")
    }

    func testDoubled() throws {
        let template = "{{^bool}}\n* first\n{{/bool}}\n* {{two}}\n{{^bool}}\n* third\n{{/bool}}\n"
        let contextJSONString = "{\"two\":\"second\",\"bool\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "* first\n* second\n* third\n", "Multiple inverted sections per template should be permitted.")
    }

    func testNested_Falsey() throws {
        let template = "| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSONString = "{\"bool\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| A B C D E |", "Nested falsey sections should have their contents rendered.")
    }

    func testNested_Truthy() throws {
        let template = "| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSONString = "{\"bool\":true}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| A  E |", "Nested truthy sections should be omitted.")
    }

    func testContextMisses() throws {
        let template = "[{{^missing}}Cannot find key 'missing'!{{/missing}}]"
        let contextJSONString = "{}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "[Cannot find key 'missing'!]", "Failed context lookups should be considered falsey.")
    }

    func testDottedNames_Truthy() throws {
        let template = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":true}}}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\" == \"\"", "Dotted names should be valid for Inverted Section tags.")
    }

    func testDottedNames_Falsey() throws {
        let template = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"Not Here\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":false}}}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Not Here\" == \"Not Here\"", "Dotted names should be valid for Inverted Section tags.")
    }

    func testDottedNames_BrokenChains() throws {
        let template = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"Not Here\""
        let contextJSONString = "{\"a\":{}}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Not Here\" == \"Not Here\"", "Dotted names that cannot be resolved should be considered falsey.")
    }

    func testSurroundingWhitespace() throws {
        let template = " | {{^boolean}}\t|\t{{/boolean}} | \n"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " | \t|\t | \n", "Inverted sections should not alter surrounding whitespace.")
    }

    func testInternalWhitespace() throws {
        let template = " | {{^boolean}} {{! Important Whitespace }}\n {{/boolean}} | \n"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " |  \n  | \n", "Inverted should not alter internal whitespace.")
    }

    func testIndentedInlineSections() throws {
        let template = " {{^boolean}}NO{{/boolean}}\n {{^boolean}}WAY{{/boolean}}\n"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " NO\n WAY\n", "Single-line sections should not alter surrounding whitespace.")
    }

    func testStandaloneLines() throws {
        let template = "| This Is\n{{^boolean}}\n|\n{{/boolean}}\n| A Line\n"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| This Is\n|\n| A Line\n", "Standalone lines should be removed from the template.")
    }

    func testStandaloneIndentedLines() throws {
        let template = "| This Is\n  {{^boolean}}\n|\n  {{/boolean}}\n| A Line\n"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| This Is\n|\n| A Line\n", "Standalone indented lines should be removed from the template.")
    }

    func testStandaloneLineEndings() throws {
        let template = "|\r\n{{^boolean}}\r\n{{/boolean}}\r\n|"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|\r\n|", "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let template = "  {{^boolean}}\n^{{/boolean}}\n/"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "^\n/", "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let template = "^{{^boolean}}\n/\n  {{/boolean}}"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "^\n/\n", "Standalone tags should not require a newline to follow them.")
    }

    func testPadding() throws {
        let template = "|{{^ boolean }}={{/ boolean }}|"
        let contextJSONString = "{\"boolean\":false}"
        let contextJSON = try JSONParser().parse(data: contextJSONString.data)
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: parse(reader: Reader(template)))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|=|", "Superfluous in-tag whitespace should be ignored.")
    }
}
