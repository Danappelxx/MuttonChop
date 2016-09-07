// stage 2 parsing
public typealias AST = [ASTNode]
public enum ASTNode: Equatable {
    case text(String)
    case variable(String, escaped: Bool)
    case partial(ast: AST)
    case section(variable: String, inverted: Bool, ast: AST)
}

public func ==(lhs: ASTNode, rhs: ASTNode) -> Bool {
    switch (lhs, rhs) {
    case let (.text(l), .text(r)): return l == r
    case let (.variable(l), .variable(r)): return l == r
    case let (.section(la, lb, lc), .section(ra, rb, rc)): return la == ra && lb == rb && lc == rc
    default: return false
    }
}

public enum CompilerError: Error {
    case expectingToken(token: Token)
    case badSectionIdentifier(got: String, expected: String)
}

public func compile(tokens: [Token], partials: [String:AST] = [:]) throws -> AST {
    var index = 0
    return try compile(tokens: tokens, index: &index, partials: partials)
}

public func compile(tokens: [Token], index: inout Int, partials: [String:AST] = [:], openToken: Token? = nil) throws -> AST {
    var ast = AST()
    while let token = tokens.element(at: index) {
        defer { index += 1 }
        switch token {
        case .comment:
            break

        case let .text(text):
            ast.append(.text(text))

        case let .variable(variable):
            ast.append(.variable(variable, escaped: true))
        case let .unescapedVariable(variable):
            ast.append(.variable(variable, escaped: false))

        case let .partial(partial, indentation):
            guard let partial = partials[partial] else {
                break
            }
            let indented = partial.map { node -> ASTNode in
                guard case let .text(text) = node else {
                    return node
                }

                return .text(text.characters.split(separator: "\n", omittingEmptySubsequences: false).map(String.init(_:)).map { indentation + $0 }.joined(separator: "\n"))
            }
            ast.append(.partial(ast: indented))

        // nested section, recurse
        case .openSection, .openInvertedSection:
            index += 1
            try ast.append(contentsOf: compile(tokens: tokens, index: &index, partials: partials, openToken: token))
            index -= 1

        case let .closeSection(variable):

            // if it hits this, that means it was not preceded by an opensection token
            guard let openToken = openToken else {
                throw CompilerError.expectingToken(token: .openSection(variable: variable))
            }

            // finished section - make sure it has the same contents
            switch openToken {

            case let .openSection(openVariable),
                 let .openInvertedSection(openVariable):
                guard openVariable == variable else {
                    throw CompilerError.badSectionIdentifier(got: variable, expected: openVariable)
                }
                return [.section(variable: openVariable, inverted: openToken == .openInvertedSection(variable: openVariable), ast: ast)]

            // TODO: handle properly
            default: fatalError()
            }
        }
    }

    return ast
}
