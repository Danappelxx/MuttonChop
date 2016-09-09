// Stage 3 - Render AST to string

@_exported import StructuredData

public typealias Context = StructuredData

extension Context {
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
        default:
            return true
        }
    }
}

extension Sequence where Iterator.Element == Context {
    // TODO: clean this up
    func value(of variable: String) -> Context? {
        let components = variable.characters.split(separator: ".").map({ String($0) })

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

// TODO: Move this into a `Renderer` class
func render(ast: AST, context: Context) -> String {
    return render(ast: ast, contextStack: [context])
}

func render(ast: AST, contextStack: [Context]) -> String {
    var out = ""

    for node in ast {
        switch node {

        case let .text(text):
            out += text

        case let .variable(variable, escaped):
            guard let variable = contextStack.value(of: variable)?.stringyValue else {
                continue
            }
            switch escaped {
            case true: out += escapeHTML(variable)
            case false: out += variable
            }


        case let .invertedSection(variable, innerAST):
            if let context = contextStack.value(of: variable), context.truthyValue {
                continue
            }

            out += render(ast: innerAST, contextStack: contextStack)

        case let .section(variable, innerAST):
            guard let context = contextStack.value(of: variable), context.truthyValue else {
                continue
            }

            if case let .array(innerContexts) = context {
                out += innerContexts.map { render(ast: innerAST, contextStack: [$0] + contextStack) }.joined(separator: "")
            } else {
                out += render(ast: innerAST, contextStack: [context] + contextStack)
            }

        case let .partial(partial):
            out += render(ast: partial, contextStack: contextStack)

        case let .override(identifier: _, ast: innerAST):
            out += render(ast: innerAST, contextStack: contextStack)
        }
    }

    return out
}
