//
//  CompilerTests.swift
//  MuttonChopTests
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import MuttonChop

class CompilerTests: XCTestCase {
    func testWhitespace() throws {
        let template = "* one\n* two\n  {{#three}}\n* {{three}}\n{{/three}}a"
        let context = Context.dictionary(["three": .string("three")])
        let tokens = try Parser(reader: Reader(template)).parse()
        let ast = try compile(tokens: tokens)
        let rendered = render(ast: ast, context: context)
        XCTAssertEqual(rendered, "* one\n* two\n* three\na")
    }

    func testCompilingSections() throws {
        // equivalent to "Hello, {{# location }} {{ location }} {{/ location }}!"
        let tokens: [Token] = [
            .text("Hello, "),
            .openSection(variable: "location"),
            .text(" "),
            .variable("location"),
            .text(" "),
            .closeSection(variable: "location"),
            .text("!")
        ]
        let ast = try compile(tokens: tokens)

        XCTAssertEqual(ast.count, 3)
        XCTAssertEqual(ast[0], .text("Hello, "))
        XCTAssertEqual(ast[1], .section(variable: "location", inverted: false, ast: [
            .text(" "),
            .variable("location", escaped: true),
            .text(" "),
        ]))
        XCTAssertEqual(ast[2], .text("!"))
    }
}
