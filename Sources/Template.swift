public struct Template {
    public let ast: AST

    public init(_ ast: AST) {
        self.ast = ast
    }
    public init(_ tokens: [Token], with templates: [String:Template] = [:]) throws {
        try self.init(compile(tokens: tokens, with: templates.mapValues { $0.ast }))
    }
    public init(_ reader: Reader, with templates: [String:Template] = [:]) throws {
        try self.init(Parser(reader: reader).parse(), with: templates)
    }
    public init(_ string: String, with templates: [String:Template] = [:]) throws {
        try self.init(Reader(string), with: templates)
    }

    public func render(with context: Context = .null) -> String {
        return MuttonChop.render(ast: ast, context: context)
    }
}
