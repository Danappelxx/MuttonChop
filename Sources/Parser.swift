// stage 1 parsing
public enum Token: Equatable {
    // some text
    case text(String)
    // {{ variable }}
    case variable(String)
    // {{! comment }}
    case comment
    // {{# variable }}
    case openSection(variable: String)
    // {{^ variable }}
    case openInvertedSection(variable: String)
    // {{/ variable }}
    case closeSection(variable: String)
    // {{> partial }}
    case partial(String)
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

enum ParseError: Error {
    case missingEndOfToken
}

public func parse(reader: Reader) throws -> [Token] {
    var tokens = [Token]()

    while !reader.done {
        if reader.peek(2) == ["{", "{"] {
            try tokens.append(parseExpression(reader: reader))
            continue
        }

        try tokens.append(parseText(reader: reader))
    }

    return tokens
}

func parseText(reader: Reader) throws -> Token {
    let text = reader.pop(upTo: ["{", "{"], discarding: false)!
    return .text(String(text))
}

func parseExpression(reader: Reader) throws -> Token {
    precondition(reader.pop(2) == ["{", "{"])

    reader.consume(using: String.whitespaceAndNewLineCharacterSet)

    guard
        let char = reader.pop(),
        let content = reader.pop(upTo: ["}", "}"])
        else {
            throw ParseError.missingEndOfToken
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

    // partial
    case ">":
        return .partial(String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

    default:
        return .variable(String([char] + content).trim(using: String.whitespaceAndNewLineCharacterSet))
    }
}
