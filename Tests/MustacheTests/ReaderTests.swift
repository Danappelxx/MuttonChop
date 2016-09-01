//
//  ReaderTests.swift
//  Mustache
//
//  Created by Dan Appel on 8/30/16.
//  Copyright © 2016 dvappel. All rights reserved.
//

import XCTest
@testable import Mustache

class ReaderTests: XCTestCase {
    func testPeekingPopping() {
        let string = "Hello, world!"
        let reader = string.reader()
        XCTAssertEqual(reader.peek(), "H")
        XCTAssertEqual(reader.peek(3), ["H", "e", "l"])
        XCTAssertEqual(reader.pop(), "H")
        XCTAssertEqual(reader.pop(3), ["e", "l", "l"])
        guard let popped = reader.pop(upTo: ["o", "r"]) else {
            return XCTFail("pop(upTo:) returned nil")
        }
        XCTAssertEqual(popped, ["o", ",", " ", "w"])
    }
    
//    func testTest() {
////        try! print(generateTestSuites()[0])
//        try! print(generateTestSuites()[1])
//        try! print(generateTestSuites()[2])
//        try! print(generateTestSuites()[3])
//        
//    }

    func testWhitespace() {
        let string = "H   e   ll\to\n\n\t \t\n!"
        let reader = string.reader()
        XCTAssertEqual(reader.pop(), "H")
        XCTAssertEqual(reader.pop(), " ")
        reader.consume(using: String.whitespaceAndNewLineCharacterSet)
        XCTAssertEqual(reader.pop(), "e")
        XCTAssertEqual(reader.peek(2),  [" ", " "])
        reader.consume(using: String.whitespaceAndNewLineCharacterSet)
        XCTAssertEqual(reader.pop(2), ["l", "l"])
        XCTAssertEqual(reader.peek(), "\t")
        reader.consume(using: String.whitespaceAndNewLineCharacterSet)
        XCTAssertEqual(reader.pop(), "o")
        XCTAssertEqual(reader.peek(), "\n")
        reader.consume(using: String.whitespaceAndNewLineCharacterSet, upTo: 3)
        XCTAssertEqual(reader.peek(2), [" ", "\t"])
        reader.consume(using: String.whitespaceAndNewLineCharacterSet)
        XCTAssertEqual(reader.pop(), "!")
        XCTAssertNil(reader.peek())
    }
}
