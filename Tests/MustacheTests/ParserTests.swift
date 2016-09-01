//
//  ParserTests.swift
//  MustacheTests
//
//  Created by Dan Appel on 8/27/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

class ParserTests: XCTestCase {

    //MARK: multi-token tests
    func testSectionParsing() throws {
        // heavy whitespace to test robustness
        let string = "{{ #\nlocation }} {{  \n\t\r\n  location  \r\n\t\n  }} {{ \t/  location   }}"
        let reader = string.reader()
        let tokens = try parse(reader: reader)
        XCTAssertEqual(tokens.count, 5)
        XCTAssertEqual(tokens[0], .openSection(variable: "location"))
        XCTAssertEqual(tokens[1], .text(" "))
        XCTAssertEqual(tokens[2], .variable("location"))
        XCTAssertEqual(tokens[3], .text(" "))
        XCTAssertEqual(tokens[4], .closeSection(variable: "location"))
    }

    //MARK: single-token tests
    func testTextParser() throws {
        let string = "Hello, world!"
        let reader = string.reader()
        let token = try TextParser.parse(reader: reader)
        XCTAssertEqual(token, .text(string))
    }

    func testVariableParser() throws {
        let string = "{{ location }}"
        let reader = string.reader()
        let token = try ExpressionParser.parse(reader: reader)
        XCTAssertEqual(token, .variable("location"))
    }

    func testOpenSectionParser() throws {
        let string = "{{# location }}"
        let reader = string.reader()
        let token = try ExpressionParser.parse(reader: reader)
        XCTAssertEqual(token, .openSection(variable: "location"))
    }

    func testCloseSectionParser() throws {
        let string = "{{/ location }}"
        let reader = string.reader()
        let token = try ExpressionParser.parse(reader: reader)
        XCTAssertEqual(token, .closeSection(variable: "location"))
    }
}
