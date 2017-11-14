extension Array {
    func last(_ n: Int) -> [Element] {
        let startIndex = self.index(endIndex, offsetBy: -n, limitedBy: self.startIndex) ?? 0
        return Array(self[startIndex..<endIndex])
    }
    func first(_ n: Int) -> [Element] {
        let endIndex = self.index(startIndex, offsetBy: n)
        return Array(self[startIndex..<endIndex])
    }
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}

extension Array {
    func element(at index: Index) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
    func elements(in range: CountableRange<Int>) -> [Element]? {
        guard indices.contains(range.lowerBound), indices.contains(range.upperBound - 1) else {
            return nil
        }
        return Array(self[range])
    }
}

extension Dictionary {
    func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> [Key: T] {
        var dictionary: [Key: T] = [:]

        for (key, value) in self {
            dictionary[key] = try transform(value)
        }

        return dictionary
    }
}

extension String {
    static let newLineCharacterSet: [Character] = ["\n", "\r", "\r\n"]
    static let whitespaceCharacterSet: [Character] = [" ", "\t"]
    static let whitespaceAndNewLineCharacterSet: [Character] = whitespaceCharacterSet + newLineCharacterSet

    func trim(using characterSet: [Character]) -> String {
        return trimLeft(using: characterSet).trimRight(using: characterSet)
    }

    func trimLeft(using characterSet: [Character]) -> String {
        var start = 0

        for (index, character) in enumerated() {
            if !characterSet.contains(character) {
                start = index
                break
            }
        }

        return String(self[index(startIndex, offsetBy: start) ..< endIndex])
    }

    func trimRight(using characterSet: [Character]) -> String {
        var end = count

        for (index, character) in reversed().enumerated() {
            if !characterSet.contains(character) {
                end = index
                break
            }
        }

        return String(self[startIndex ..< index(endIndex, offsetBy: -end)])
    }
}
