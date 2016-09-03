// stage 2 parsing
public typealias AST = [ASTNode]
public enum ASTNode: Equatable {
    case text(String)
    case variable(String)
    case invertedSection(variable: String, ast: AST)
    case section(variable: String, ast: AST)
}

public func ==(lhs: ASTNode, rhs: ASTNode) -> Bool {
    switch (lhs, rhs) {
    case let (.text(l), .text(r)): return l == r
    case let (.variable(l), .variable(r)): return l == r
    case let (.section(lv, li), .section(rv, ri)): return lv == rv && li == ri
    default: return false
    }
}

public enum CompilerError: Error {
    case expectingToken(token: Token)
    case badSectionIdentifier(got: String, expected: String)
}

public func compile(tokens: AnyIterator<Token>, openToken: Token? = nil) throws -> AST {
    var ast = AST()

    while let token = tokens.next() {
        switch token {
        case .comment:
            break

        case let .text(text):
            ast.append(.text(text))

        case let .variable(variable):
            ast.append(.variable(variable))

        // nested section, recurse
        case .openSection:
            try ast.append(contentsOf: compile(tokens: tokens, openToken: token))
        case .openInvertedSection:
            try ast.append(contentsOf: compile(tokens: tokens, openToken: token))

        case let .closeSection(variable):

            // if it hits this, that means it was not preceded by an opensection token
            guard let openToken = openToken else {
                throw CompilerError.expectingToken(token: .openSection(variable: variable))
            }

            // finished section - make sure it has the same contents
            switch openToken {

            case let .openSection(openVariable):
                guard openVariable == variable else {
                    throw CompilerError.badSectionIdentifier(got: variable, expected: openVariable)
                }
                return [.section(variable: openVariable, ast: ast)]

            case let .openInvertedSection(openVariable):
                guard openVariable == variable else {
                    throw CompilerError.badSectionIdentifier(got: variable, expected: openVariable)
                }
                return [.invertedSection(variable: openVariable, ast: ast)]

            default: fatalError()
            }
        }
    }

    return ast
}
