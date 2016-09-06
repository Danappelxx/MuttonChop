//
//  ParserTests.swift
//  MuttonChopTests
//
//  Created by Dan Appel on 8/27/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import MuttonChop

class ParserTests: XCTestCase {

    //MARK: multi-token tests
    func testSectionParsing() throws {
        // heavy whitespace to test robustness
        let string = "{{ #\nlocation }} {{  \n\t\r\n  location  \r\n\t\n  }} {{ \t/  location   }}"
        let reader = Reader(string)
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
        let reader = Reader(string)
        let token = try Parser(reader: reader).parseText()
        XCTAssertEqual(token, .text(string))
    }

    func testVariableParser() throws {
        let string = "{{ location }}"
        let reader = Reader(string)
        let token = try Parser(reader: reader).parseExpression()
        XCTAssertEqual(token, .variable("location"))
    }

    func testOpenSectionParser() throws {
        let string = "{{# location }}"
        let reader = Reader(string)
        let token = try Parser(reader: reader).parseExpression()
        XCTAssertEqual(token, .openSection(variable: "location"))
    }

    func testOpenInvertedSectionParser() throws {
        let string = "{{^ location }}"
        let reader = Reader(string)
        let token = try Parser(reader: reader).parseExpression()
        XCTAssertEqual(token, .openInvertedSection(variable: "location"))
    }

    func testCloseSectionParser() throws {
        let string = "{{/ location }}"
        let reader = Reader(string)
        let token = try Parser(reader: reader).parseExpression()
        XCTAssertEqual(token, .closeSection(variable: "location"))
    }
}
