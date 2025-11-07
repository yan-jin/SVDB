//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
//

import Accelerate
import CoreML
import NaturalLanguage

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public class Collection<Doc: DocumentProtocol> {
    private var documents: [UUID: Doc] = [:]
    private let name: String
    
    // 防抖保存机制
    private let saveQueue: DispatchQueue
    private var saveWorkItem: DispatchWorkItem?
    private let saveDelay: TimeInterval
    
    // 用于线程安全的保存操作
    private let saveLock = NSLock()

    init(name: String, saveDelay: TimeInterval = 10.0) {
        self.name = name
        self.saveDelay = saveDelay
        // 创建串行队列用于保存操作
        self.saveQueue = DispatchQueue(label: "com.svdb.collection.save.\(name)", qos: .utility)
    }
    
    // 向后兼容：添加Document的方法（如果Doc是Document类型）
    public func addDocument(id: UUID? = nil, text: String, embedding: [Double], saveImmediately: Bool = false) where Doc == Document {
        let document = Document(
            id: id ?? UUID(),
            text: text,
            embedding: embedding
        )
        saveLock.lock()
        documents[document.id] = document
        saveLock.unlock()
        save(immediately: saveImmediately)
    }

    public func addDocument(_ document: Doc, saveImmediately: Bool = false) {
        saveLock.lock()
        documents[document.id] = document
        saveLock.unlock()
        save(immediately: saveImmediately)
    }

    public func addDocuments(_ docs: [Doc], saveImmediately: Bool = false) {
        saveLock.lock()
        docs.forEach { documents[$0.id] = $0 }
        saveLock.unlock()
        save(immediately: saveImmediately)
    }

    public func removeDocument(byId id: UUID, saveImmediately: Bool = false) {
        saveLock.lock()
        documents[id] = nil
        saveLock.unlock()
        save(immediately: saveImmediately)
    }

    public func search(
        query: [Double],
        num_results: Int = 10,
        threshold: Double? = nil
    ) -> [SearchResult<Doc>] {
        let queryMagnitude = sqrt(query.reduce(0) { $0 + $1 * $1 })

        // 安全地获取 documents 的副本用于搜索
        let documentsCopy: [UUID: Doc]
        saveLock.lock()
        documentsCopy = documents
        saveLock.unlock()

        var similarities: [SearchResult<Doc>] = []
        for document in documentsCopy.values {
            let id = document.id
            let vector = document.embedding
            let magnitude = document.magnitude
            let similarity = MathFunctions.cosineSimilarity(query, vector, magnitudeA: queryMagnitude, magnitudeB: magnitude)

            if let thresholdValue = threshold, similarity < thresholdValue {
                continue
            }

            similarities.append(SearchResult(id: id, document: document, score: similarity))
        }

        return Array(similarities.sorted(by: { $0.score > $1.score }).prefix(num_results))
    }

    /// 防抖保存：延迟执行保存操作，如果延迟期间有新操作则重新计时
    private func save(immediately: Bool = false) {
        // 取消之前的保存任务
        saveWorkItem?.cancel()
        
        if immediately {
            // 立即保存
            performSave()
            return
        }
        
        // 创建新的延迟保存任务
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = workItem
        
        // 延迟执行
        saveQueue.asyncAfter(deadline: .now() + saveDelay, execute: workItem)
    }
    
    /// 实际执行保存操作（在后台队列中执行）
    private func performSave() {
        // 在后台队列中执行保存操作
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 安全地获取 documents 的副本
            let documentsCopy: [UUID: Doc]
            self.saveLock.lock()
            documentsCopy = self.documents
            self.saveLock.unlock()
            
            let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
            try? FileManager.default.createDirectory(at: svdbDirectory, withIntermediateDirectories: true, attributes: nil)

            let fileURL = svdbDirectory.appendingPathComponent("\(self.name).json")

            do {
                let encodedDocuments = try JSONEncoder().encode(documentsCopy)
                let compressedData = try (encodedDocuments as NSData).compressed(using: .zlib)
                try compressedData.write(to: fileURL)
            } catch {
                print("Failed to save documents: \(error.localizedDescription)")
            }
        }
    }
    
    /// 公共方法：强制立即保存
    public func saveNow() {
        saveWorkItem?.cancel()
        performSave()
    }

    public func load() throws {
        let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
        let fileURL = svdbDirectory.appendingPathComponent("\(name).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist for collection \(name), initializing with empty documents.")
            saveLock.lock()
            documents = [:]
            saveLock.unlock()
            return
        }

        do {
            let compressedData = try Data(contentsOf: fileURL)

            let decompressedData = try (compressedData as NSData).decompressed(using: .zlib)
            let loadedDocuments = try JSONDecoder().decode([UUID: Doc].self, from: decompressedData as Data)
            
            saveLock.lock()
            documents = loadedDocuments
            saveLock.unlock()

            print("Successfully loaded collection: \(name)")
        } catch {
            print("Failed to load collection \(name): \(error.localizedDescription)")
            throw CollectionError.loadFailed(error.localizedDescription)
        }
    }

    public func clear(saveImmediately: Bool = false) {
        saveLock.lock()
        documents.removeAll()
        saveLock.unlock()
        save(immediately: saveImmediately)
    }
    
    /// 获取所有文档（用于查找和遍历）
    public func getAllDocuments() -> [Doc] {
        saveLock.lock()
        defer { saveLock.unlock() }
        return Array(documents.values)
    }
    
    /// 根据ID获取文档
    public func getDocument(byId id: UUID) -> Doc? {
        saveLock.lock()
        defer { saveLock.unlock() }
        return documents[id]
    }
}
