//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
//

import Foundation

/// 通用搜索结果，可以包含完整的Document信息
@available(macOS 10.15, *)
@available(iOS 13.0, *)
public struct SearchResult<Doc: DocumentProtocol> {
    public let id: UUID
    public let document: Doc
    public let score: Double
    
    // 向后兼容：text字段（如果Document有text字段）
    public var text: String {
        if let doc = document as? Document {
            return doc.text
        }
        return ""
    }
}
