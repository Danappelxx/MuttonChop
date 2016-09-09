// Stage 1 - Break down string into tokens

public enum Token: Equatable {
    // some text
    case text(String)
    // {{ variable }}
    case variable(String)
    // {{{ variable }}}
    case unescapedVariable(String)
    // {{! comment }}
    case comment
    // {{> partial }}
    case partial(String, indentation: String)
    // {{# variable }}
    case openSection(variable: String)
    // {{^ variable }}
    case openInvertedSection(variable: String)
    // {{$ identifier }}
    case openOverrideSection(identifier: String)
    // {{< identifier }}
    case openParentSection(identifier: String)
    // {{/ variable }}
    case closeSection(variable: String)
}

public func ==(lhs: Token, rhs: Token) -> Bool {
    switch (lhs, rhs) {
    case (.comment, .comment): return true
    case let (.text(la),.text(ra)): return la == ra
    case let (.variable(la),.variable(ra)): return la == ra
    case let (.unescapedVariable(la),.unescapedVariable(ra)): return la == ra
    case let (.partial(la, lb),.partial(ra, rb)): return la == ra && lb == rb
    case let (.openSection(la),.openSection(ra)): return la == ra
    case let (.openInvertedSection(la),.openInvertedSection(ra)): return la == ra
    case let (.openOverrideSection(la),.openOverrideSection(ra)): return la == ra
    case let (.openParentSection(la),.openParentSection(ra)): return la == ra
    case let (.closeSection(la),.closeSection(ra)): return la == ra
    default: return false
    }
}

public struct SyntaxError: Error {
    public enum Reason {
        case missingEndOfToken
    }

    public let line: Int
    public let column: Int
    public let reason: Reason

    init(reader: Reader, reason: Reason) {
        self.line = reader.line
        self.column = reader.column
        self.reason = reason
    }
}

public final class Parser {
    fileprivate var tokens = [Token]()
    fileprivate let reader: Reader

    public var delimiters: (open: [Character], close: [Character]) = (["{", "{"], ["}", "}"])
    public init(reader: Reader) {
        self.reader = reader
    }

    public func parse() throws -> [Token] {
        while !reader.done {
            if reader.peek(delimiters.open.count) == delimiters.open {
                try tokens.append(parseExpression())
                continue
            }

            try tokens.append(parseText())
        }

        return tokens
    }

    internal func parseText() throws -> Token {
        let text = reader.pop(upTo: delimiters.open, discarding: false)!
        return .text(String(text))
    }

    internal func parseExpression() throws -> Token {
        // whitespace up to newline before the tag
        // nil = not only whitespace
        let leading = reader.leadingWhitespace()

        // opening braces
        precondition(reader.pop(delimiters.open.count) == delimiters.open)

        // skip whitespace inside tag
        reader.pop(matching: String.whitespaceAndNewLineCharacterSet)

        // char = token type (first non-whitespace character after opening braces)
        // content = everything after the token
        guard
            let char = reader.pop(),
            let content = reader.pop(upTo: delimiters.close)
            else {
                throw SyntaxError(reader: reader, reason: .missingEndOfToken)
        }

        // closing braces
        precondition(reader.pop(delimiters.close.count) == delimiters.close)

        // whitespace up to newline after the tag
        // nil = not only whitespace
        let trailing = reader.trailingWhitespace()

        // trimmed = content with whitespace trimmed off
        // made a computed property so that it is lazy
        var trimmed: String { return String(content).trim(using: String.whitespaceAndNewLineCharacterSet) }

        // if the tag is standalone, remove all leading and trailing whitespace
        let stripIfStandalone = { self.stripIfStandalone(leading: leading, trailing: trailing) }

        // char = token type (first non-whitespace character after opening braces)
        switch char {

        // change delimiter:
        case "=":
            defer { stripIfStandalone() }

            self.delimiters = try parseDelimiters(tagContents: content)

            // maybe it would be better to return optional?
            // either way, this works for now
            return .comment

        // comment
        case "!":
            defer { stripIfStandalone() }
            return .comment

        // open section
        case "#":
            defer { stripIfStandalone() }
            return .openSection(variable: trimmed)

        // open inverted section
        case "^":
            defer { stripIfStandalone() }
            return .openInvertedSection(variable: trimmed)

        // open inherit section
        case "$":
            defer { stripIfStandalone() }
            return .openOverrideSection(identifier: trimmed)

        // open overwrite section
        case "<":
            defer { stripIfStandalone() }
            return .openParentSection(identifier: trimmed)

        // close section
        case "/":
            defer { stripIfStandalone() }
            return .closeSection(variable: trimmed)

        // partial
        case ">":
            defer { stripIfStandalone() }
            let indentation = leading.map(String.init(_:)) ?? ""
            return .partial(trimmed, indentation: indentation)

        // unescaped variable
        case "{":
            // pop the third brace
            guard reader.pop() == "}" else {
                throw SyntaxError(reader: reader, reason: .missingEndOfToken)
            }
            return .unescapedVariable(trimmed)

        // unescaped variable
        case "&":
            return .unescapedVariable(trimmed)

        // escaped variable
        default:
            return .variable(String([char] + content).trim(using: String.whitespaceAndNewLineCharacterSet))

        }
    }
}

fileprivate extension Parser {
    // a standalone tag is one which has only whitespace on both sides until a newlien
    func stripIfStandalone(leading: [Character]?, trailing: [Character]?) {
        // if just whitespace until newline on both sides, tag is standalone
        guard let _ = leading, let trailing = trailing else {
            return
        }

        // get rid of trailing whitespace
        reader.pop(trailing.count)
        // get rid of newline
        reader.pop(matching: String.newLineCharacterSet, upTo: 1)

        // get the token before it (should be text)
        if case let .text(prev)? = tokens.last {
            // get rid of trailing whitespace on that token
            let newText = prev.trimRight(using: String.whitespaceCharacterSet)
            // put it back in
            tokens[tokens.endIndex - 1] = .text(newText)
        }
    }

    func parseDelimiters(tagContents: [Character]) throws -> (open: [Character], close: [Character]) {
        // make a reader for the contents of the tag (code reuse FTW)
        let reader = Reader(AnyIterator(tagContents.makeIterator()))

        // strip any whitespace before the open delimiter
        reader.pop(matching: String.whitespaceCharacterSet)

        guard
            // open delimiter ends upon whitespace
            let open = reader.pop(upTo: " "),
            // close delimiter ends upon =
            // also strip any whitespace before/afterwards
            let close = reader.pop(upTo: "=")?.filter({!String.whitespaceCharacterSet.contains($0)})
            else {
            throw SyntaxError(reader: reader, reason: .missingEndOfToken)
        }

        return (open: open, close: close)
    }
}
