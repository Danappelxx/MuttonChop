//
//  CompilerTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

class CompilerTests: XCTestCase {
//    func testWhitespace1() throws {
//        let template = "* one\n* two\n  {{#three}}\n* {{three}}\n{{/three}}a"
//        let context = Context.dictionary(["three": .string("three")])
//        let tokens = try parse(reader: Reader(template))
//        let ast = try compile(tokens: tokens)
//        let rendered = render(ast: ast, context: context)
//        XCTAssertEqual(rendered, "* one\n* two\n* three\na")
//    }
    func testWhitespace2() throws {
        let template = "* one\n* two\n  {{#three}}  \n* {{three}}\n{{/three}}a"
        let context = Context.dictionary(["three": .string("three")])
        let tokens = try parse(reader: Reader(template))
        let ast = try compile(tokens: AnyIterator(tokens.makeIterator()))
        let rendered = render(ast: ast, context: context)
        XCTAssertEqual(rendered, "* one\n* two\n    \n* three\na")
    }

    func testCompiling() throws {
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
        let ast = try compile(tokens: AnyIterator(tokens.makeIterator()))

        XCTAssertEqual(ast.count, 3)
        XCTAssertEqual(ast[0], .text("Hello, "))
        XCTAssertEqual(ast[1], .section(variable: "location", ast: [
            .text(" "),
            .variable("location"),
            .text(" "),
        ]))
        XCTAssertEqual(ast[2], .text("!"))
    }
}