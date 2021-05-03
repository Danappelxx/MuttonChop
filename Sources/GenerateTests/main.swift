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

struct TestSuite: Decodable {
    let overview: String
    let tests: [Test]
}

func generateTestSuite(_ suite: String) throws -> String {

    let path = URL(fileURLWithPath: "Resources/spec/\(suite).json")
    let data = try Data(contentsOf: path)

    let testSuite = try JSONDecoder().decode(TestSuite.self, from: data)

    let testCases = testSuite.tests.map(generateTestCase)

    let allTests = [
        "    static var allTests: [(String, (\(suite)Tests) -> () throws -> Void)] {",
        "        return [",
        (testSuite.tests.map { test in
        "            (\"test\(test.name)\", test\(test.name)),"
        }.joined(separator: "\n")),
        "        ]",
        "    }"
    ].joined(separator: "\n")

    return [
        "/**",
        "\(testSuite.overview)",
        " */",
        "final class \(suite)Tests: XCTestCase {",
        allTests,
        "",
        testCases.joined(separator: "\n\n"),
        "}",
    ].joined(separator: "\n")
}

func generateTestCase(test: Test) -> String {
    return [
        "    func test\(test.name)() throws {",
        "        let templateString = \"\(test.template)\"",
        "        let contextJSON = \"\(test.contextJSON)\".data(using: .utf8)!",
        "        let expected = \"\(test.expected)\"",
        (test.partials?.isEmpty ?? true
            ? ""
            : "        let partials = try [\n" + test.partials!.map { key, value in
              "            \"\(key)\": Template(\"\(value)\")"
                }.joined(separator: ",\n") + "\n        ]\n"
        ),
        "        let context = try JSONDecoder().decode(Context.self, from: contextJSON)",
        "        let template = try Template(templateString)",
        (test.partials?.isEmpty ?? true
            ? "        let rendered = template.render(with: context)"
            : "        let rendered = template.render(with: context, partials: partials)"),
        "",
        "        XCTAssertEqual(rendered, expected, \"\(test.description)\")",
        "    }",
    ].joined(separator: "\n")
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
