public protocol Peeker {
    func peek(_ n: Int) -> [Character]
    func peek(_ n: Int, ignoring: [Character]) -> [Character]
    func backPeek(_ n: Int) -> [Character]
}

public extension Peeker {
    func peek() -> Character? {
        return peek(1).first
    }

    var done: Bool {
        return peek() == nil
    }
}

public protocol Popper {
    func pop(_ n: Int) -> [Character]
    func pop(_ n: Int, ignoring: [Character]) -> [Character]
    var done: Bool { get }
}

public extension Popper {
    @discardableResult
    func pop() -> Character? {
        return pop(1).first
    }
}

public final class Reader: Peeker, Popper {
    fileprivate let iterator: AnyIterator<Character>
    fileprivate var lookahead = [Character]()
    fileprivate var popped = [Character]()

    public init(_ iterator: AnyIterator<Character>) {
        self.iterator = iterator
    }

    public convenience init(_ string: String) {
        self.init(AnyIterator(string.characters.makeIterator()))
    }

    public func backPeek(_ n: Int) -> [Character] {
        return popped.last(n)
    }

    public func peek(_ n: Int) -> [Character] {
        for i in 0..<n {
            guard !lookahead.indices.contains(i) else {
                continue
            }
            guard let next = iterator.next() else {
                return lookahead.first(i)
            }
            lookahead.append(next)
        }
        return lookahead.first(n)
    }

    public func pop(_ n: Int) -> [Character] {
        for i in 0..<n {
            guard let char = lookahead.popFirst() ?? iterator.next() else {
                return popped.last(i)
            }
            popped.append(char)
        }
        return popped.last(n)
    }
}

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
