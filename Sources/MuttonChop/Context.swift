public enum Context {
    case null
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case array([Context])
    case dictionary([String:Context])
}

// MARK: Codable

extension Context: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let array):
            try container.encode(array)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if container.decodeNil() {
            self = .null
        } else if let array = try? container.decode([Context].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String:Context].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected value to be of type String, Bool, Int, Double, Array, Dictionary, or null.")
        }
    }
}


// MARK: Literal
extension Context: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}
extension Context: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}
extension Context: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}
extension Context: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
}
extension Context: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}
extension Context: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Context...) {
        self = .array(elements)
    }
}
extension Context: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Context)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}
