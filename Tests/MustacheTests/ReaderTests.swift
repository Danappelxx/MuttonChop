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
        let reader = Reader(string)
        XCTAssertEqual(reader.peek(), "H")
        XCTAssertEqual(reader.peek(3), ["H", "e", "l"])
        XCTAssertEqual(reader.pop(), "H")
        XCTAssertEqual(reader.pop(3), ["e", "l", "l"])
        XCTAssertEqual(reader.backPeek(3), ["e", "l", "l"])
        guard let popped = reader.pop(upTo: ["o", "r"]) else {
            return XCTFail("pop(upTo:) returned nil")
        }
        XCTAssertEqual(popped, ["o", ",", " ", "w"])
    }

    func testPeekingPoppingIgnoring() {
        let string = "Hello, world!"
        let reader = Reader(string)
        XCTAssertEqual(reader.peek(3, ignoring: ["l", "o"]), ["H", "e", ","])
        XCTAssertEqual(reader.peek(3, ignoring: ["l", "o"]), ["H", "e", ","])
        XCTAssertEqual(reader.pop(4, ignoring: ["l", "o"]), ["H", "e", ",", " "])
        XCTAssertEqual(reader.pop(3, ignoring: ["w", "r"]), ["o", "l", "d"])
    }

    func testWhitespace() {
        let string = "H   e   ll\to\n\n\t \t\n!"
        let reader = Reader(string)
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
