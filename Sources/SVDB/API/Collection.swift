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

    init(name: String) {
        self.name = name
    }
    
    // 向后兼容：添加Document的方法（如果Doc是Document类型）
    public func addDocument(id: UUID? = nil, text: String, embedding: [Double]) where Doc == Document {
        let document = Document(
            id: id ?? UUID(),
            text: text,
            embedding: embedding
        )
        documents[document.id] = document
        save()
    }

    public func addDocument(_ document: Doc) {
        documents[document.id] = document
        save()
    }

    public func addDocuments(_ docs: [Doc]) {
        docs.forEach { documents[$0.id] = $0 }
        save()
    }

    public func removeDocument(byId id: UUID) {
        documents[id] = nil
        save()
    }

    public func search(
        query: [Double],
        num_results: Int = 10,
        threshold: Double? = nil
    ) -> [SearchResult<Doc>] {
        let queryMagnitude = sqrt(query.reduce(0) { $0 + $1 * $1 })

        var similarities: [SearchResult<Doc>] = []
        for document in documents.values {
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

    private func save() {
        let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
        try? FileManager.default.createDirectory(at: svdbDirectory, withIntermediateDirectories: true, attributes: nil)

        let fileURL = svdbDirectory.appendingPathComponent("\(name).json")

        do {
            let encodedDocuments = try JSONEncoder().encode(documents)
            let compressedData = try (encodedDocuments as NSData).compressed(using: .zlib)
            try compressedData.write(to: fileURL)
        } catch {
            print("Failed to save documents: \(error.localizedDescription)")
        }
    }

    public func load() throws {
        let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
        let fileURL = svdbDirectory.appendingPathComponent("\(name).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist for collection \(name), initializing with empty documents.")
            documents = [:]
            return
        }

        do {
            let compressedData = try Data(contentsOf: fileURL)

            let decompressedData = try (compressedData as NSData).decompressed(using: .zlib)
            documents = try JSONDecoder().decode([UUID: Doc].self, from: decompressedData as Data)

            print("Successfully loaded collection: \(name)")
        } catch {
            print("Failed to load collection \(name): \(error.localizedDescription)")
            throw CollectionError.loadFailed(error.localizedDescription)
        }
    }

    public func clear() {
        documents.removeAll()
        save()
    }
    
    /// 获取所有文档（用于查找和遍历）
    public func getAllDocuments() -> [Doc] {
        return Array(documents.values)
    }
    
    /// 根据ID获取文档
    public func getDocument(byId id: UUID) -> Doc? {
        return documents[id]
    }
}
