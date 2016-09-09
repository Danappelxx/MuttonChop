// Stage 2 - Comile tokens into an AST

public typealias AST = [ASTNode]
public enum ASTNode: Equatable {
    case text(String)
    case variable(String, escaped: Bool)
    case partial(ast: AST)
    case section(variable: String, ast: AST)
    case invertedSection(variable: String, ast: AST)
    case override(identifier: String, ast: AST)
}

public func ==(lhs: ASTNode, rhs: ASTNode) -> Bool {
    switch (lhs, rhs) {
    case let (.text(la), .text(ra)): return la == ra
    case let (.variable(la, lb), .variable(ra, rb)): return la == ra && lb == rb
    case let (.partial(la), .partial(ra)): return la == ra
    case let (.section(la, lb), .section(ra, rb)): return la == ra && lb == rb
    case let (.invertedSection(la, lb), .invertedSection(ra, rb)): return la == ra && lb == rb
    case let (.override(la, lb), .override(ra, rb)): return la == ra && lb == rb
    default: return false
    }
}

public enum CompilerError: Error {
    case expectingToken(token: Token)
    case badSectionIdentifier(got: String, expected: String)
}

public final class Compiler {
    private let tokens: [Token]
    private let templates: [String:AST]

    public init(tokens: [Token], templates: [String:AST] = [:]) {
        self.tokens = tokens
        self.templates = templates
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

            case let .partial(partial, indentation):
                guard let partial = templates[partial] else {
                    continue
                }
                ast.append(.partial(ast: indent(partial: partial, with: indentation)))

            // nested section, recurse
            case let .openSection(variable):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.section(variable: variable, ast: innerAST))

            case let .openInvertedSection(variable):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.invertedSection(variable: variable, ast: innerAST))

            case let .openOverrideSection(identifier: idenitifer):
                let innerAST = try compile(index: &index, openToken: token)
                ast.append(.override(identifier: idenitifer, ast: innerAST))

            case let .openParentSection(identifier: identifier):
                let innerAST = try compile(index: &index, openToken: token)

                // if we can't find what we're trying to override, ignore it
                guard let overriding = templates[identifier] else {
                    continue
                }

                ast.append(contentsOf: override(overriding, with: innerAST))

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
                     let .openOverrideSection(identifier: openVariable),
                     let .openParentSection(identifier: openVariable):
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

fileprivate extension Compiler {
    func override(_ inherited: AST, with ast: AST) -> AST {
        // for every inherited node, search for a matching node in the ast. 
        // if found, replace inherited node with matching node
        return inherited.map { inherited in
            // we don't mess with anything but override nodes
            guard case let .override(identifier: overridingIdentifier, ast: _) = inherited else {
                return inherited
            }

            // search for nodes with a matching identifier
            for node in ast {
                guard case let .override(identifier: identifier, ast: _) = node, identifier == overridingIdentifier else {
                    continue
                }
                // we found a matching node! it replaces the inherited one
                return node
            }

            return inherited
        }
    }

    // TODO: Fix this... it's breaking a single test case and I don't know why
    func indent(partial: AST, with indentation: String) -> AST {
        return partial.map { node in
            guard case let .text(text) = node else {
                return node
            }

            return .text(text.characters.split(separator: "\n", omittingEmptySubsequences: false).map(String.init(_:)).map { indentation + $0 }.joined(separator: "\n"))
        }
    }
}
