//
//  TemplateCollectionTests.swift
//  MuttonChop
//
//  Created by Dan Appel on 11/1/16.
//
//

import XCTest
import Foundation
@testable import MuttonChop

var currentDirectory: String {
    return (NSString(string: #file)).deletingLastPathComponent + "/"
}

func fixture(name: String) throws -> Template? {
    let path = currentDirectory + "Fixtures/" + name
    guard let handle = FileHandle(forReadingAtPath: path),
        let fixture = String(data: handle.readDataToEndOfFile(), encoding: .utf8) else {
            return nil
    }
    return try Template(fixture)
}

class TemplateCollectionTests: XCTestCase {
    static var allTests: [(String, (TemplateCollectionTests) -> () throws -> Void)] {
        return [
            ("testBasicCollection", testBasicCollection),
            ("testFileCollection", testFileCollection)
        ]
    }

    func testBasicCollection() throws {
        let collection = try TemplateCollection(templates: [
            "conversation": fixture(name: "conversation.mustache")!,
            "greeting": fixture(name: "greeting.mustache")!
        ])

        try testGetting(for: collection)
        try testRendering(for: collection)
    }

    func testFileCollection() throws {
        let collection = try TemplateCollection(basePath: currentDirectory, directory: "Fixtures")

        try testGetting(for: collection)
        try testRendering(for: collection)
    }

    func testGetting(for collection: TemplateCollection) throws {
        try XCTAssertEqual(collection.get(template: "conversation"), fixture(name: "conversation.mustache")!)
        try XCTAssertEqual(collection.get(template: "greeting"), fixture(name: "greeting.mustache"))
    }

    func testRendering(for collection: TemplateCollection) throws {
        try XCTAssertEqual("Hey there, Dan!", collection.render(template: "greeting", with: ["your-name": "Dan"]))
        try XCTAssertEqual("Hey there, Dan! My name is Billy.", collection.render(template: "conversation", with: ["your-name": "Dan", "my-name": "Billy"]))
    }
}
