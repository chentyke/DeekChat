import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    var isComplete: Bool
    var isSystemPrompt: Bool
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), isComplete: Bool = true, isSystemPrompt: Bool = false) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isComplete = isComplete
        self.isSystemPrompt = isSystemPrompt
    }
}

struct Chat: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String = "新对话", messages: [ChatMessage] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
    }
    
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
} 
