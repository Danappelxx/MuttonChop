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
    func mapValues<T>(_ transform: (Value) -> T) -> [Key: T] {
        var dictionary: [Key: T] = [:]

        for (key, value) in self {
            dictionary[key] = transform(value)
        }

        return dictionary
    }
}

extension AnyIterator where Element: Equatable {
    func pop(until element: Element) -> (matched: Bool, popped: [Element]) {
        var popped = [Element]()
        while let next = next() {
            guard next != element else {
                return (matched: true, popped: popped)
            }
            popped.append(next)
        }
        return (matched: false, popped: popped)
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

        for (index, character) in characters.enumerated() {
            if !characterSet.contains(character) {
                start = index
                break
            }
        }

        return self[index(startIndex, offsetBy: start) ..< endIndex]
    }

    func trimRight(using characterSet: [Character]) -> String {
        var end = characters.count

        for (index, character) in characters.reversed().enumerated() {
            if !characterSet.contains(character) {
                end = index
                break
            }
        }

        return self[startIndex ..< index(endIndex, offsetBy: -end)]
    }
}
