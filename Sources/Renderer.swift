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

        case let .variable(variable):
            if let variable = contextStack.value(of: variable)?.asString() {
                out += variable
            }

        case let .section(variable, innerAST):
            guard
                let innerContext = contextStack.value(of: variable), innerContext.isTruthy
                else {
                continue
            }

            if case let .array(innerContexts) = innerContext {
                out += innerContexts.map { render(ast: innerAST, contextStack: [$0] + contextStack) }.joined(separator: "")
            } else {
                out += render(ast: innerAST, contextStack: [innerContext] + contextStack)
            }

        case let .invertedSection(variable, innerAST):
            switch contextStack.value(of: variable) {

            // if there is a value and its truthy, don't render
            case let .some(innerContext) where innerContext.isTruthy:
                continue

            // if no value, render
            // if yes value but falsey, render
            case .none, .some:
                out += render(ast: innerAST, contextStack: contextStack)
            }
        }
    }

    return out
}
