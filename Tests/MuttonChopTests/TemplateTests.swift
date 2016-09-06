//
//  TemplateTests.swift
//  MuttonChop
//
//  Created by Dan Appel on 9/5/16.
//
//

import XCTest
@testable import MuttonChop

class TemplateTests: XCTestCase {
    func testPipeline() throws {
        let partials = [
            "greeting": try Template("Hello, {{name}}")
        ]
        let string = "And then I said \"{{>greeting}}\"!"
        let context = Context.dictionary(["name":.string("Dan")])

        let template = try Template(string, partials: partials)
        let rendered = template.render(context: context)
        XCTAssertEqual(rendered, "And then I said \"Hello, Dan\"!")
    }

    //MARK: Error handling
    func testSyntaxError() {
        let string = "Hello, \n {{location"

        do {
            _ = try Template(string)
            XCTFail("Should throw")
        } catch let error as SyntaxError {
            XCTAssertEqual(error.reason, .missingEndOfToken)
            XCTAssertEqual(error.line, 2)
            XCTAssertEqual(error.column, 11)
        } catch {
            XCTFail("Should throw a SyntaxError, not a \(error)")
        }
    }
    func testBadSectionIdentifier() {
        let string = "Hello, {{#open}}{{var}}{{/close}}"

        do {
            _ = try Template(string)
            XCTFail("Should throw")
        } catch CompilerError.badSectionIdentifier(got: "close", expected: "open") {
            XCTAssert(true)
        } catch {
            XCTFail("Should throw a CompilerError.badSectionIdentifier, not a \(error)")
        }
    }
    func testCompilerError() {
        let string = "Hello, {{#location}}{{var}}"

        do {
            _ = try Template(string)
        } catch CompilerError.expectingToken(token: Token.closeSection(variable: "location")) {
            XCTAssert(true)
        } catch {
            XCTFail("Should throw a CompilerError.expectingToken, not a \(error)")
        }
    }
}
