public enum Context {
    case bool(Bool)
    case double(Double)
    case int(Int)
    case string(String)
    case array([Context])
    case dictionary([String: Context])

    var isTruthy: Bool {
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

    func asString() -> String? {
        switch self {

        case let .string(value): return value
        case let .int(value): return String(value)
        case let .double(value): return String(value)

        case let .array(values):
            var out = ""
            for value in values {
                guard let string = value.asString() else {
                    return nil
                }
                out += string
            }
            return out

        default: return nil
        }
    }
}

extension Sequence where Iterator.Element == Context {
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
            if let variable = contextStack.value(of: variable)?.asString() {
                switch escaped {
                case true: out += escapeHTML(variable)
                case false: out += variable
                }
            }

        case let .section(variable, inverted, innerAST):
            let truthyContext: Context? = {
                guard let context = contextStack.value(of: variable), context.isTruthy else {
                    return nil
                }
                return context
            }()

            switch inverted {
            case true:
                if truthyContext == nil {
                    out += render(ast: innerAST, contextStack: contextStack)
                }
            case false:
                guard let context = truthyContext else {
                    break
                }
                if case let .array(innerContexts) = context {
                    out += innerContexts.map { render(ast: innerAST, contextStack: [$0] + contextStack) }.joined(separator: "")
                } else {
                    out += render(ast: innerAST, contextStack: [context] + contextStack)
                }
            }

        case let .partial(partial, indentation):
            let partial = partial.map { node -> ASTNode in
                guard case let .text(text) = node else {
                    return node
                }

                // add indentation to each newline
                return .text(text.characters.split(separator: "\n", omittingEmptySubsequences: false).map(String.init(_:))
                    .map { line in line.characters.isEmpty ? line : indentation + line }
                    .joined(separator: "\n"))
            }

            out += render(ast: partial, contextStack: contextStack)
        }
    }

    return out
}
