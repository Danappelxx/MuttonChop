import Foundation
import MuttonChop

struct Test: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case description = "desc"
        case partials
        case context = "data"
        case template
        case expected
    }

    let name: String
    let description: String
    let partials: [String:String]?
    let contextJSON: String
    let template: String
    let expected: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "(", with: "_")
            .replacingOccurrences(of: ")", with: "")

        description = try container.decode(String.self, forKey: .description)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")

        partials = try container.decodeIfPresent([String:String].self, forKey: .partials)?
            .mapValues { $0
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\n", with: "\\n") }

        let context = try container.decode(Context.self, forKey: .context)
        contextJSON = try String(data: JSONEncoder().encode(context), encoding: .utf8)!
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\\\\\"", with: "\\\\\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        template = try container.decode(String.self, forKey: .template)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")

        expected = try container.decode(String.self, forKey: .expected)
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

let testSuiteTemplateString = """
    /**
    {{&overview}}
     */
    final class {{suite}}Tests: XCTestCase {
    {{&allTests}}
    {{#tests}}

    {{&.}}
    {{/tests}}
    }
    """

let allTestsTemplateString = """
        static var allTests: [(String, ({{suite}}Tests) -> () throws -> Void)] {
            return [
            {{#tests}}
                ("test{{.}}", test{{.}}),
            {{/tests}}
            ]
        }
    """

let testCaseTemplateString = """
        {{={| |}=}}
        func test{|name|}() throws {
            let templateString = "{|&template|}"
            let contextJSON = "{|&contextJSON|}".data(using: .utf8)!
            let expected = "{|&expected|}"
            {|#hasPartials|}
            let partials = try [
            {|#partials|}
                "{|name|}": Template("{|&value|}"),
            {|/partials|}
            ]
            {|/hasPartials|}

            let context = try JSONDecoder().decode(Context.self, from: contextJSON)
            let template = try Template(templateString)
            {|#hasPartials|}
            let rendered = template.render(with: context, partials: partials)
            {|/hasPartials|}
            {|^hasPartials|}
            let rendered = template.render(with: context)
            {|/hasPartials|}

            XCTAssertEqual(rendered, expected, "{|&description|}")
        }
    """

let testSuiteTemplate = try Template(testSuiteTemplateString)
let allTestsTemplate = try Template(allTestsTemplateString)
let testCaseTemplate = try Template(testCaseTemplateString)

struct TestSuite: Decodable {
    let overview: String
    let tests: [Test]
}

func generateTestSuite(_ suite: String) throws -> String {

    let path = URL(fileURLWithPath: "Resources/spec/\(suite).json")
    let data = try Data(contentsOf: path)

    let testSuite = try JSONDecoder().decode(TestSuite.self, from: data)

    let testCases = testSuite.tests.map(generateTestCase)

    let allTests = allTestsTemplate.render(with: [
        "suite": .string(suite),
        "tests": .array(testSuite.tests.map { .string($0.name) })
    ])

    return testSuiteTemplate.render(with: [
        "overview": .string(testSuite.overview),
        "suite": .string(suite),
        "allTests": .string(allTests),
        "tests": .array(testCases.map { .string($0) })
    ])
}

func generateTestCase(test: Test) -> String {
    let partials: [String:String] = test.partials ?? [:]
    return testCaseTemplate.render(with: [
        "name": .string(test.name),
        "contextJSON": .string(test.contextJSON),
        "expected": .string(test.expected),
        "hasPartials": .bool(!partials.isEmpty),
        "partials": .array(partials.map { .dictionary(["name": .string($0.0), "value": .string($0.1)])}),
        "description": .string(test.description),
        "template": .string(test.template)
    ])
}

let suites = ["Sections", "Interpolation", "Inverted", "Comments", "Partials", "Delimiters", "Inheritance"]
print("import XCTest")
print("import MuttonChop")
print("")
for suite in suites {
    let suite = try generateTestSuite(suite)
    print()
    print(suite)
    print()
}
