//
//  CommentTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/31/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

/**
Comment tags represent content that should never appear in the resulting
output.

The tag's content may contain any substring (including newlines) EXCEPT the
closing delimiter.

Comment tags SHOULD be treated as standalone when appropriate.

 */
final class CommentsTests: XCTestCase {
    func testInline() throws {
        let template = "12345{{! Comment Block! }}67890"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "1234567890", "Comment blocks should be removed from the template.")
    }

    func testMultiline() throws {
        let template = "12345{{!\n  This is a\n  multi-line comment...\n}}67890\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "1234567890\n", "Multiline comments should be permitted.")
    }

    func testStandalone() throws {
        let template = "Begin.\n{{! Comment Block! }}\nEnd.\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Begin.\nEnd.\n", "All standalone comment lines should be removed.")
    }

    func testIndentedStandalone() throws {
        let template = "Begin.\n  {{! Indented Comment Block! }}\nEnd.\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Begin.\nEnd.\n", "All standalone comment lines should be removed.")
    }

    func testStandaloneLineEndings() throws {
        let template = "|\r\n{{! Standalone Comment }}\r\n|"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "|\r\n|", "\"\r\n\" should be considered a newline for standalone tags.")
    }

    func testStandaloneWithoutPreviousLine() throws {
        let template = "  {{! I'm Still Standalone }}\n!"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "!", "Standalone tags should not require a newline to precede them.")
    }

    func testStandaloneWithoutNewline() throws {
        let template = "!\n  {{! I'm Still Standalone }}"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "!\n", "Standalone tags should not require a newline to follow them.")
    }

    func testMultilineStandalone() throws {
        let template = "Begin.\n{{!\nSomething's going on here...\n}}\nEnd.\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Begin.\nEnd.\n", "All standalone comment lines should be removed.")
    }

    func testIndentedMultilineStandalone() throws {
        let template = "Begin.\n  {{!\n    Something's going on here...\n  }}\nEnd.\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "Begin.\nEnd.\n", "All standalone comment lines should be removed.")
    }

    func testIndentedInline() throws {
        let template = "  12 {{! 34 }}\n"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "  12 \n", "Inline comments should not strip whitespace")
    }

    func testSurroundingWhitespace() throws {
        let template = "12345 {{! Comment Block! }} 67890"
        let contextJSONString = "{}"
        let contextJSON = try JSONSerialization.jsonObject(with: contextJSONString.data(using: String.Encoding.utf8)!, options: [])
        let context = Context(from: contextJSON)

        let ast = try compile(tokens: AnyIterator(parse(reader: Reader(template)).makeIterator()))
        let rendered = render(ast: ast, context: context)

        XCTAssertEqual(rendered, "12345  67890", "Comment removal should preserve surrounding whitespace.")
    }
}
