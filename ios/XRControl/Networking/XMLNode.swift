import Foundation

/// A minimal read-only XML tree, enough to pick values out of NETGEAR's SOAP
/// responses without pulling in a dependency.
public final class XMLNode {
    public let name: String
    public private(set) var text: String
    public private(set) var children: [XMLNode]
    public private(set) weak var parent: XMLNode?

    init(name: String, parent: XMLNode? = nil) {
        self.name = name
        self.text = ""
        self.children = []
        self.parent = parent
    }

    fileprivate func append(text: String) {
        self.text += text
    }

    fileprivate func addChild(_ node: XMLNode) {
        children.append(node)
    }

    /// Element name with any namespace prefix removed (`m:GetInfoResponse` → `GetInfoResponse`).
    public var localName: String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    public var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Depth-first search for the first descendant with a matching local name.
    public func firstDescendant(named target: String) -> XMLNode? {
        for child in children {
            if child.localName.caseInsensitiveCompare(target) == .orderedSame { return child }
            if let match = child.firstDescendant(named: target) { return match }
        }
        return nil
    }

    /// All descendants with a matching local name, in document order.
    public func descendants(named target: String) -> [XMLNode] {
        var matches: [XMLNode] = []
        for child in children {
            if child.localName.caseInsensitiveCompare(target) == .orderedSame {
                matches.append(child)
            }
            matches.append(contentsOf: child.descendants(named: target))
        }
        return matches
    }

    /// Text of the first descendant with a matching local name.
    public func value(_ target: String) -> String? {
        guard let node = firstDescendant(named: target) else { return nil }
        let value = node.trimmedText
        return value.isEmpty ? nil : value
    }

    public subscript(target: String) -> String? { value(target) }
}

/// Parses XML into an `XMLNode` tree.
public enum XMLTreeParser {
    public static func parse(_ data: Data) throws -> XMLNode {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "malformed XML"
            throw RouterError.malformedResponse(detail)
        }
        return delegate.root
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let root = XMLNode(name: "#document")
        private lazy var current: XMLNode = root

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            let node = XMLNode(name: elementName, parent: current)
            current.addChild(node)
            current = node
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            current.append(text: string)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            current = current.parent ?? root
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let string = String(data: CDATABlock, encoding: .utf8) {
                current.append(text: string)
            }
        }
    }
}
