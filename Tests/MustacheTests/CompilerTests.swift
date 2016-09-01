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
        let ast = try compile(reader: tokens.reader())

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
