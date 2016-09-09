/**
 Glue between the individual components of MuttonChop. Boils down to
 ```
 String
  -> Reader
   -> Parser.parse
    -> Compiler.compile
 + MuttonChop.render
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

     - parameter templates: The templates which are going to be used as context
     while compiling (partials, inheritance, etc.).
     */
    public init(_ tokens: [Token], with templates: [String:Template] = [:]) throws {
        try self.init(Compiler(tokens: tokens, templates: templates.mapValues { $0.ast }).compile())
    }

    /**
     Creates a template from the string reader, first parsing the template
     into tokens, and then compiling those tokens into an AST.

     - parameter reader: The reader for the template string.

     - parameter templates: The templates which are going to be used as context
     while compiling (partials, inheritance, etc.).
     */
    public init(_ reader: Reader, with templates: [String:Template] = [:]) throws {
        try self.init(Parser(reader: reader).parse(), with: templates)
    }

    /**
     Creates a template from the string, first parsing the template
     into tokens, and then compiling those tokens into an AST.

     - parameter reader: The reader for the template string.

     - parameter templates: The templates which are going to be used as context
     while compiling (partials, inheritance, etc.).
     */
    public init(_ string: String, with templates: [String:Template] = [:]) throws {
        try self.init(Reader(string), with: templates)
    }

    /**
     Renders the template with the given context.

     - parameter context: The data that will be used as context for the template.

     - note: The type `Context` is a typealias to `StructuredData`.

     - throws: Nothing! The advantage of compiling ahead of time :).

     - returns: The rendered template as a string.
     */
    public func render(with context: Context = .null) -> String {
        return MuttonChop.render(ast: ast, context: context)
    }
}
