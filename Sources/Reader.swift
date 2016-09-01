public class Peeker<Element> {
    fileprivate var lookahead = [Element]()
    fileprivate let iterator: AnyIterator<Element>

    public init(_ iterator: AnyIterator<Element>) {
        self.iterator = iterator
    }

    public func peek(_ n: Int) -> [Element] {
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
}

// inheritance to avoid type erasers (tried it, made stuff extremely ugly)
public final class Reader<Element>: Peeker<Element>, IteratorProtocol, Sequence {
    public func pop(_ n: Int) -> [Element] {
        var elements = [Element]()
        for _ in 0..<n {
            guard let next = lookahead.popFirst() ?? iterator.next() else {
                return elements
            }
            elements.append(next)
        }
        return elements
    }

    public func next() -> Element? {
        return pop()
    }
}

extension Peeker {
    public func peek() -> Element? {
        return peek(1).first
    }
}

extension Reader {
    @discardableResult
    public func pop() -> Element? {
        return pop(1).first
    }
}

extension Reader where Element: Equatable {
    public func pop(upTo element: Element, discarding: Bool = true) -> [Element]? {
        return pop(upTo: [element], discarding: discarding)
    }

    public func pop(upTo elements: [Element], discarding: Bool = true) -> [Element]? {
        let count = elements.count

        var popped: [Element] = []
        while peek(count) != elements {
            guard let el = pop() else {
                return discarding ? nil : popped
            }
            popped.append(el)
        }

        return popped
    }

    public var done: Bool {
        return peek() == nil
    }
}

public protocol _Character { var character: Character {get} }
extension Character: _Character { public var character: Character { return self } }
extension Reader where Element: _Character {
    public func consume(using characterSet: [Character]) {
        while let c = peek()?.character, characterSet.contains(c) {
            pop()
        }
    }
    public func consume(using characterSet: [Character], upTo: Int) {
        var upTo = upTo
        while upTo > 0, let c = peek()?.character, characterSet.contains(c) {
            upTo -= 1
            pop()
        }
    }
}

extension String {
    func reader() -> Reader<Character> {
        return Reader(AnyIterator(characters.makeIterator()))
    }
}

extension Sequence where Iterator.Element == Token {
    func reader() -> Reader<Token> {
        return Reader(AnyIterator(makeIterator()))
    }
}
