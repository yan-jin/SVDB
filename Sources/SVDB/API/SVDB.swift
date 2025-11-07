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
    
    /// 保存所有 collections（用于应用退出时确保数据持久化）
    public func saveAll() {
        lock.lock()
        defer { lock.unlock() }
        
        // 由于 collections 存储为 [String: Any]，我们需要遍历并调用 saveNow()
        // 由于类型擦除，我们需要使用协议或类型检查
        for (_, collection) in collections {
            // 尝试将 collection 转换为有 saveNow 方法的类型
            // 由于 Collection 是泛型类，我们需要使用反射或协议
            // 简单方法：检查是否有 saveNow 方法（通过协议）
            if let saveable = collection as? any CollectionSaveable {
                saveable.saveNow()
            }
        }
    }
}

/// 协议用于类型擦除，允许在 SVDB 中保存所有 collections
@available(macOS 10.15, *)
@available(iOS 13.0, *)
private protocol CollectionSaveable {
    func saveNow()
}

@available(macOS 10.15, *)
@available(iOS 13.0, *)
extension Collection: CollectionSaveable {
    // Collection 已经实现了 saveNow() 方法
}
