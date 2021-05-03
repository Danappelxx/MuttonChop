// Stage 3 - Render AST to string

fileprivate struct RenderingContext {
    let contextStack: [Context]
    let overrideStack: [(identifier: String, ast: AST)]

    func extended(by context: Context) -> RenderingContext {
        return RenderingContext(contextStack: [context] + contextStack, overrideStack: overrideStack)
    }

    func extended(by override: (identifier: String, ast: AST)) -> RenderingContext {
        return RenderingContext(contextStack: contextStack, overrideStack: [override] + overrideStack)
    }
}

fileprivate extension Context {
    var stringyValue: String? {
        switch self {

        case let .string(value): return value
        case let .int(value): return String(value)
        case let .double(value): return String(value)

        case let .array(values):
            var out = ""
            for value in values {
                guard let string = value.stringyValue else {
                    return nil
                }
                out += string
            }
            return out

        default: return nil
        }
    }
    var truthyValue: Bool {
        switch self {
        case let .bool(bool):
            return bool
        case let .array(array):
            return !array.isEmpty
        case let .dictionary(dictionary):
            return !dictionary.isEmpty
        case .null:
            return false
        default:
            return true
        }
    }
}

extension RenderingContext {
    func value(of variable: String) -> Context? {
        return contextStack.value(of: variable)
    }
}

extension Sequence where Iterator.Element == Context {
    // TODO: clean this up
    func value(of variable: String) -> Context? {
        let components = variable.split(separator: ".").map({ String($0) })

        switch components.count {
        case 1:
            if variable == "." {
                return self.first(where: { _ in true })
            }
            for context in self {
                if
                    case let .dictionary(dictionary) = context,
                    let value = dictionary[variable] {
                    return value
                }
            }
            return nil

        default:
            // TODO: do this more efficiently (not create an array every lookup)
            var stack = Array(self)
            for component in components {
                guard let value = stack.value(of: component) else {
                    return nil
                }
                stack = [value]
            }
            return stack.first
        }
    }
}

public final class Renderer {
    fileprivate let ast: AST
    fileprivate let partials: [String:AST]

    public init(ast: AST, partials: [String:AST] = [:]) {
        self.ast = ast
        self.partials = partials
    }

    public func render(with context: Context) -> String {
        let context = RenderingContext(contextStack: [context], overrideStack: [])
        return render(ast: ast, with: context)
    }

    private func render(ast: AST, with context: RenderingContext) -> String {
        var out = ""

        for node in ast {
            switch node {

            case let .text(text):
                out += text

            case let .variable(variable, escaped):
                guard let variable = context.value(of: variable)?.stringyValue else {
                    continue
                }
                switch escaped {
                case true: out += escapeHTML(variable)
                case false: out += variable
                }

            case let .invertedSection(variable, innerAST):
                if let innerContext = context.value(of: variable), innerContext.truthyValue {
                    continue
                }

                out += render(ast: innerAST, with: context)

            case let .section(variable, innerAST):
                guard let innerContext = context.value(of: variable), innerContext.truthyValue else {
                    continue
                }

                if case let .array(innerContexts) = innerContext {
                    out += innerContexts
                        .map { render(ast: innerAST, with: context.extended(by: $0)) }
                        .joined(separator: "")
                } else {
                    out += render(ast: innerAST, with: context.extended(by: innerContext))
                }

            case let .partial(identifier, indentation):
                guard let partial = partials[identifier] else {
                    // if we dont find partial, dont render anything
                    continue
                }
                out += render(ast: indent(partial: partial, with: indentation), with: context)

            case let .block(identifier, innerAST):
                let (_, resolved) = resolve(block: (identifier, innerAST), against: context.overrideStack)
                out += render(ast: resolved, with: context)

            case let .override(identifier, innerAST):
                guard let inherited = partials[identifier] else {
                    // if we dont find partial to override, dont render anything
                    continue
                }

                let context = context.extended(by: (identifier, innerAST))
                out += render(ast: inherited, with: context)
            }
        }

        return out
    }
}

// Template inheritance
// Algorithm taken from https://github.com/mustache/spec/issues/38#issuecomment-162602289
// code heavily inspired by https://github.com/groue/GRMustache.swift/blob/Swift2/Mustache/Rendering/RenderingEngine.swift#L210
fileprivate extension Renderer {

    /**
     ```
     Iterate reversed partial queue
       If not been used yet
         resolver(content of partial override)
       If used
         Flag partial as used
     ```
     */
    func resolve(block: (identifier: String, ast: AST), against overrides: [(identifier: String, ast: AST)]) -> (identifier: String, ast: AST) {
        // identifiers of overrides that have already been overriden
        // (block only override first partial it hits, to support
        // nested overriding)
        var overridden = [String]()

        return overrides.reduce(block) { block, override in
            // if we have already overridden this block, dont override it again
            guard !overridden.contains(override.identifier) else {
                return block
            }

            // search through parents, overriding matching blocks with this one
            let (modified, resolved) = resolve(block: block, against: override.ast)

            // if resolving the block overrode another block, add it to the list
            if modified {
                overridden.append(override.identifier)
            }

            return resolved
        }
    }

    /**
     "Heavily inspired by" (basically copied from) https://github.com/groue/GRMustache.swift/blob/Swift2/Mustache/Rendering/RenderingEngine.swift#L251
     ```
     For each element in content
       If block
         If name matches
           Flag this as overriden
             return block
       If override
         recurse(parent partial content) or recurse(inner content)
       If partial
         recurse(partial content)
     ```
     */
    func resolve(block: (identifier: String, ast: AST), against content: AST) -> (overriden: Bool, resolved: (identifier: String, ast: AST)) {
        var overriden = false
        var block = block

        for node in content {
            switch node {
            case let .block(identifier, ast) where identifier == block.identifier:
                block = (identifier: identifier, ast: ast)
                overriden = true

            case let .override(partial, ast):
                // Partial overrides have two opportunities to override the
                // block: their parent partial, and their overriding blocks.
                guard let parent = self.partials[partial] else {
                    continue
                }

                // recurse all the way up
                let (overriden1, resolved1) = resolve(block: block, against: parent)
                // recurse down
                let (overriden2, resolved2) = resolve(block: resolved1, against: ast)

                overriden = overriden1 || overriden2
                block = resolved2

            case let .partial(partial, _):
                // partials can contain overrides, so they should
                // also be evaluated
                guard let partial = self.partials[partial] else {
                    continue
                }
                let (overriden1, resolved) = resolve(block: block, against: partial)

                overriden = overriden || overriden1
                block = resolved

            default:
                continue
            }
        }

        return (overriden, block)
    }
}

fileprivate extension Renderer {
    // TODO: Fix this... it's breaking a single test case and I don't know why
    func indent(partial: AST, with indentation: String) -> AST {
        return partial.map { node in
            guard case let .text(text) = node else {
                return node
            }

            return .text(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init(_:)).map { indentation + $0 }.joined(separator: "\n"))
        }
    }
}
