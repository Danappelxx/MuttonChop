import XCTest
import MuttonChop


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
    static var allTests: [(String, (SectionsTests) -> () throws -> Void)] {
        return [
            ("testTruthy", testTruthy),
            ("testFalsey", testFalsey),
            ("testNullisfalsey", testNullisfalsey),
            ("testContext", testContext),
            ("testParentcontexts", testParentcontexts),
            ("testVariabletest", testVariabletest),
            ("testListContexts", testListContexts),
            ("testDeeplyNestedContexts", testDeeplyNestedContexts),
            ("testList", testList),
            ("testEmptyList", testEmptyList),
            ("testDoubled", testDoubled),
            ("testNested_Truthy", testNested_Truthy),
            ("testNested_Falsey", testNested_Falsey),
            ("testContextMisses", testContextMisses),
            ("testImplicitIterator_String", testImplicitIterator_String),
            ("testImplicitIterator_Integer", testImplicitIterator_Integer),
            ("testImplicitIterator_Decimal", testImplicitIterator_Decimal),
            ("testImplicitIterator_Array", testImplicitIterator_Array),
            ("testDottedNames_Truthy", testDottedNames_Truthy),
            ("testDottedNames_Falsey", testDottedNames_Falsey),
            ("testDottedNames_BrokenChains", testDottedNames_BrokenChains),
            ("testSurroundingWhitespace", testSurroundingWhitespace),
            ("testInternalWhitespace", testInternalWhitespace),
            ("testIndentedInlineSections", testIndentedInlineSections),
            ("testStandaloneLines", testStandaloneLines),
            ("testIndentedStandaloneLines", testIndentedStandaloneLines),
            ("testStandaloneLineEndings", testStandaloneLineEndings),
            ("testStandaloneWithoutPreviousLine", testStandaloneWithoutPreviousLine),
            ("testStandaloneWithoutNewline", testStandaloneWithoutNewline),
            ("testPadding", testPadding),
        ]
    }

    func testTruthy() throws {
        let templateString = "\"{{#boolean}}This should be rendered.{{/boolean}}\""
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "\"This should be rendered.\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Truthy sections should have their contents rendered.")
    }

    func testFalsey() throws {
        let templateString = "\"{{#boolean}}This should not be rendered.{{/boolean}}\""
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Falsey sections should have their contents omitted.")
    }

    func testNullisfalsey() throws {
        let templateString = "\"{{#null}}This should not be rendered.{{/null}}\""
        let contextJSON = "{\"null\":null}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Null is falsey.")
    }

    func testContext() throws {
        let templateString = "\"{{#context}}Hi {{name}}.{{/context}}\""
        let contextJSON = "{\"context\":{\"name\":\"Joe\"}}".data(using: .utf8)!
        let expected = "\"Hi Joe.\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Objects and hashes should be pushed onto the context stack.")
    }

    func testParentcontexts() throws {
        let templateString = "\"{{#sec}}{{a}}, {{b}}, {{c.d}}{{/sec}}\""
        let contextJSON = "{\"sec\":{\"b\":\"bar\"},\"b\":\"wrong\",\"c\":{\"d\":\"baz\"},\"a\":\"foo\"}".data(using: .utf8)!
        let expected = "\"foo, bar, baz\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Names missing in the current context are looked up in the stack.")
    }

    func testVariabletest() throws {
        let templateString = "\"{{#foo}}{{.}} is {{foo}}{{/foo}}\""
        let contextJSON = "{\"foo\":\"bar\"}".data(using: .utf8)!
        let expected = "\"bar is bar\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Non-false sections have their value at the top of context, accessible as {{.}} or through the parent context. This gives a simple way to display content conditionally if a variable exists. ")
    }

    func testListContexts() throws {
        let templateString = "{{#tops}}{{#middles}}{{tname.lower}}{{mname}}.{{#bottoms}}{{tname.upper}}{{mname}}{{bname}}.{{/bottoms}}{{/middles}}{{/tops}}"
        let contextJSON = "{\"tops\":[{\"middles\":[{\"mname\":\"1\",\"bottoms\":[{\"bname\":\"x\"},{\"bname\":\"y\"}]}],\"tname\":{\"lower\":\"a\",\"upper\":\"A\"}}]}".data(using: .utf8)!
        let expected = "a1.A1x.A1y."

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All elements on the context stack should be accessible within lists.")
    }

    func testDeeplyNestedContexts() throws {
        let templateString = "{{#a}}\n{{one}}\n{{#b}}\n{{one}}{{two}}{{one}}\n{{#c}}\n{{one}}{{two}}{{three}}{{two}}{{one}}\n{{#d}}\n{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}\n{{#five}}\n{{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}\n{{one}}{{two}}{{three}}{{four}}{{.}}6{{.}}{{four}}{{three}}{{two}}{{one}}\n{{one}}{{two}}{{three}}{{four}}{{five}}{{four}}{{three}}{{two}}{{one}}\n{{/five}}\n{{one}}{{two}}{{three}}{{four}}{{three}}{{two}}{{one}}\n{{/d}}\n{{one}}{{two}}{{three}}{{two}}{{one}}\n{{/c}}\n{{one}}{{two}}{{one}}\n{{/b}}\n{{one}}\n{{/a}}\n"
        let contextJSON = "{\"b\":{\"two\":2},\"c\":{\"three\":3,\"d\":{\"four\":4,\"five\":5}},\"a\":{\"one\":1}}".data(using: .utf8)!
        let expected = "1\n121\n12321\n1234321\n123454321\n12345654321\n123454321\n1234321\n12321\n121\n1\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All elements on the context stack should be accessible.")
    }

    func testList() throws {
        let templateString = "\"{{#list}}{{item}}{{/list}}\""
        let contextJSON = "{\"list\":[{\"item\":1},{\"item\":2},{\"item\":3}]}".data(using: .utf8)!
        let expected = "\"123\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Lists should be iterated; list items should visit the context stack.")
    }

    func testEmptyList() throws {
        let templateString = "\"{{#list}}Yay lists!{{/list}}\""
        let contextJSON = "{\"list\":[]}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Empty lists should behave like falsey values.")
    }

    func testDoubled() throws {
        let templateString = "{{#bool}}\n* first\n{{/bool}}\n* {{two}}\n{{#bool}}\n* third\n{{/bool}}\n"
        let contextJSON = "{\"two\":\"second\",\"bool\":true}".data(using: .utf8)!
        let expected = "* first\n* second\n* third\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Multiple sections per template should be permitted.")
    }

    func testNested_Truthy() throws {
        let templateString = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSON = "{\"bool\":true}".data(using: .utf8)!
        let expected = "| A B C D E |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nested truthy sections should have their contents rendered.")
    }

    func testNested_Falsey() throws {
        let templateString = "| A {{#bool}}B {{#bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSON = "{\"bool\":false}".data(using: .utf8)!
        let expected = "| A  E |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nested falsey sections should be omitted.")
    }

    func testContextMisses() throws {
        let templateString = "[{{#missing}}Found key 'missing'!{{/missing}}]"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "[]"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Failed context lookups should be considered falsey.")
    }

    func testImplicitIterator_String() throws {
        let templateString = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSON = "{\"list\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}".data(using: .utf8)!
        let expected = "\"(a)(b)(c)(d)(e)\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Implicit iterators should directly interpolate strings.")
    }

    func testImplicitIterator_Integer() throws {
        let templateString = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSON = "{\"list\":[1,2,3,4,5]}".data(using: .utf8)!
        let expected = "\"(1)(2)(3)(4)(5)\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Implicit iterators should cast integers to strings and interpolate.")
    }

    func testImplicitIterator_Decimal() throws {
        let templateString = "\"{{#list}}({{.}}){{/list}}\""
        let contextJSON = "{\"list\":[1.1000000000000001,2.2000000000000002,3.2999999999999998,4.4000000000000004,5.5]}".data(using: .utf8)!
        let expected = "\"(1.1)(2.2)(3.3)(4.4)(5.5)\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Implicit iterators should cast decimals to strings and interpolate.")
    }

    func testImplicitIterator_Array() throws {
        let templateString = "\"{{#list}}({{#.}}{{.}}{{/.}}){{/list}}\""
        let contextJSON = "{\"list\":[[1,2,3],[\"a\",\"b\",\"c\"]]}".data(using: .utf8)!
        let expected = "\"(123)(abc)\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Implicit iterators should allow iterating over nested arrays.")
    }

    func testDottedNames_Truthy() throws {
        let templateString = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"Here\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":true}}}".data(using: .utf8)!
        let expected = "\"Here\" == \"Here\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be valid for Section tags.")
    }

    func testDottedNames_Falsey() throws {
        let templateString = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":false}}}".data(using: .utf8)!
        let expected = "\"\" == \"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be valid for Section tags.")
    }

    func testDottedNames_BrokenChains() throws {
        let templateString = "\"{{#a.b.c}}Here{{/a.b.c}}\" == \"\""
        let contextJSON = "{\"a\":{}}".data(using: .utf8)!
        let expected = "\"\" == \"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names that cannot be resolved should be considered falsey.")
    }

    func testSurroundingWhitespace() throws {
        let templateString = " | {{#boolean}}\t|\t{{/boolean}} | \n"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = " | \t|\t | \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Sections should not alter surrounding whitespace.")
    }

    func testInternalWhitespace() throws {
        let templateString = " | {{#boolean}} {{! Important Whitespace }}\n {{/boolean}} | \n"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = " |  \n  | \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Sections should not alter internal whitespace.")
    }

    func testIndentedInlineSections() throws {
        let templateString = " {{#boolean}}YES{{/boolean}}\n {{#boolean}}GOOD{{/boolean}}\n"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = " YES\n GOOD\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Single-line sections should not alter surrounding whitespace.")
    }

    func testStandaloneLines() throws {
        let templateString = "| This Is\n{{#boolean}}\n|\n{{/boolean}}\n| A Line\n"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "| This Is\n|\n| A Line\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone lines should be removed from the template.")
    }

    func testIndentedStandaloneLines() throws {
        let templateString = "| This Is\n  {{#boolean}}\n|\n  {{/boolean}}\n| A Line\n"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "| This Is\n|\n| A Line\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Indented standalone lines should be removed from the template.")
    }

    func testStandaloneLineEndings() throws {
        let templateString = "|\r\n{{#boolean}}\r\n{{/boolean}}\r\n|"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "|\r\n|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let templateString = "  {{#boolean}}\n#{{/boolean}}\n/"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "#\n/"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let templateString = "#{{#boolean}}\n/\n  {{/boolean}}"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "#\n/\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to follow them.")
    }

    func testPadding() throws {
        let templateString = "|{{# boolean }}={{/ boolean }}|"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "|=|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }
}


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
    static var allTests: [(String, (InterpolationTests) -> () throws -> Void)] {
        return [
            ("testNoInterpolation", testNoInterpolation),
            ("testBasicInterpolation", testBasicInterpolation),
            ("testHTMLEscaping", testHTMLEscaping),
            ("testTripleMustache", testTripleMustache),
            ("testAmpersand", testAmpersand),
            ("testBasicIntegerInterpolation", testBasicIntegerInterpolation),
            ("testTripleMustacheIntegerInterpolation", testTripleMustacheIntegerInterpolation),
            ("testAmpersandIntegerInterpolation", testAmpersandIntegerInterpolation),
            ("testBasicDecimalInterpolation", testBasicDecimalInterpolation),
            ("testTripleMustacheDecimalInterpolation", testTripleMustacheDecimalInterpolation),
            ("testAmpersandDecimalInterpolation", testAmpersandDecimalInterpolation),
            ("testBasicNullInterpolation", testBasicNullInterpolation),
            ("testTripleMustacheNullInterpolation", testTripleMustacheNullInterpolation),
            ("testAmpersandNullInterpolation", testAmpersandNullInterpolation),
            ("testBasicContextMissInterpolation", testBasicContextMissInterpolation),
            ("testTripleMustacheContextMissInterpolation", testTripleMustacheContextMissInterpolation),
            ("testAmpersandContextMissInterpolation", testAmpersandContextMissInterpolation),
            ("testDottedNames_BasicInterpolation", testDottedNames_BasicInterpolation),
            ("testDottedNames_TripleMustacheInterpolation", testDottedNames_TripleMustacheInterpolation),
            ("testDottedNames_AmpersandInterpolation", testDottedNames_AmpersandInterpolation),
            ("testDottedNames_ArbitraryDepth", testDottedNames_ArbitraryDepth),
            ("testDottedNames_BrokenChains", testDottedNames_BrokenChains),
            ("testDottedNames_BrokenChainResolution", testDottedNames_BrokenChainResolution),
            ("testDottedNames_InitialResolution", testDottedNames_InitialResolution),
            ("testDottedNames_ContextPrecedence", testDottedNames_ContextPrecedence),
            ("testImplicitIterators_BasicInterpolation", testImplicitIterators_BasicInterpolation),
            ("testImplicitIterators_HTMLEscaping", testImplicitIterators_HTMLEscaping),
            ("testImplicitIterators_TripleMustache", testImplicitIterators_TripleMustache),
            ("testImplicitIterators_Ampersand", testImplicitIterators_Ampersand),
            ("testImplicitIterators_BasicIntegerInterpolation", testImplicitIterators_BasicIntegerInterpolation),
            ("testInterpolation_SurroundingWhitespace", testInterpolation_SurroundingWhitespace),
            ("testTripleMustache_SurroundingWhitespace", testTripleMustache_SurroundingWhitespace),
            ("testAmpersand_SurroundingWhitespace", testAmpersand_SurroundingWhitespace),
            ("testInterpolation_Standalone", testInterpolation_Standalone),
            ("testTripleMustache_Standalone", testTripleMustache_Standalone),
            ("testAmpersand_Standalone", testAmpersand_Standalone),
            ("testInterpolationWithPadding", testInterpolationWithPadding),
            ("testTripleMustacheWithPadding", testTripleMustacheWithPadding),
            ("testAmpersandWithPadding", testAmpersandWithPadding),
        ]
    }

    func testNoInterpolation() throws {
        let templateString = "Hello from {Mustache}!\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Hello from {Mustache}!\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Mustache-free templates should render as-is.")
    }

    func testBasicInterpolation() throws {
        let templateString = "Hello, {{subject}}!\n"
        let contextJSON = "{\"subject\":\"world\"}".data(using: .utf8)!
        let expected = "Hello, world!\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Unadorned tags should interpolate content into the template.")
    }

    func testHTMLEscaping() throws {
        let templateString = "These characters should be HTML escaped: {{forbidden}}\n"
        let contextJSON = "{\"forbidden\":\"& \\\" < >\"}".data(using: .utf8)!
        let expected = "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Basic interpolation should be HTML escaped.")
    }

    func testTripleMustache() throws {
        let templateString = "These characters should not be HTML escaped: {{{forbidden}}}\n"
        let contextJSON = "{\"forbidden\":\"& \\\" < >\"}".data(using: .utf8)!
        let expected = "These characters should not be HTML escaped: & \" < >\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Triple mustaches should interpolate without HTML escaping.")
    }

    func testAmpersand() throws {
        let templateString = "These characters should not be HTML escaped: {{&forbidden}}\n"
        let contextJSON = "{\"forbidden\":\"& \\\" < >\"}".data(using: .utf8)!
        let expected = "These characters should not be HTML escaped: & \" < >\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Ampersand should interpolate without HTML escaping.")
    }

    func testBasicIntegerInterpolation() throws {
        let templateString = "\"{{mph}} miles an hour!\""
        let contextJSON = "{\"mph\":85}".data(using: .utf8)!
        let expected = "\"85 miles an hour!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Integers should interpolate seamlessly.")
    }

    func testTripleMustacheIntegerInterpolation() throws {
        let templateString = "\"{{{mph}}} miles an hour!\""
        let contextJSON = "{\"mph\":85}".data(using: .utf8)!
        let expected = "\"85 miles an hour!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Integers should interpolate seamlessly.")
    }

    func testAmpersandIntegerInterpolation() throws {
        let templateString = "\"{{&mph}} miles an hour!\""
        let contextJSON = "{\"mph\":85}".data(using: .utf8)!
        let expected = "\"85 miles an hour!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Integers should interpolate seamlessly.")
    }

    func testBasicDecimalInterpolation() throws {
        let templateString = "\"{{power}} jiggawatts!\""
        let contextJSON = "{\"power\":1.21}".data(using: .utf8)!
        let expected = "\"1.21 jiggawatts!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Decimals should interpolate seamlessly with proper significance.")
    }

    func testTripleMustacheDecimalInterpolation() throws {
        let templateString = "\"{{{power}}} jiggawatts!\""
        let contextJSON = "{\"power\":1.21}".data(using: .utf8)!
        let expected = "\"1.21 jiggawatts!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Decimals should interpolate seamlessly with proper significance.")
    }

    func testAmpersandDecimalInterpolation() throws {
        let templateString = "\"{{&power}} jiggawatts!\""
        let contextJSON = "{\"power\":1.21}".data(using: .utf8)!
        let expected = "\"1.21 jiggawatts!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Decimals should interpolate seamlessly with proper significance.")
    }

    func testBasicNullInterpolation() throws {
        let templateString = "I ({{cannot}}) be seen!"
        let contextJSON = "{\"cannot\":null}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nulls should interpolate as the empty string.")
    }

    func testTripleMustacheNullInterpolation() throws {
        let templateString = "I ({{{cannot}}}) be seen!"
        let contextJSON = "{\"cannot\":null}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nulls should interpolate as the empty string.")
    }

    func testAmpersandNullInterpolation() throws {
        let templateString = "I ({{&cannot}}) be seen!"
        let contextJSON = "{\"cannot\":null}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nulls should interpolate as the empty string.")
    }

    func testBasicContextMissInterpolation() throws {
        let templateString = "I ({{cannot}}) be seen!"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Failed context lookups should default to empty strings.")
    }

    func testTripleMustacheContextMissInterpolation() throws {
        let templateString = "I ({{{cannot}}}) be seen!"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Failed context lookups should default to empty strings.")
    }

    func testAmpersandContextMissInterpolation() throws {
        let templateString = "I ({{&cannot}}) be seen!"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "I () be seen!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Failed context lookups should default to empty strings.")
    }

    func testDottedNames_BasicInterpolation() throws {
        let templateString = "\"{{person.name}}\" == \"{{#person}}{{name}}{{/person}}\""
        let contextJSON = "{\"person\":{\"name\":\"Joe\"}}".data(using: .utf8)!
        let expected = "\"Joe\" == \"Joe\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_TripleMustacheInterpolation() throws {
        let templateString = "\"{{{person.name}}}\" == \"{{#person}}{{{name}}}{{/person}}\""
        let contextJSON = "{\"person\":{\"name\":\"Joe\"}}".data(using: .utf8)!
        let expected = "\"Joe\" == \"Joe\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_AmpersandInterpolation() throws {
        let templateString = "\"{{&person.name}}\" == \"{{#person}}{{&name}}{{/person}}\""
        let contextJSON = "{\"person\":{\"name\":\"Joe\"}}".data(using: .utf8)!
        let expected = "\"Joe\" == \"Joe\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be considered a form of shorthand for sections.")
    }

    func testDottedNames_ArbitraryDepth() throws {
        let templateString = "\"{{a.b.c.d.e.name}}\" == \"Phil\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Phil\"}}}}}}".data(using: .utf8)!
        let expected = "\"Phil\" == \"Phil\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be functional to any level of nesting.")
    }

    func testDottedNames_BrokenChains() throws {
        let templateString = "\"{{a.b.c}}\" == \"\""
        let contextJSON = "{\"a\":{}}".data(using: .utf8)!
        let expected = "\"\" == \"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Any falsey value prior to the last part of the name should yield ''.")
    }

    func testDottedNames_BrokenChainResolution() throws {
        let templateString = "\"{{a.b.c.name}}\" == \"\""
        let contextJSON = "{\"a\":{\"b\":{}},\"c\":{\"name\":\"Jim\"}}".data(using: .utf8)!
        let expected = "\"\" == \"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Each part of a dotted name should resolve only against its parent.")
    }

    func testDottedNames_InitialResolution() throws {
        let templateString = "\"{{#a}}{{b.c.d.e.name}}{{/a}}\" == \"Phil\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Phil\"}}}}},\"b\":{\"c\":{\"d\":{\"e\":{\"name\":\"Wrong\"}}}}}".data(using: .utf8)!
        let expected = "\"Phil\" == \"Phil\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "The first part of a dotted name should resolve as any other name.")
    }

    func testDottedNames_ContextPrecedence() throws {
        let templateString = "{{#a}}{{b.c}}{{/a}}"
        let contextJSON = "{\"b\":{\"c\":\"ERROR\"},\"a\":{\"b\":{}}}".data(using: .utf8)!
        let expected = ""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be resolved against former resolutions.")
    }

    func testImplicitIterators_BasicInterpolation() throws {
        let templateString = "Hello, {{.}}!\n"
        let contextJSON = "\"world\"".data(using: .utf8)!
        let expected = "Hello, world!\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Unadorned tags should interpolate content into the template.")
    }

    func testImplicitIterators_HTMLEscaping() throws {
        let templateString = "These characters should be HTML escaped: {{.}}\n"
        let contextJSON = "\"& \\\" < >\"".data(using: .utf8)!
        let expected = "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Basic interpolation should be HTML escaped.")
    }

    func testImplicitIterators_TripleMustache() throws {
        let templateString = "These characters should not be HTML escaped: {{{.}}}\n"
        let contextJSON = "\"& \\\" < >\"".data(using: .utf8)!
        let expected = "These characters should not be HTML escaped: & \" < >\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Triple mustaches should interpolate without HTML escaping.")
    }

    func testImplicitIterators_Ampersand() throws {
        let templateString = "These characters should not be HTML escaped: {{&.}}\n"
        let contextJSON = "\"& \\\" < >\"".data(using: .utf8)!
        let expected = "These characters should not be HTML escaped: & \" < >\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Ampersand should interpolate without HTML escaping.")
    }

    func testImplicitIterators_BasicIntegerInterpolation() throws {
        let templateString = "\"{{.}} miles an hour!\""
        let contextJSON = "85".data(using: .utf8)!
        let expected = "\"85 miles an hour!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Integers should interpolate seamlessly.")
    }

    func testInterpolation_SurroundingWhitespace() throws {
        let templateString = "| {{string}} |"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "| --- |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Interpolation should not alter surrounding whitespace.")
    }

    func testTripleMustache_SurroundingWhitespace() throws {
        let templateString = "| {{{string}}} |"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "| --- |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Interpolation should not alter surrounding whitespace.")
    }

    func testAmpersand_SurroundingWhitespace() throws {
        let templateString = "| {{&string}} |"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "| --- |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Interpolation should not alter surrounding whitespace.")
    }

    func testInterpolation_Standalone() throws {
        let templateString = "  {{string}}\n"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "  ---\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testTripleMustache_Standalone() throws {
        let templateString = "  {{{string}}}\n"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "  ---\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testAmpersand_Standalone() throws {
        let templateString = "  {{&string}}\n"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "  ---\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone interpolation should not alter surrounding whitespace.")
    }

    func testInterpolationWithPadding() throws {
        let templateString = "|{{ string }}|"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "|---|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }

    func testTripleMustacheWithPadding() throws {
        let templateString = "|{{{ string }}}|"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "|---|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }

    func testAmpersandWithPadding() throws {
        let templateString = "|{{& string }}|"
        let contextJSON = "{\"string\":\"---\"}".data(using: .utf8)!
        let expected = "|---|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }
}


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
    static var allTests: [(String, (InvertedTests) -> () throws -> Void)] {
        return [
            ("testFalsey", testFalsey),
            ("testTruthy", testTruthy),
            ("testNullisfalsey", testNullisfalsey),
            ("testContext", testContext),
            ("testList", testList),
            ("testEmptyList", testEmptyList),
            ("testDoubled", testDoubled),
            ("testNested_Falsey", testNested_Falsey),
            ("testNested_Truthy", testNested_Truthy),
            ("testContextMisses", testContextMisses),
            ("testDottedNames_Truthy", testDottedNames_Truthy),
            ("testDottedNames_Falsey", testDottedNames_Falsey),
            ("testDottedNames_BrokenChains", testDottedNames_BrokenChains),
            ("testSurroundingWhitespace", testSurroundingWhitespace),
            ("testInternalWhitespace", testInternalWhitespace),
            ("testIndentedInlineSections", testIndentedInlineSections),
            ("testStandaloneLines", testStandaloneLines),
            ("testStandaloneIndentedLines", testStandaloneIndentedLines),
            ("testStandaloneLineEndings", testStandaloneLineEndings),
            ("testStandaloneWithoutPreviousLine", testStandaloneWithoutPreviousLine),
            ("testStandaloneWithoutNewline", testStandaloneWithoutNewline),
            ("testPadding", testPadding),
        ]
    }

    func testFalsey() throws {
        let templateString = "\"{{^boolean}}This should be rendered.{{/boolean}}\""
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "\"This should be rendered.\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Falsey sections should have their contents rendered.")
    }

    func testTruthy() throws {
        let templateString = "\"{{^boolean}}This should not be rendered.{{/boolean}}\""
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Truthy sections should have their contents omitted.")
    }

    func testNullisfalsey() throws {
        let templateString = "\"{{^null}}This should be rendered.{{/null}}\""
        let contextJSON = "{\"null\":null}".data(using: .utf8)!
        let expected = "\"This should be rendered.\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Null is falsey.")
    }

    func testContext() throws {
        let templateString = "\"{{^context}}Hi {{name}}.{{/context}}\""
        let contextJSON = "{\"context\":{\"name\":\"Joe\"}}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Objects and hashes should behave like truthy values.")
    }

    func testList() throws {
        let templateString = "\"{{^list}}{{n}}{{/list}}\""
        let contextJSON = "{\"list\":[{\"n\":1},{\"n\":2},{\"n\":3}]}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Lists should behave like truthy values.")
    }

    func testEmptyList() throws {
        let templateString = "\"{{^list}}Yay lists!{{/list}}\""
        let contextJSON = "{\"list\":[]}".data(using: .utf8)!
        let expected = "\"Yay lists!\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Empty lists should behave like falsey values.")
    }

    func testDoubled() throws {
        let templateString = "{{^bool}}\n* first\n{{/bool}}\n* {{two}}\n{{^bool}}\n* third\n{{/bool}}\n"
        let contextJSON = "{\"two\":\"second\",\"bool\":false}".data(using: .utf8)!
        let expected = "* first\n* second\n* third\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Multiple inverted sections per template should be permitted.")
    }

    func testNested_Falsey() throws {
        let templateString = "| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSON = "{\"bool\":false}".data(using: .utf8)!
        let expected = "| A B C D E |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nested falsey sections should have their contents rendered.")
    }

    func testNested_Truthy() throws {
        let templateString = "| A {{^bool}}B {{^bool}}C{{/bool}} D{{/bool}} E |"
        let contextJSON = "{\"bool\":true}".data(using: .utf8)!
        let expected = "| A  E |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Nested truthy sections should be omitted.")
    }

    func testContextMisses() throws {
        let templateString = "[{{^missing}}Cannot find key 'missing'!{{/missing}}]"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "[Cannot find key 'missing'!]"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Failed context lookups should be considered falsey.")
    }

    func testDottedNames_Truthy() throws {
        let templateString = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":true}}}".data(using: .utf8)!
        let expected = "\"\" == \"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be valid for Inverted Section tags.")
    }

    func testDottedNames_Falsey() throws {
        let templateString = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"Not Here\""
        let contextJSON = "{\"a\":{\"b\":{\"c\":false}}}".data(using: .utf8)!
        let expected = "\"Not Here\" == \"Not Here\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names should be valid for Inverted Section tags.")
    }

    func testDottedNames_BrokenChains() throws {
        let templateString = "\"{{^a.b.c}}Not Here{{/a.b.c}}\" == \"Not Here\""
        let contextJSON = "{\"a\":{}}".data(using: .utf8)!
        let expected = "\"Not Here\" == \"Not Here\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Dotted names that cannot be resolved should be considered falsey.")
    }

    func testSurroundingWhitespace() throws {
        let templateString = " | {{^boolean}}\t|\t{{/boolean}} | \n"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = " | \t|\t | \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Inverted sections should not alter surrounding whitespace.")
    }

    func testInternalWhitespace() throws {
        let templateString = " | {{^boolean}} {{! Important Whitespace }}\n {{/boolean}} | \n"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = " |  \n  | \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Inverted should not alter internal whitespace.")
    }

    func testIndentedInlineSections() throws {
        let templateString = " {{^boolean}}NO{{/boolean}}\n {{^boolean}}WAY{{/boolean}}\n"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = " NO\n WAY\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Single-line sections should not alter surrounding whitespace.")
    }

    func testStandaloneLines() throws {
        let templateString = "| This Is\n{{^boolean}}\n|\n{{/boolean}}\n| A Line\n"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "| This Is\n|\n| A Line\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone lines should be removed from the template.")
    }

    func testStandaloneIndentedLines() throws {
        let templateString = "| This Is\n  {{^boolean}}\n|\n  {{/boolean}}\n| A Line\n"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "| This Is\n|\n| A Line\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone indented lines should be removed from the template.")
    }

    func testStandaloneLineEndings() throws {
        let templateString = "|\r\n{{^boolean}}\r\n{{/boolean}}\r\n|"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "|\r\n|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let templateString = "  {{^boolean}}\n^{{/boolean}}\n/"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "^\n/"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let templateString = "^{{^boolean}}\n/\n  {{/boolean}}"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "^\n/\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to follow them.")
    }

    func testPadding() throws {
        let templateString = "|{{^ boolean }}={{/ boolean }}|"
        let contextJSON = "{\"boolean\":false}".data(using: .utf8)!
        let expected = "|=|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }
}


/**
Comment tags represent content that should never appear in the resulting
output.

The tag's content may contain any substring (including newlines) EXCEPT the
closing delimiter.

Comment tags SHOULD be treated as standalone when appropriate.

 */
final class CommentsTests: XCTestCase {
    static var allTests: [(String, (CommentsTests) -> () throws -> Void)] {
        return [
            ("testInline", testInline),
            ("testMultiline", testMultiline),
            ("testStandalone", testStandalone),
            ("testIndentedStandalone", testIndentedStandalone),
            ("testStandaloneLineEndings", testStandaloneLineEndings),
            ("testStandaloneWithoutPreviousLine", testStandaloneWithoutPreviousLine),
            ("testStandaloneWithoutNewline", testStandaloneWithoutNewline),
            ("testMultilineStandalone", testMultilineStandalone),
            ("testIndentedMultilineStandalone", testIndentedMultilineStandalone),
            ("testIndentedInline", testIndentedInline),
            ("testSurroundingWhitespace", testSurroundingWhitespace),
        ]
    }

    func testInline() throws {
        let templateString = "12345{{! Comment Block! }}67890"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "1234567890"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Comment blocks should be removed from the template.")
    }

    func testMultiline() throws {
        let templateString = "12345{{!\n  This is a\n  multi-line comment...\n}}67890\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "1234567890\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Multiline comments should be permitted.")
    }

    func testStandalone() throws {
        let templateString = "Begin.\n{{! Comment Block! }}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All standalone comment lines should be removed.")
    }

    func testIndentedStandalone() throws {
        let templateString = "Begin.\n  {{! Indented Comment Block! }}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All standalone comment lines should be removed.")
    }

    func testStandaloneLineEndings() throws {
        let templateString = "|\r\n{{! Standalone Comment }}\r\n|"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "|\r\n|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let templateString = "  {{! I'm Still Standalone }}\n!"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "!"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let templateString = "!\n  {{! I'm Still Standalone }}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "!\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to follow them.")
    }

    func testMultilineStandalone() throws {
        let templateString = "Begin.\n{{!\nSomething's going on here...\n}}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All standalone comment lines should be removed.")
    }

    func testIndentedMultilineStandalone() throws {
        let templateString = "Begin.\n  {{!\n    Something's going on here...\n  }}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "All standalone comment lines should be removed.")
    }

    func testIndentedInline() throws {
        let templateString = "  12 {{! 34 }}\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "  12 \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Inline comments should not strip whitespace")
    }

    func testSurroundingWhitespace() throws {
        let templateString = "12345 {{! Comment Block! }} 67890"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "12345  67890"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Comment removal should preserve surrounding whitespace.")
    }
}


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
    static var allTests: [(String, (PartialsTests) -> () throws -> Void)] {
        return [
            ("testBasicBehavior", testBasicBehavior),
            ("testFailedLookup", testFailedLookup),
            ("testContext", testContext),
            ("testRecursion", testRecursion),
            ("testSurroundingWhitespace", testSurroundingWhitespace),
            ("testInlineIndentation", testInlineIndentation),
            ("testStandaloneLineEndings", testStandaloneLineEndings),
            ("testStandaloneWithoutPreviousLine", testStandaloneWithoutPreviousLine),
            ("testStandaloneWithoutNewline", testStandaloneWithoutNewline),
            ("testStandaloneIndentation", testStandaloneIndentation),
            ("testPaddingWhitespace", testPaddingWhitespace),
        ]
    }

    func testBasicBehavior() throws {
        let templateString = "\"{{>text}}\""
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "\"from partial\""
        let partials = try [
            "text": Template("from partial"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "The greater-than operator should expand to the named partial.")
    }

    func testFailedLookup() throws {
        let templateString = "\"{{>text}}\""
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "\"\""

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "The empty string should be used when the named partial is not found.")
    }

    func testContext() throws {
        let templateString = "\"{{>partial}}\""
        let contextJSON = "{\"text\":\"content\"}".data(using: .utf8)!
        let expected = "\"*content*\""
        let partials = try [
            "partial": Template("*{{text}}*"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "The greater-than operator should operate within the current context.")
    }

    func testRecursion() throws {
        let templateString = "{{>node}}"
        let contextJSON = "{\"content\":\"X\",\"nodes\":[{\"content\":\"Y\",\"nodes\":[]}]}".data(using: .utf8)!
        let expected = "X<Y<>>"
        let partials = try [
            "node": Template("{{content}}<{{#nodes}}{{>node}}{{/nodes}}>"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "The greater-than operator should properly recurse.")
    }

    func testSurroundingWhitespace() throws {
        let templateString = "| {{>partial}} |"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "| \t|\t |"
        let partials = try [
            "partial": Template("\t|\t"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "The greater-than operator should not alter surrounding whitespace.")
    }

    func testInlineIndentation() throws {
        let templateString = "  {{data}}  {{> partial}}\n"
        let contextJSON = "{\"data\":\"|\"}".data(using: .utf8)!
        let expected = "  |  >\n>\n"
        let partials = try [
            "partial": Template(">\n>"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Whitespace should be left untouched.")
    }

    func testStandaloneLineEndings() throws {
        let templateString = "|\r\n{{>partial}}\r\n|"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "|\r\n>|"
        let partials = try [
            "partial": Template(">"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let templateString = "  {{>partial}}\n>"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "  >\n  >>"
        let partials = try [
            "partial": Template(">\n>"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let templateString = ">\n  {{>partial}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = ">\n  >\n  >"
        let partials = try [
            "partial": Template(">\n>"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to follow them.")
    }

    func testStandaloneIndentation() throws {
        let templateString = "\\n {{>partial}}\n/\n"
        let contextJSON = "{\"content\":\"<\n->\"}".data(using: .utf8)!
        let expected = "\\n |\n <\n->\n |\n/\n"
        let partials = try [
            "partial": Template("|\n{{{content}}}\n|\n"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Each line of the partial should be indented before rendering.")
    }

    func testPaddingWhitespace() throws {
        let templateString = "|{{> partial }}|"
        let contextJSON = "{\"boolean\":true}".data(using: .utf8)!
        let expected = "|[]|"
        let partials = try [
            "partial": Template("[]"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }
}


/**
Set Delimiter tags are used to change the tag delimiters for all content
following the tag in the current compilation unit.

The tag's content MUST be any two non-whitespace sequences (separated by
whitespace) EXCEPT an equals sign ('=') followed by the current closing
delimiter.

Set Delimiter tags SHOULD be treated as standalone when appropriate.

 */
final class DelimitersTests: XCTestCase {
    static var allTests: [(String, (DelimitersTests) -> () throws -> Void)] {
        return [
            ("testPairBehavior", testPairBehavior),
            ("testSpecialCharacters", testSpecialCharacters),
            ("testSections", testSections),
            ("testInvertedSections", testInvertedSections),
            ("testPartialInheritence", testPartialInheritence),
            ("testPost_PartialBehavior", testPost_PartialBehavior),
            ("testSurroundingWhitespace", testSurroundingWhitespace),
            ("testOutlyingWhitespace_Inline", testOutlyingWhitespace_Inline),
            ("testStandaloneTag", testStandaloneTag),
            ("testIndentedStandaloneTag", testIndentedStandaloneTag),
            ("testStandaloneLineEndings", testStandaloneLineEndings),
            ("testStandaloneWithoutPreviousLine", testStandaloneWithoutPreviousLine),
            ("testStandaloneWithoutNewline", testStandaloneWithoutNewline),
            ("testPairwithPadding", testPairwithPadding),
        ]
    }

    func testPairBehavior() throws {
        let templateString = "{{=<% %>=}}(<%text%>)"
        let contextJSON = "{\"text\":\"Hey!\"}".data(using: .utf8)!
        let expected = "(Hey!)"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "The equals sign (used on both sides) should permit delimiter changes.")
    }

    func testSpecialCharacters() throws {
        let templateString = "({{=[ ]=}}[text])"
        let contextJSON = "{\"text\":\"It worked!\"}".data(using: .utf8)!
        let expected = "(It worked!)"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Characters with special meaning regexen should be valid delimiters.")
    }

    func testSections() throws {
        let templateString = "[\n{{#section}}\n  {{data}}\n  |data|\n{{/section}}\n\n{{= | | =}}\n|#section|\n  {{data}}\n  |data|\n|/section|\n]\n"
        let contextJSON = "{\"section\":true,\"data\":\"I got interpolated.\"}".data(using: .utf8)!
        let expected = "[\n  I got interpolated.\n  |data|\n\n  {{data}}\n  I got interpolated.\n]\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Delimiters set outside sections should persist.")
    }

    func testInvertedSections() throws {
        let templateString = "[\n{{^section}}\n  {{data}}\n  |data|\n{{/section}}\n\n{{= | | =}}\n|^section|\n  {{data}}\n  |data|\n|/section|\n]\n"
        let contextJSON = "{\"section\":false,\"data\":\"I got interpolated.\"}".data(using: .utf8)!
        let expected = "[\n  I got interpolated.\n  |data|\n\n  {{data}}\n  I got interpolated.\n]\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Delimiters set outside inverted sections should persist.")
    }

    func testPartialInheritence() throws {
        let templateString = "[ {{>include}} ]\n{{= | | =}}\n[ |>include| ]\n"
        let contextJSON = "{\"value\":\"yes\"}".data(using: .utf8)!
        let expected = "[ .yes. ]\n[ .yes. ]\n"
        let partials = try [
            "include": Template(".{{value}}."),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Delimiters set in a parent template should not affect a partial.")
    }

    func testPost_PartialBehavior() throws {
        let templateString = "[ {{>include}} ]\n[ .{{value}}.  .|value|. ]\n"
        let contextJSON = "{\"value\":\"yes\"}".data(using: .utf8)!
        let expected = "[ .yes.  .yes. ]\n[ .yes.  .|value|. ]\n"
        let partials = try [
            "include": Template(".{{value}}. {{= | | =}} .|value|."),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Delimiters set in a partial should not affect the parent template.")
    }

    func testSurroundingWhitespace() throws {
        let templateString = "| {{=@ @=}} |"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "|  |"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Surrounding whitespace should be left untouched.")
    }

    func testOutlyingWhitespace_Inline() throws {
        let templateString = " | {{=@ @=}}\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = " | \n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Whitespace should be left untouched.")
    }

    func testStandaloneTag() throws {
        let templateString = "Begin.\n{{=@ @=}}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone lines should be removed from the template.")
    }

    func testIndentedStandaloneTag() throws {
        let templateString = "Begin.\n  {{=@ @=}}\nEnd.\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Begin.\nEnd.\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Indented standalone lines should be removed from the template.")
    }

    func testStandaloneLineEndings() throws {
        let templateString = "|\r\n{{= @ @ =}}\r\n|"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "|\r\n|"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let templateString = "  {{=@ @=}}\n="
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "="

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let templateString = "=\n  {{=@ @=}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "=\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Standalone tags should not require a newline to follow them.")
    }

    func testPairwithPadding() throws {
        let templateString = "|{{= @   @ =}}|"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "||"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Superfluous in-tag whitespace should be ignored.")
    }
}


/**
Like partials, Parent tags are used to expand an external template into the
current template. Unlike partials, Parent tags may contain optional
arguments delimited by Block tags. For this reason, Parent tags may also be
referred to as Parametric Partials.

The Parent tags' content MUST be a non-whitespace character sequence NOT
containing the current closing delimiter; each Parent tag MUST be followed by
an End Section tag with the same content within the matching Parent tag.

This tag's content names the Parent template to inject. Set Delimiter tags
Preceding a Parent tag MUST NOT affect the parsing of the injected external
template. The Parent MUST be rendered against the context stack local to the
tag. If the named Parent cannot be found, the empty string SHOULD be used
instead, as in interpolations.

Parent tags SHOULD be treated as standalone when appropriate. If this tag is
used standalone, any whitespace preceding the tag should be treated as
indentation, and prepended to each line of the Parent before rendering.

The Block tags' content MUST be a non-whitespace character sequence NOT
containing the current closing delimiter. Each Block tag MUST be followed by
an End Section tag with the same content within the matching Block tag. This
tag's content determines the parameter or argument name.

Block tags may appear both inside and outside of Parent tags. In both cases,
they specify a position within the template that can be overridden; it is a
parameter of the containing template. The template text between the Block tag
and its matching End Section tag defines the default content to render when
the parameter is not overridden from outside.

In addition, when used inside of a Parent tag, the template text between a
Block tag and its matching End Section tag defines content that replaces the
default defined in the Parent template. This content is the argument passed
to the Parent template.

The practice of injecting an external template using a Parent tag is referred
to as inheritance. If the Parent tag includes a Block tag that overrides a
parameter of the Parent template, this may also be referred to as
substitution.

Parent templates are taken from the same namespace as regular Partial
templates and in fact, injecting a regular Partial is exactly equivalent to
injecting a Parent without making any substitutions. Parameter and arguments
names live in a namespace that is distinct from both Partials and the context.

 */
final class InheritanceTests: XCTestCase {
    static var allTests: [(String, (InheritanceTests) -> () throws -> Void)] {
        return [
            ("testDefault", testDefault),
            ("testVariable", testVariable),
            ("testTripleMustache", testTripleMustache),
            ("testSections", testSections),
            ("testNegativeSections", testNegativeSections),
            ("testMustacheInjection", testMustacheInjection),
            ("testInherit", testInherit),
            ("testOverriddencontent", testOverriddencontent),
            ("testDatadoesnotoverrideblock", testDatadoesnotoverrideblock),
            ("testDatadoesnotoverrideblockdefault", testDatadoesnotoverrideblockdefault),
            ("testOverriddenparent", testOverriddenparent),
            ("testTwooverriddenparents", testTwooverriddenparents),
            ("testOverrideparentwithnewlines", testOverrideparentwithnewlines),
            ("testInheritindentation", testInheritindentation),
            ("testOnlyoneoverride", testOnlyoneoverride),
            ("testParenttemplate", testParenttemplate),
            ("testRecursion", testRecursion),
            ("testMulti_levelinheritance", testMulti_levelinheritance),
            ("testMulti_levelinheritance_nosubchild", testMulti_levelinheritance_nosubchild),
            ("testTextinsideparent", testTextinsideparent),
            ("testTextinsideparent2", testTextinsideparent2),
        ]
    }

    func testDefault() throws {
        let templateString = "{{$title}}Default title{{/title}}\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "Default title\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Default content should be rendered if the block isn't overridden")
    }

    func testVariable() throws {
        let templateString = "{{$foo}}default {{bar}} content{{/foo}}\n"
        let contextJSON = "{\"bar\":\"baz\"}".data(using: .utf8)!
        let expected = "default baz content\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Default content renders variables")
    }

    func testTripleMustache() throws {
        let templateString = "{{$foo}}default {{{bar}}} content{{/foo}}\n"
        let contextJSON = "{\"bar\":\"<baz>\"}".data(using: .utf8)!
        let expected = "default <baz> content\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Default content renders triple mustache variables")
    }

    func testSections() throws {
        let templateString = "{{$foo}}default {{#bar}}{{baz}}{{/bar}} content{{/foo}}\n"
        let contextJSON = "{\"bar\":{\"baz\":\"qux\"}}".data(using: .utf8)!
        let expected = "default qux content\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Default content renders sections")
    }

    func testNegativeSections() throws {
        let templateString = "{{$foo}}default {{^bar}}{{baz}}{{/bar}} content{{/foo}}\n"
        let contextJSON = "{\"baz\":\"three\"}".data(using: .utf8)!
        let expected = "default three content\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Default content renders negative sections")
    }

    func testMustacheInjection() throws {
        let templateString = "{{$foo}}default {{#bar}}{{baz}}{{/bar}} content{{/foo}}\n"
        let contextJSON = "{\"bar\":{\"baz\":\"{{qux}}\"}}".data(using: .utf8)!
        let expected = "default {{qux}} content\n"

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context)

        XCTAssertEqual(rendered, expected, "Mustache injection in default content")
    }

    func testInherit() throws {
        let templateString = "{{<include}}{{/include}}\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "default content"
        let partials = try [
            "include": Template("{{$foo}}default content{{/foo}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Default content rendered inside inherited templates")
    }

    func testOverriddencontent() throws {
        let templateString = "{{<super}}{{$title}}sub template title{{/title}}{{/super}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "...sub template title..."
        let partials = try [
            "super": Template("...{{$title}}Default title{{/title}}..."),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Overridden content")
    }

    func testDatadoesnotoverrideblock() throws {
        let templateString = "{{<include}}{{$var}}var in template{{/var}}{{/include}}"
        let contextJSON = "{\"var\":\"var in data\"}".data(using: .utf8)!
        let expected = "var in template"
        let partials = try [
            "include": Template("{{$var}}var in include{{/var}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Context does not override argument passed into parent")
    }

    func testDatadoesnotoverrideblockdefault() throws {
        let templateString = "{{<include}}{{/include}}"
        let contextJSON = "{\"var\":\"var in data\"}".data(using: .utf8)!
        let expected = "var in include"
        let partials = try [
            "include": Template("{{$var}}var in include{{/var}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Context does not override default content of block")
    }

    func testOverriddenparent() throws {
        let templateString = "test {{<parent}}{{$stuff}}override{{/stuff}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "test override"
        let partials = try [
            "parent": Template("{{$stuff}}...{{/stuff}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Overridden parent")
    }

    func testTwooverriddenparents() throws {
        let templateString = "test {{<parent}}{{$stuff}}override1{{/stuff}}{{/parent}} {{<parent}}{{$stuff}}override2{{/stuff}}{{/parent}}\n"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "test |override1 default| |override2 default|\n"
        let partials = try [
            "parent": Template("|{{$stuff}}...{{/stuff}}{{$default}} default{{/default}}|"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Two overridden parents with different content")
    }

    func testOverrideparentwithnewlines() throws {
        let templateString = "{{<parent}}{{$ballmer}}\npeaked\n\n:(\n{{/ballmer}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "peaked\n\n:(\n"
        let partials = try [
            "parent": Template("{{$ballmer}}peaking{{/ballmer}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Override parent with newlines")
    }

    func testInheritindentation() throws {
        let templateString = "{{<parent}}{{$nineties}}hammer time{{/nineties}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "stop:\n  hammer time\n"
        let partials = try [
            "parent": Template("stop:\n  {{$nineties}}collaborate and listen{{/nineties}}\n"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Inherit indentation when overriding a parent")
    }

    func testOnlyoneoverride() throws {
        let templateString = "{{<parent}}{{$stuff2}}override two{{/stuff2}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "new default one, override two"
        let partials = try [
            "parent": Template("{{$stuff}}new default one{{/stuff}}, {{$stuff2}}new default two{{/stuff2}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Override one parameter but not the other")
    }

    func testParenttemplate() throws {
        let templateString = "{{>parent}}|{{<parent}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "default content|default content"
        let partials = try [
            "parent": Template("{{$foo}}default content{{/foo}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Parent templates behave identically to partials when called with no parameters")
    }

    func testRecursion() throws {
        let templateString = "{{<parent}}{{$foo}}override{{/foo}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "override override override don't recurse"
        let partials = try [
            "parent2": Template("{{$foo}}parent2 default content{{/foo}} {{<parent}}{{$bar}}don't recurse{{/bar}}{{/parent}}"),
            "parent": Template("{{$foo}}default content{{/foo}} {{$bar}}{{<parent2}}{{/parent2}}{{/bar}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Recursion in inherited templates")
    }

    func testMulti_levelinheritance() throws {
        let templateString = "{{<parent}}{{$a}}c{{/a}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "c"
        let partials = try [
            "grandParent": Template("{{$a}}g{{/a}}"),
            "older": Template("{{<grandParent}}{{$a}}o{{/a}}{{/grandParent}}"),
            "parent": Template("{{<older}}{{$a}}p{{/a}}{{/older}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Top-level substitutions take precedence in multi-level inheritance")
    }

    func testMulti_levelinheritance_nosubchild() throws {
        let templateString = "{{<parent}}{{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "p"
        let partials = try [
            "grandParent": Template("{{$a}}g{{/a}}"),
            "older": Template("{{<grandParent}}{{$a}}o{{/a}}{{/grandParent}}"),
            "parent": Template("{{<older}}{{$a}}p{{/a}}{{/older}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Top-level substitutions take precedence in multi-level inheritance")
    }

    func testTextinsideparent() throws {
        let templateString = "{{<parent}} asdfasd {{$foo}}hmm{{/foo}} asdfasdfasdf {{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "hmm"
        let partials = try [
            "parent": Template("{{$foo}}default content{{/foo}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Ignores text inside parent templates, but does parse $ tags")
    }

    func testTextinsideparent2() throws {
        let templateString = "{{<parent}} asdfasd asdfasdfasdf {{/parent}}"
        let contextJSON = "{}".data(using: .utf8)!
        let expected = "default content"
        let partials = try [
            "parent": Template("{{$foo}}default content{{/foo}}"),
        ]

        let context = try JSONDecoder().decode(Context.self, from: contextJSON)
        let template = try Template(templateString)
        let rendered = template.render(with: context, partials: partials)

        XCTAssertEqual(rendered, expected, "Allows text inside a parent tag, but ignores it")
    }
}

