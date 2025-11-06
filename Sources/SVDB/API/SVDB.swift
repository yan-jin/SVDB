import Accelerate
import CoreML
import NaturalLanguage
import Foundation

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public class SVDB {
    public static let shared = SVDB()
    private var collections: [String: Any] = [:]
    private let lock = NSLock()

    private init() {}
    
    // 向后兼容：默认使用Document类型
    public func collection(_ name: String) throws -> Collection<Document> {
        lock.lock()
        defer { lock.unlock() }
        
        if collections[name] != nil {
            throw SVDBError.collectionAlreadyExists
        }

        let collection = Collection<Document>(name: name)
        collections[name] = collection
        try collection.load()
        return collection
    }
    
    // 支持自定义Document类型的Collection
    public func collection<Doc: DocumentProtocol>(_ name: String, documentType: Doc.Type) throws -> Collection<Doc> {
        lock.lock()
        defer { lock.unlock() }
        
        if collections[name] != nil {
            throw SVDBError.collectionAlreadyExists
        }

        let collection = Collection<Doc>(name: name)
        collections[name] = collection
        try collection.load()
        return collection
    }

    public func getCollection(_ name: String) -> Collection<Document>? {
        lock.lock()
        defer { lock.unlock() }
        return collections[name] as? Collection<Document>
    }
    
    public func getCollection<Doc: DocumentProtocol>(_ name: String, documentType: Doc.Type) -> Collection<Doc>? {
        lock.lock()
        defer { lock.unlock() }
        return collections[name] as? Collection<Doc>
    }

    public func releaseCollection(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        collections[name] = nil
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        for (_, collection) in collections {
            if let coll = collection as? Collection<Document> {
                coll.clear()
            }
        }
        collections.removeAll()
    }
}
