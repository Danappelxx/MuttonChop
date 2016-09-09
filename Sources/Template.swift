public struct Template {
    public let ast: AST

    public init(_ ast: AST) {
        self.ast = ast
    }
    public init(_ tokens: [Token], with templates: [String:Template] = [:]) throws {
        try self.init(Compiler(tokens: tokens, templates: templates.mapValues { $0.ast }).compile())
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
