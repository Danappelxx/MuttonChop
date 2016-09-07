// MARK: Declarations
public final class Reader {
    fileprivate let iterator: AnyIterator<Character>
    fileprivate var lookahead = [Character]()
    fileprivate var lookbehind = [Character]()

    public init(_ iterator: AnyIterator<Character>) {
        self.iterator = iterator
    }

    public convenience init(_ string: String) {
        self.init(AnyIterator(string.characters.makeIterator()))
    }

    public func backPeek(_ n: Int) -> [Character] {
        return lookbehind.last(n)
    }

    // returns false if it ran out of characters
    @discardableResult
    fileprivate func loadLookahead(_ n: Int = 1) -> Bool {
        for _ in 0..<n {
            guard let next = iterator.next() else {
                return false
            }
            lookahead.append(next)
        }
        return true
    }

    public func peek(_ n: Int) -> [Character] {
        for i in 0..<n {
            guard !lookahead.indices.contains(i) else {
                continue
            }
            guard loadLookahead(1) else {
                return lookahead.first(i)
            }
        }
        return lookahead.first(n)
    }

    @discardableResult
    public func pop(_ n: Int) -> [Character] {
        for i in 0..<n {
            guard let char = lookahead.popFirst() ?? iterator.next() else {
                return lookbehind.last(i)
            }
            lookbehind.append(char)
        }
        return lookbehind.last(n)
    }
}

// MARK: Line/column
public extension Reader {
    var lines: [[Character]] {
        return self.lookbehind.split(separator: "\n", omittingEmptySubsequences: false).map(Array.init)
    }
    var line: Int {
        return lines.count
    }
    var column: Int {
        return lines.last?.count ?? 0
    }
}

// MARK: Single peek/pop
public extension Reader {
    func peek() -> Character? {
        return peek(1).first
    }

    var done: Bool {
        return peek() == nil
    }
}

public extension Reader {
    @discardableResult
    func pop() -> Character? {
        return pop(1).first
    }
}

// MARK: [peek,pop](ignoring:)
public extension Reader {
    func peek(_ n: Int, ignoring: [Character]) -> [Character] {
        var remaining = n
        var i = 0
        while remaining > 0 {
            defer { i += 1 }

            guard !lookahead.indices.contains(i) else {
                if !ignoring.contains(lookahead[i]) {
                    remaining -= 1
                }
                continue
            }
            guard let next = iterator.next() else {
                return lookahead.first(i)
            }
            lookahead.append(next)
            if ignoring.contains(next) {
                continue
            }
            remaining -= 1
        }
        return lookahead.first(i).filter { !ignoring.contains($0) }
    }

    func pop(_ n: Int, ignoring: [Character]) -> [Character] {
        var characters = [Character]()
        while characters.count < n {
            guard let next = lookahead.popFirst() ?? iterator.next() else {
                return characters
            }
            if ignoring.contains(next) {
                continue
            }
            characters.append(next)
        }
        return characters
    }
}

// MARK: [peek/backPeek/pop](upTo:)
public extension Reader {
    func backPeek(upToAnyOf characterSet: [Character], discarding: Bool = true) -> [Character]? {
        // goes from end to start
        var upper = lookbehind.count
        var lower = upper - 1

        while let window = lookbehind.elements(in: lower..<upper) {
            defer { lower -= 1; upper -= 1 }
            for character in characterSet where window.contains(character) {
                return Array(lookbehind[upper..<lookbehind.endIndex])
            }
        }

        return discarding ? nil : Array(lookbehind[upper..<lookbehind.endIndex])
    }

    func backPeek(upTo character: Character, discarding: Bool = true) -> [Character]? {
        return backPeek(upTo: [character], discarding: discarding)
    }

    func backPeek(upTo characters: [Character], discarding: Bool = true) -> [Character]? {
        let count = characters.count

        // goes from end to start
        var upper = lookbehind.count
        var lower = upper - count

        while let window = lookbehind.elements(in: lower..<upper) {
            defer { lower -= 1; upper -= 1 }
            if window == characters {
                return Array(lookbehind[upper..<lookbehind.endIndex])
            }
        }

        return discarding ? nil : Array(lookbehind[upper..<lookbehind.endIndex])
    }
}

public extension Reader {
    private func lookaheadWindow(lower: Int, upper: Int) -> [Character]? {
        if let window = lookahead.elements(in: lower..<upper) {
            return window
        }
        loadLookahead(upper - lower)
        return lookahead.elements(in: lower..<upper)
    }

    func peek(upToAnyOf characterSet: [Character], discarding: Bool = true) -> [Character]? {
        // goes from start to end
        var lower = 0
        var upper = 1

        while let window = lookaheadWindow(lower: lower, upper: upper) {
            defer { lower += 1; upper += 1 }
            for character in characterSet where window.contains(character) {
                return Array(lookahead[0..<lower])
            }
        }

        return discarding ? nil : Array(lookahead[0..<lower])
    }

    func peek(upTo character: Character, discarding: Bool = true) -> [Character]? {
        return backPeek(upTo: [character], discarding: discarding)
    }

    func peek(upTo characters: [Character], discarding: Bool = true) -> [Character]? {
        let count = characters.count

        // goes from end to start
        var lower = 0
        var upper = lower + count

        while let window = lookaheadWindow(lower: lower, upper: upper) {
            defer { lower += 1; upper += 1 }
            if window == characters {
                return Array(lookahead[0..<lower])
            }
        }

        return discarding ? nil : Array(lookahead[0..<lower])
    }
}

public extension Reader {
    func pop(upTo character: Character, discarding: Bool = true) -> [Character]? {
        return pop(upTo: [character], discarding: discarding)
    }

    func pop(upTo characters: [Character], discarding: Bool = true) -> [Character]? {
        let count = characters.count

        var popped: [Character] = []
        while peek(count) != characters {
            guard let char = pop() else {
                return discarding ? nil : popped
            }
            popped.append(char)
        }

        return popped
    }

    func popToEnd() -> [Character] {
        var popped = [Character]()
        while let next = pop() {
            popped.append(next)
        }
        return popped
    }
}

public extension Reader {
    func consume(using characterSet: [Character]) {
        consume(using: characterSet, upTo: -1)
    }

    func consume(using characterSet: [Character], upTo: Int) {
        var upTo = upTo
        while upTo != 0, let c = peek(), characterSet.contains(c) {
            upTo -= 1
            pop()
        }
    }
}

// MARK: Leading/Trailing
public extension Reader {
    func leadingWhitespace() -> [Character]? {
        // not discarding = force unwrap is ok
        let characters = backPeek(upToAnyOf: String.newLineCharacterSet, discarding: false)!
        return characters.filter { !String.whitespaceCharacterSet.contains($0) }.isEmpty
            ? characters
            : nil
    }

    func trailingWhitespace() -> [Character]? {
        let characters = peek(upToAnyOf: String.newLineCharacterSet, discarding: false)!
        return characters.filter { !String.whitespaceCharacterSet.contains($0) }.isEmpty
            ? characters
            : nil
    }
}
