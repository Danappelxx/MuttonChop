//
//  InterpolationTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/31/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

/**
Interpolation tags are used to integrate dynamic content into the template.

The tag's content MUST be a non-whitespace character sequence NOT containing
the current closing delimiter.

This tag's content names the data to replace the tag.  A single period (`.`)
indicates that the item currently sitting atop the context stack should be
used; otherwise, name resolution is as follows:
  1) Split the name on periods; the first part is the name to resolve, any
  remaining parts should be retained.
  2) Walk the context stack from top to bottom, finding the first context
  that is a) a hash containing the name as a key OR b) an object responding
  to a method with the given name.
  3) If the context is a hash, the data is the value associated with the
  name.
  4) If the context is an object, the data is the value returned by the
  method with the given name.
  5) If any name parts were retained in step 1, each should be resolved
  against a context stack containing only the result from the former
  resolution.  If any part fails resolution, the result should be considered
  falsey, and should interpolate as the empty string.
Data should be coerced into a string (and escaped, if appropriate) before
interpolation.

The Interpolation tags MUST NOT be treated as standalone.

 */
final class InterpolationTests: XCTestCase {
    func testNoInterpolation() throws {
        let template = "Hello from {Mustache}!\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Hello from {Mustache}!\n", "Mustache-free templates should render as-is.")
    }

    func testBasicInterpolation() throws {
        let template = "Hello, {{subject}}!\n"
        let contextJSONString = "{\"subject\":\"world\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Hello, world!\n", "Unadorned tags should interpolate content into the template.")
    }

    func testHTMLEscaping() throws {
        let template = "These characters should be HTML escaped: {{forbidden}}\n"
        let contextJSONString = "{\"forbidden\":\"& \" < >\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n", "Basic interpolation should be HTML escaped.")
    }

    func testTripleMustache() throws {
        let template = "These characters should not be HTML escaped: {{{forbidden}}}\n"
        let contextJSONString = "{\"forbidden\":\"& \" < >\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "These characters should not be HTML escaped: & \" < >\n", "Triple mustaches should interpolate without HTML escaping.")
    }

    func testAmpersand() throws {
        let template = "These characters should not be HTML escaped: {{&forbidden}}\n"
        let contextJSONString = "{\"forbidden\":\"& \" < >\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "These characters should not be HTML escaped: & \" < >\n", "Ampersand should interpolate without HTML escaping.")
    }

    func testBasicIntegerInterpolation() throws {
        let template = "\"{{mph}} miles an hour!\""
        let contextJSONString = "{\"mph\":85}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"85 miles an hour!\"", "Integers should interpolate seamlessly.")
    }

    func testTripleMustacheIntegerInterpolation() throws {
        let template = "\"{{{mph}}} miles an hour!\""
        let contextJSONString = "{\"mph\":85}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"85 miles an hour!\"", "Integers should interpolate seamlessly.")
    }

    func testAmpersandIntegerInterpolation() throws {
        let template = "\"{{&mph}} miles an hour!\""
        let contextJSONString = "{\"mph\":85}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"85 miles an hour!\"", "Integers should interpolate seamlessly.")
    }

    func testBasicDecimalInterpolation() throws {
        let template = "\"{{power}} jiggawatts!\""
        let contextJSONString = "{\"power\":1.21}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"1.21 jiggawatts!\"", "Decimals should interpolate seamlessly with proper significance.")
    }

    func testTripleMustacheDecimalInterpolation() throws {
        let template = "\"{{{power}}} jiggawatts!\""
        let contextJSONString = "{\"power\":1.21}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"1.21 jiggawatts!\"", "Decimals should interpolate seamlessly with proper significance.")
    }

    func testAmpersandDecimalInterpolation() throws {
        let template = "\"{{&power}} jiggawatts!\""
        let contextJSONString = "{\"power\":1.21}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"1.21 jiggawatts!\"", "Decimals should interpolate seamlessly with proper significance.")
    }

    func testBasicContextMissInterpolation() throws {
        let template = "I ({{cannot}}) be seen!"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "I () be seen!", "Failed context lookups should default to empty strings.")
    }

    func testTripleMustacheContextMissInterpolation() throws {
        let template = "I ({{{cannot}}}) be seen!"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "I () be seen!", "Failed context lookups should default to empty strings.")
    }

    func testAmpersandContextMissInterpolation() throws {
        let template = "I ({{&cannot}}) be seen!"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "I () be seen!", "Failed context lookups should default to empty strings.")
    }

    func testDottedNames_BasicInterpolation() throws {
        let template = "\"{{person.name}}\" == \"{{#person}}{{name}}{{/person}}\""
        let contextJSONString = "{\"person\":{\"name\":\"Joe\"}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Joe\" == \"Joe\"", "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_TripleMustacheInterpolation() throws {
        let template = "\"{{{person.name}}}\" == \"{{#person}}{{{name}}}{{/person}}\""
        let contextJSONString = "{\"person\":{\"name\":\"Joe\"}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Joe\" == \"Joe\"", "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_AmpersandInterpolation() throws {
        let template = "\"{{&person.name}}\" == \"{{#person}}{{&name}}{{/person}}\""
        let contextJSONString = "{\"person\":{\"name\":\"Joe\"}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Joe\" == \"Joe\"", "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_ArbitraryDepth() throws {
        let template = "\"{{a.b.c.d.e.name}}\" == \"Phil\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Phil\"}}}}}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Phil\" == \"Phil\"", "Dotted names should be functional to any level of nesting.")
    }

    func testDottedNames_BrokenChains() throws {
        let template = "\"{{a.b.c}}\" == \"\""
        let contextJSONString = "{\"a\":{}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\" == \"\"", "Any falsey value prior to the last part of the name should yield ''.")
    }

    func testDottedNames_BrokenChainResolution() throws {
        let template = "\"{{a.b.c.name}}\" == \"\""
        let contextJSONString = "{\"a\":{\"b\":{}},\"c\":{\"name\":\"Jim\"}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"\" == \"\"", "Each part of a dotted name should resolve only against its parent.")
    }

    func testDottedNames_InitialResolution() throws {
        let template = "\"{{#a}}{{b.c.d.e.name}}{{/a}}\" == \"Phil\""
        let contextJSONString = "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Phil\"}}}}},\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Wrong\"}}}}}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "\"Phil\" == \"Phil\"", "The first part of a dotted name should resolve as any other name.")
    }

    func testInterpolation_SurroundingWhitespace() throws {
        let template = "| {{string}} |"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| --- |", "Interpolation should not alter surrounding whitespace.")
    }

    func testTripleMustache_SurroundingWhitespace() throws {
        let template = "| {{{string}}} |"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| --- |", "Interpolation should not alter surrounding whitespace.")
    }

    func testAmpersand_SurroundingWhitespace() throws {
        let template = "| {{&string}} |"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "| --- |", "Interpolation should not alter surrounding whitespace.")
    }

    func testInterpolation_Standalone() throws {
        let template = "  {{string}}\n"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  ---\n", "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testTripleMustache_Standalone() throws {
        let template = "  {{{string}}}\n"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  ---\n", "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testAmpersand_Standalone() throws {
        let template = "  {{&string}}\n"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  ---\n", "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testInterpolationWithPadding() throws {
        let template = "|{{ string }}|"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|---|", "Superfluous in-tag whitespace should be ignored.")
    }

    func testTripleMustacheWithPadding() throws {
        let template = "|{{{ string }}}|"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|---|", "Superfluous in-tag whitespace should be ignored.")
    }

    func testAmpersandWithPadding() throws {
        let template = "|{{& string }}|"
        let contextJSONString = "{\"string\":\"---\"}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(reader: parse(reader: template.reader()).reader())
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|---|", "Superfluous in-tag whitespace should be ignored.")
    }
}
