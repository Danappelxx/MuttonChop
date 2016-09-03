//
//  SectionsTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

/**
Section tags and End Section tags are used in combination to wrap a section
of the template for iteration

These tags' content MUST be a non-whitespace character sequence NOT
containing the current closing delimiter; each Section tag MUST be followed
by an End Section tag with the same content within the same section.

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

For each element in the data list, the element MUST be pushed onto the
context stack, the section MUST be rendered, and the element MUST be popped
off the context stack.

Section and End Section tags SHOULD be treated as standalone when
appropriate.

 */
final class SectionsTests: XCTestCase {
    func testTruthy() throws {
        let template = "\"{{#boolean}}This should be rendered.{{/boolean}}\""
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"This should be rendered.\"", "Truthy sections should have their contents rendered.")
    }

    func testFalsey() throws {
        let template = "\"{{#boolean}}This should not be rendered.{{/boolean}}\""
        let contextJSONString = "{\"boolean\":\"false\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "Falsey sections should have their contents omitted.")
    }

    func testContext() throws {
        let template = "\"{{#context}}Hi {{name}}.{{/context}}\""
        let contextJSONString = "{\"context\":{\"name\":\"Joe\"}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Hi Joe.\"", "Objects and hashes should be pushed onto the context stack.")
    }

    func testDeeplyNestedContexts() throws {
        let template = "{{#a}}\n{{one}}\n{{#b}}\n{{one}}{{two}}{{one}}\n{{#c}}\n{{one}}{{two}}{{three}}{{two}}{{one}}\n{{#d}}\n{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}\n{{#e}}\n{{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}\n{{/e}}\n{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}\n{{/d}}\n{{one}}{{two}}{{three}}{{two}}{{one}}\n{{/c}}\n{{one}}{{two}}{{one}}\n{{/b}}\n{{one}}\n{{/a}}\n"
        let contextJSONString = "{\"d\":{\"four\":4},\"b\":{\"two\":2},\"e\":{\"five\":5},\"c\":{\"three\":3},\"a\":{\"one\":1}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "1\n121\n12321\n1234321\n123454321\n1234321\n12321\n121\n1\n", "All elements on the context stack should be accessible.")
    }

    func testList() throws {
        let template = "\"{{#list}}{{item}}{{/list}}\""
        let contextJSONString = "{\"list\":[{\"item\":1},{\"item\":2},{\"item\":3}]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"123\"", "Lists should be iterated; list items should visit the context stack.")
    }

    func testEmptyList() throws {
        let template = "\"{{#list}}Yay lists!{{/list}}\""
        let contextJSONString = "{\"list\":[]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\"", "Empty lists should behave like falsey values.")
    }

    func testDoubled() throws {
        let template = "{{#bool}}\n* first\n{{/bool}}\n* {{two}}\n{{#bool}}\n* third\n{{/bool}}\n"
        let contextJSONString = "{\"two\":\"second\",\"bool\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "* first\n* second\n* third\n", "Multiple sections per template should be permitted.")
    }

    func testNested_Truthy() throws {
        let template = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSONString = "{\"bool\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| A B C D E |", "Nested truthy sections should have their contents rendered.")
    }

    func testNested_Falsey() throws {
        let template = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSONString = "{\"bool\":\"false\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| A  E |", "Nested falsey sections should be omitted.")
    }

    func testContextMisses() throws {
        let template = "[{{#missing}}Found key 'missing'!{{/missing}}]"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "[]", "Failed context lookups should be considered falsey.")
    }

    func testImplicitIterator_String() throws {
        let template = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSONString = "{\"list\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"(a)(b)(c)(d)(e)\"", "Implicit iterators should directly interpolate strings.")
    }

    func testImplicitIterator_Integer() throws {
        let template = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSONString = "{\"list\":[1,2,3,4,5]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"(1)(2)(3)(4)(5)\"", "Implicit iterators should cast integers to strings and interpolate.")
    }

    func testImplicitIterator_Decimal() throws {
        let template = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSONString = "{\"list\":[1.1,2.2,3.3,4.4,5.5]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"(1.1)(2.2)(3.3)(4.4)(5.5)\"", "Implicit iterators should cast decimals to strings and interpolate.")
    }

    func testImplicitIterator_Array() throws {
        let template = "\"{{#list}}({{#.}}{{.}}{{/.}}){{/list}}\""
        let contextJSONString = "{\"list\":[[1,2,3],[\"a\",\"b\",\"c\"]]}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"(123)(abc)\"", "Implicit iterators should allow iterating over nested arrays.")
    }

    func testDottedNames_Truthy() throws {
        let template = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"Here\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":\"true\"}}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Here\" == \"Here\"", "Dotted names should be valid for Section tags.")
    }

    func testDottedNames_Falsey() throws {
        let template = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":\"false\"}}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\" == \"\"", "Dotted names should be valid for Section tags.")
    }

    func testDottedNames_BrokenChains() throws {
        let template = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"\""
        let contextJSONString = "{\"a\":{}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\" == \"\"", "Dotted names that cannot be resolved should be considered falsey.")
    }

    func testSurroundingWhitespace() throws {
        let template = " | {{#boolean}}\t|\t{{/boolean}} | \n"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " | \t|\t | \n", "Sections should not alter surrounding whitespace.")
    }

    func testInternalWhitespace() throws {
        let template = " | {{#boolean}} {{! Important Whitespace }}\n {{/boolean}} | \n"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " |  \n  | \n", "Sections should not alter internal whitespace.")
    }

    func testIndentedInlineSections() throws {
        let template = " {{#boolean}}YES{{/boolean}}\n {{#boolean}}GOOD{{/boolean}}\n"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, " YES\n GOOD\n", "Single-line sections should not alter surrounding whitespace.")
    }

    func testStandaloneLines() throws {
        let template = "| This Is\n{{#boolean}}\n|\n{{/boolean}}\n| A Line\n"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| This Is\n|\n| A Line\n", "Standalone lines should be removed from the template.")
    }

    func testIndentedStandaloneLines() throws {
        let template = "| This Is\n  {{#boolean}}\n|\n  {{/boolean}}\n| A Line\n"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| This Is\n|\n| A Line\n", "Indented standalone lines should be removed from the template.")
    }

    func testStandaloneLineEndings() throws {
        let template = "|\r\n{{#boolean}}\r\n{{/boolean}}\r\n|"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|\r\n|", "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let template = "  {{#boolean}}\n#{{/boolean}}\n/"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "#\n/", "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let template = "#{{#boolean}}\n/\n  {{/boolean}}"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "#\n/\n", "Standalone tags should not require a newline to follow them.")
    }

    func testPadding() throws {
        let template = "|{{# boolean }}={{/ boolean }}|"
        let contextJSONString = "{\"boolean\":\"true\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|=|", "Superfluous in-tag whitespace should be ignored.")
    }
}
