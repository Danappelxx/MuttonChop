// stage 1 parsing
public enum Token: Equatable {
    // some text
    case text(String)
    // {{ variable }}
    case variable(String)
    // {{{ variable }}}
    case unescapedVariable(String)
    // {{! comment }}
    case comment
    // {{# variable }}
    case openSection(variable: String)
    // {{^ variable }}
    case openInvertedSection(variable: String)
    // {{/ variable }}
    case closeSection(variable: String)
    // {{> partial }}
    case partial(String, indentation: String)
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

public struct SyntaxError: Error {
    let line: Int
    let column: Int
    let reason: Reason

    init(reader: Reader, reason: Reason) {
        self.line = reader.line
        self.column = reader.column
        self.reason = reason
    }
}

public enum Reason: Error {
    case missingEndOfToken
}

final class Parser {
    private var tokens = [Token]()
    private let reader: Reader

    init(reader: Reader) {
        self.reader = reader
    }

    public func parse() throws -> [Token] {
        do {

            while !reader.done {
                if reader.peek(2) == ["{", "{"] {
                    try tokens.append(parseExpression())
                    continue
                }

                try tokens.append(parseText())
            }

            return tokens

        } catch let reason as Reason {
            throw SyntaxError(reader: reader, reason: reason)
        }
    }

    func parseText() throws -> Token {
        let text = reader.pop(upTo: ["{", "{"], discarding: false)!
        return .text(String(text))
    }

    func parseExpression() throws -> Token {
        // whitespace up to newline before the tag
        // nil = not only whitespace
        let leading = reader.leadingWhitespace()

        // opening braces
        precondition(reader.pop(2) == ["{", "{"])

        reader.consume(using: String.whitespaceAndNewLineCharacterSet)

        // char = token type
        guard
            let char = reader.pop(),
            let content = reader.pop(upTo: ["}", "}"])
            else {
                throw Reason.missingEndOfToken
        }

        // closing braces
        precondition(reader.pop(2) == ["}", "}"])

        // whitespace up to newline after the tag
        // nil = not only whitespace
        let trailing = reader.trailingWhitespace()

        func stripIfStandalone() {
            // if just whitespace until newline on both sides, tag is standalone
            guard let _ = leading, let trailing = trailing else {
                return
            }

            // get rid of trailing whitespace
            reader.pop(trailing.count)
            // get rid of newline
            reader.consume(using: String.newLineCharacterSet, upTo: 1)

            // get the token before it (should be text)
            if case let .text(prev)? = tokens.last {
                // get rid of trailing whitespace on that token
                let newText = prev.trimRight(using: String.whitespaceCharacterSet)
                // put it back in
                tokens[tokens.endIndex - 1] = .text(newText)
            }
        }

        switch char {

        // comment
        case "!":
            defer { stripIfStandalone() }
            return .comment

        // open section
        case "#":
            defer { stripIfStandalone() }
            return .openSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // open inverted section
        case "^":
            defer { stripIfStandalone() }
            return .openInvertedSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // close section
        case "/":
            defer { stripIfStandalone() }
            return .closeSection(variable: String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // partial
        case ">":
            defer { stripIfStandalone() }
            let indentation = leading.map(String.init(_:)) ?? ""
            return .partial(String(content).trim(using: String.whitespaceAndNewLineCharacterSet), indentation: indentation)

        // unescaped variable
        case "{":
            // pop the third brace
            guard reader.pop() == "}" else {
                throw Reason.missingEndOfToken
            }
            return .unescapedVariable(String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // unescaped variable
        case "&":
            return .unescapedVariable(String(content).trim(using: String.whitespaceAndNewLineCharacterSet))

        // normal variable
        default:
            return .variable(String([char] + content).trim(using: String.whitespaceAndNewLineCharacterSet))
        }
    }
}

public func parse(reader: Reader) throws -> [Token] {
    return try Parser(reader: reader).parse()
}
