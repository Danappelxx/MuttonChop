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
    default: return false
    }
}

struct ParserError: Error {
    enum Reason {
        case missingEndOfToken
        case unexpectedToken
    }
    let reader: Reader<Character>
    let reason: Reason
    init(reader: Reader<Character>, reason: Reason) {
        self.reader = reader
        self.reason = reason
        fatalError(String(describing: reason))
    }
}

protocol Parser {
    static func matches(peeker: Peeker<Character>) -> Bool
    static func parse(reader: Reader<Character>) throws -> Token
}

let parsers: [Parser.Type] = [ExpressionParser.self, TextParser.self]

public func parseOne(reader: Reader<Character>) throws -> Token {
    for parser in parsers where parser.matches(peeker: reader) {
        return try parser.parse(reader: reader)
    }
    fatalError("TextParser should always pick it up, worst case scenario")
}

public func parse(reader: Reader<Character>) throws -> [Token] {
    var tokens = [Token]()

    while !reader.done {
        try tokens.append(parseOne(reader: reader))
    }

    return tokens
}

struct TextParser: Parser {
    static func matches(peeker: Peeker<Character>) -> Bool {
        return true
    }
    static func parse(reader: Reader<Character>) throws -> Token {
        let text = reader.pop(upTo: ["{", "{"], discarding: false)!
        return .text(String(text))
    }
}

// all expressions start with {{
struct ExpressionParser: Parser {
    // order matters
    static let parsers: [Parser.Type] = [
        OpenSectionParser.self,
        OpenInvertedSectionParser.self,
        CloseSectionParser.self,
        CommentParser.self,
        VariableParser.self,
    ]

    static func matches(peeker: Peeker<Character>) -> Bool {
        return peeker.peek(2) == ["{", "{"]
    }

    static func parse(reader: Reader<Character>) throws -> Token {
        // remove the leading braces
        precondition(reader.pop(2) == ["{", "{"])
        reader.consume(using: String.whitespaceAndNewLineCharacterSet)

        for parser in parsers where parser.matches(peeker: reader) {
            return try parser.parse(reader: reader)
        }

        throw ParserError(reader: reader, reason: .unexpectedToken)
    }

    struct CommentParser: Parser {
        static func matches(peeker: Peeker<Character>) -> Bool {
            return peeker.peek() == "!"
        }
        static func parse(reader: Reader<Character>) throws -> Token {
            precondition(reader.pop() == "!")

            guard let _ = reader.pop(upTo: ["}", "}"]) else {
                throw ParserError(reader: reader, reason: .missingEndOfToken)
            }

            // closing braces
            precondition(reader.pop(2) == ["}", "}"])

            return .comment
        }
    }

    struct VariableParser: Parser {
        static func matches(peeker: Peeker<Character>) -> Bool {
            return true
        }
        static func parse(reader: Reader<Character>) throws -> Token {

            guard let variable = reader.pop(upTo: ["}", "}"]) else {
                throw ParserError(reader: reader, reason: .missingEndOfToken)
            }

            // closing braces
            precondition(reader.pop(2) == ["}", "}"])

            return .variable(String(variable).trim(using: String.whitespaceAndNewLineCharacterSet))
        }
    }

    struct CloseSectionParser: Parser {
        static func matches(peeker: Peeker<Character>) -> Bool {
            return peeker.peek() == "/"
        }
        static func parse(reader: Reader<Character>) throws -> Token {
            precondition(reader.pop() == "/")

            guard let variable = reader.pop(upTo: ["}", "}"]) else {
                throw ParserError(reader: reader, reason: .missingEndOfToken)
            }

            // closing braces
            precondition(reader.pop(2) == ["}", "}"])

            // pop trailing newline (if any)
            // (by specification)
            reader.consume(using: String.newLineCharacterSet, upTo: 1)

            return .closeSection(variable: String(variable).trim(using: String.whitespaceAndNewLineCharacterSet))
        }
    }

    struct OpenSectionParser: Parser {
        static func matches(peeker: Peeker<Character>) -> Bool {
            return peeker.peek() == "#"
        }
        static func parse(reader: Reader<Character>) throws -> Token {
            precondition(reader.pop() == "#")

            guard let variable = reader.pop(upTo: ["}", "}"]) else {
                throw ParserError(reader: reader, reason: .missingEndOfToken)
            }

            // closing braces
            precondition(reader.pop(2) == ["}", "}"])

            // pop trailing newline (if any)
            // (by specification)
            reader.consume(using: String.newLineCharacterSet, upTo: 1)

            return .openSection(variable: String(variable).trim(using: String.whitespaceAndNewLineCharacterSet))
        }
    }

    struct OpenInvertedSectionParser: Parser {
        static func matches(peeker: Peeker<Character>) -> Bool {
            return peeker.peek() == "^"
        }
        static func parse(reader: Reader<Character>) throws -> Token {
            precondition(reader.pop() == "^")

            guard let variable = reader.pop(upTo: ["}", "}"]) else {
                throw ParserError(reader: reader, reason: .missingEndOfToken)
            }

            // closing braces
            precondition(reader.pop(2) == ["}", "}"])

            // pop trailing newline (if any)
            // (by specification)
            reader.consume(using: String.newLineCharacterSet, upTo: 1)

            return .openInvertedSection(variable: String(variable).trim(using: String.whitespaceAndNewLineCharacterSet))

        }
    }
}
