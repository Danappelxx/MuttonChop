public struct Template {
    public let ast: AST

    public init(_ ast: AST) {
        self.ast = ast
    }
    public init(_ tokens: [Token], partials: [String:Template] = [:]) throws {
        try self.init(compile(tokens: tokens, partials: partials.mapValues { $0.ast }))
    }
    public init(_ reader: Reader, partials: [String:Template] = [:]) throws {
        try self.init(Parser(reader: reader).parse(), partials: partials)
    }
    public init(_ string: String, partials: [String:Template] = [:]) throws {
        try self.init(Reader(string), partials: partials)
    }

    public func render(with context: Context) -> String {
        return MuttonChop.render(ast: ast, context: context)
    }
}
