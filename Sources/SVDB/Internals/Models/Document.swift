//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
//

import Foundation

/// Document协议，要求实现Codable和Identifiable，并包含embedding和magnitude
@available(macOS 10.15, *)
@available(iOS 13.0, *)
public protocol DocumentProtocol: Codable, Identifiable {
    var id: UUID { get }
    var embedding: [Double] { get }
    var magnitude: Double { get }
}

/// 默认的Document实现（向后兼容）
public struct Document: DocumentProtocol {
    public let id: UUID
    public let text: String
    public let embedding: [Double]
    public let magnitude: Double

    public init(id: UUID? = nil, text: String, embedding: [Double]) {
        self.id = id ?? UUID()
        self.text = text
        self.embedding = embedding
        self.magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
    }
}
