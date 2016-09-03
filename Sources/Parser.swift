// stage 1 parsing
// {{# variable }} {{ variable }} {{/ variable }}
// -> tokens [open, text, variable, text, close]
public enum Token: Equatable {
    case text(String)

    // expressions
    case comment
    // {{ variable }}
    case variable(String)
    // {{# variable }}
    case openSection(variable: String)
    // {{^ variable }}
    case openInvertedSection(variable: String)
    // {{/ variable }}
    case closeSection(variable: String)
}

public func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case let (.text(l), .text(r)): return l == r
    case let (.variable(l), .variable(r)): return l == r
    case let (.openSection(l), .openSection(r)): return l == r
    case let (.closeSection(l), .closeSection(r)): return l == r
    case let (.openInvertedSection(l), .openInvertedSection(r)): return l == r
    default: return false
    }
}

struct ParserError: Error {
    enum Reason {
        case missingEndOfToken
        case unexpectedToken
    }
    let reader: Reader
    let reason: Reason
    init(reader: Reader, reason: Reason) {
        self.reader = reader
        self.reason = reason
        fatalError(String(describing: reason))
    }
}

protocol Parser {
    static func matches(peeker: Peeker) -> Bool
    static func parse(reader: Reader) throws -> Token
}

let parsers: [Parser.Type] = [
    ExpressionParser.self,
    TextParser.self
]

public func parseOne(reader: Reader) throws -> Token {
    for parser in parsers where parser.matches(peeker: reader) {
        return try parser.parse(reader: reader)
    }
    // text parser should always pick it up
    fatalError()
}

public func parse(reader: Reader) throws -> [Token] {
    var tokens = [Token]()

    while !reader.done {
        try tokens.append(parseOne(reader: reader))
    }

    return tokens
}

struct TextParser: Parser {
    static func matches(peeker: Peeker) -> Bool {
        return true
    }
    static func parse(reader: Reader) throws -> Token {
        let text = reader.pop(upTo: ["{", "{"], discarding: false)!
        return .text(String(text))
    }
}

struct ExpressionParser: Parser {
    static func matches(peeker: Peeker) -> Bool {
        return peeker.peek(2) == ["{", "{"]
    }
    static func parse(reader: Reader) throws -> Token {
        precondition(reader.pop(2) == ["{", "{"])

        reader.consume(using: String.whitespaceAndNewLineCharacterSet)

        guard
            let char = reader.pop(),
            let content = reader.pop(upTo: ["}", "}"])
            else {
            throw ParserError(reader: reader, reason: .missingEndOfToken)
        }

        // closing braces
        precondition(reader.pop(2) == ["}", "}"])

        switch char {
        // comment
        case "!":
            return .comment

        // open section
        case "#":
            return .openSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // open inverted section
        case "^":
            return .openInvertedSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // close section
        case "/":
            return .closeSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        default:
            return .variable(String([char] + content).trim(using: String.whitespaceAndNewLineCharacterSet))
        }
    }
}
