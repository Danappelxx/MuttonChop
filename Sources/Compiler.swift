// stage 2 parsing
// tokens [open, text, variable, text, close]
// -> ast [section([text, variable, text])]

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
}

public func compileSection(reader: Reader<Token>, variable: String, inverted: Bool) throws -> ASTNode {
    var ast = AST()

    while let token = reader.pop() {
        switch token {

        // nested section, recurse
        case let .openSection(variable):
            try ast.append(compileSection(reader: reader, variable: variable, inverted: false))
        case let .openInvertedSection(variable):
            try ast.append(compileSection(reader: reader, variable: variable, inverted: true))

        // finished section - make sure it has the same contents
        case let .closeSection(closeVariable):
            precondition(closeVariable == variable)
            switch inverted {
            case true: return .invertedSection(variable: variable, ast: ast)
            case false: return .section(variable: variable, ast: ast)
            }

        //TODO: find a way to get rid of this duplication
        case let .text(text):
            ast.append(.text(text))
        case let .variable(variable):
            ast.append(.variable(variable))
        case .comment:
            continue
        }
    }

    throw CompilerError.expectingToken(token: .closeSection(variable: variable))
}

public func compile(reader: Reader<Token>) throws -> AST {
    return try reader.flatMap { token in

        switch token {

        case let .text(text):
            return .text(text)

        case let .variable(variable):
            return .variable(variable)

        case let .openSection(variable):
            return try compileSection(reader: reader, variable: variable, inverted: false)
        case let .openInvertedSection(variable):
            return try compileSection(reader: reader, variable: variable, inverted: true)

        // if it hits this, that means it was not preceded by an opensection token
        case let .closeSection(variable):
            throw CompilerError.expectingToken(token: .openSection(variable: variable))

        case .comment:
            return nil
        }
    }
}
