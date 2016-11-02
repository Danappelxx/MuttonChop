/**
 Glue between the individual components of MuttonChop. Boils down to
 ```
 String
  -> Reader
   -> Parser.parse
    -> Compiler.compile
 + Renderer.render
 ```

 - note: Create as few templates as possible, reuse them as much as possible.
 Parsing is slow and unoptimized, rendering is fast and optimized.
 */
public struct Template {
    public let ast: AST

    /**
     Creates a template, directly storing the AST. There is no parsing, compiling,
     or rendering done here.
     */
    public init(_ ast: AST) {
        self.ast = ast
    }

    /**
     Creates a template from the parsed tokens by compiling the tokens into
     an AST and delegating to the init(ast:) initializer.

     - parameter tokens: The tokens that are going to be compiled.
     */
    public init(_ tokens: [Token]) throws {
        try self.init(Compiler(tokens: tokens).compile())
    }

    /**
     Creates a template from the string reader, first parsing the template
     into tokens, and then compiling those tokens into an AST.

     - parameter reader: The reader for the template string.
     */
    public init(_ reader: Reader) throws {
        try self.init(Parser(reader: reader).parse())
    }

    /**
     Creates a template from the string, first parsing the template
     into tokens, and then compiling those tokens into an AST.

     - parameter reader: The reader for the template string.
     */
    public init(_ string: String) throws {
        try self.init(Reader(string))
    }

    /**
     Renders the template with the given context and partials.

     - parameter context: The data that will be used as context for the template.

     - parameter partials: The templates that will be used as partials for partial
     inclusion and inheritance.

     - note: The type `Context` is a typealias to `StructuredData`.

     - returns: The rendered template as a string.
     */
    public func render(with context: Context = .array([]), partials: [String:Template] = [:]) -> String {
        return Renderer(ast: ast, partials: partials.mapValues { $0.ast }).render(with: context)
    }
}

extension Template: Equatable {}
public func ==(lhs: Template, rhs: Template) -> Bool {
    return lhs.ast == rhs.ast
}
