// Stage 2 - Comile tokens into an AST

public typealias AST = [ASTNode]
public enum ASTNode: Equatable {
    case text(String)
    case variable(String, escaped: Bool)
    case section(variable: String, ast: AST)
    case invertedSection(variable: String, ast: AST)
    case partial(identifier: String, indentation: String)
    case override(identifier: String, ast: AST)
    case block(identifier: String, ast: AST)
}

public func ==(lhs: ASTNode, rhs: ASTNode) -> Bool {
    switch (lhs, rhs) {
    case let (.text(la), .text(ra)): return la == ra
    case let (.variable(la, lb), .variable(ra, rb)): return la == ra && lb == rb
    case let (.partial(la, lb), .partial(ra, rb)): return la == ra && lb == rb
    case let (.section(la, lb), .section(ra, rb)): return la == ra && lb == rb
    case let (.invertedSection(la, lb), .invertedSection(ra, rb)): return la == ra && lb == rb
    case let (.override(la, lb), .override(ra, rb)): return la == ra && lb == rb
    case let (.block(la, lb), .block(ra, rb)): return la == ra && lb == rb
    default: return false
    }
}

public enum CompilerError: Error {
    case expectingToken(token: Token)
    case badSectionIdentifier(got: String, expected: String)
}

public final class Compiler {
    private let tokens: [Token]

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public func compile() throws -> AST {
        var index = 0
        return try compile(index: &index)
    }

    private func compile(index: inout Int, openToken: Token? = nil) throws -> AST {
        var ast = AST()

        while let token = tokens.element(at: index) {
            index += 1

            switch token {
            case .comment:
                continue

            case let .text(text):
                ast.append(.text(text))

            case let .variable(variable):
                ast.append(.variable(variable, escaped: true))
            case let .unescapedVariable(variable):
                ast.append(.variable(variable, escaped: false))

            case let .partial(identifier, indentation):
                ast.append(.partial(identifier: identifier, indentation: indentation))

            // nested section, recurse
            case let .openSection(variable):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.section(variable: variable, ast: innerAST))

            case let .openInvertedSection(variable):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.invertedSection(variable: variable, ast: innerAST))

            case let .openBlockSection(identifier: idenitifer):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.block(identifier: idenitifer, ast: innerAST))

            case let .openOverrideSection(identifier: identifier):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.override(identifier: identifier, ast: innerAST))

            // close sections return early, and are used
            // to end recursion started by open sections
            case let .closeSection(variable):
                guard let openToken = openToken else {
                    // if it hits this, that means it was not preceded by an opensection token
                    throw CompilerError.expectingToken(token: .openSection(variable: variable))
                }

                switch openToken {
                case let .openSection(variable: openVariable),
                     let .openInvertedSection(variable: openVariable),
                     let .openBlockSection(identifier: openVariable),
                     let .openOverrideSection(identifier: openVariable):
                    guard openVariable == variable else {
                        throw CompilerError.badSectionIdentifier(got: variable, expected: openVariable)
                    }
                    return ast

                default:
                    throw CompilerError.expectingToken(token: .openSection(variable: variable))
                }
            }
        }

        return ast
    }
}
