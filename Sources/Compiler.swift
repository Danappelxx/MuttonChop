// stage 2 parsing
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
    case let (.text(l), .text(r)): return l == r
    case let (.variable(l), .variable(r)): return l == r
    case let (.section(la, lb), .section(ra, rb)): return la == ra && lb == rb
    default: return false
    }
}

public enum CompilerError: Error {
    case expectingToken(token: Token)
    case badSectionIdentifier(got: String, expected: String)
}

public func compile(tokens: [Token], with templates: [String:AST] = [:]) throws -> AST {
    var index = 0
    return try compile(tokens: tokens, index: &index, templates: templates)
}

public func compile(tokens: [Token], index: inout Int, templates: [String:AST] = [:], openToken: Token? = nil) throws -> AST {
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
            guard let partial = templates[partial] else {
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
        case let .openSection(variable):
            index += 1; defer { index -= 1 }

            let innerAST = try compile(tokens: tokens, index: &index, templates: templates, openToken: token)
            ast.append(.section(variable: variable, ast: innerAST))

        case let .openInvertedSection(variable):
            index += 1; defer { index -= 1 }

            let innerAST = try compile(tokens: tokens, index: &index, templates: templates, openToken: token)
            ast.append(.invertedSection(variable: variable, ast: innerAST))

        case let .openOverrideSection(identifier: idenitifer):
            index += 1; defer { index -= 1 }

            let innerAST = try compile(tokens: tokens, index: &index, templates: templates, openToken: token)
            ast.append(.override(identifier: idenitifer, ast: innerAST))

        case let .openParentSection(identifier: identifier):
            index += 1; defer { index -= 1 }

            let innerAST = try compile(tokens: tokens, index: &index, templates: templates, openToken: token)

            // if we can't find what we're trying to override, ignore it
            guard let overriding = templates[identifier] else {
                continue
            }

            // for every inherited node, search for a matching node here. if found,
            // replace inherited ast for that node with overriden ast
            let overriden: AST = overriding.map { node in
                // we don't mess with anything but override nodes
                guard case let .override(identifier: overridingIdentifier, ast: _) = node else {
                    return node
                }

                // search for nodes with a matching identifier
                for node in innerAST {
                    guard case let .override(identifier: identifier, ast: _) = node, identifier == overridingIdentifier else {
                        continue
                    }
                    // we found a matching node! it replaces the inherited one
                    return node
                }

                return node
            }

            ast.append(contentsOf: overriden)

        case let .closeSection(variable):

            // TODO: also handle misnamed token
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

            default:
                throw CompilerError.expectingToken(token: .openSection(variable: variable))
            }

            return ast
        }
    }

    return ast
}
