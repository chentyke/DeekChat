import SwiftUI

// String 扩展
extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}

class ChatViewModel: ObservableObject {
    @Published var currentChat: Chat?
    @Published var chatHistory: [Chat] = []
    @Published var isEditingTitle = false
    @Published var activeChat: UUID? // 正在生成回复的聊天ID
    @Published var shouldCancelGeneration = false // 用于取消生成
    
    private var activeChatUUID: UUID?
    
    private let chatHistoryKey = "chatHistory"
    private let currentChatKey = "currentChat"
    
    init() {
        loadChats()
        
        if currentChat == nil {
            createNewChat()
        }
    }
    
    private func loadChats() {
        // 从 UserDefaults 加载聊天记录
        if let data = UserDefaults.standard.data(forKey: chatHistoryKey),
           let decodedHistory = try? JSONDecoder().decode([Chat].self, from: data) {
            chatHistory = decodedHistory
        }
        
        // 从 UserDefaults 加载当前聊天
        if let data = UserDefaults.standard.data(forKey: currentChatKey),
           let decodedChat = try? JSONDecoder().decode(Chat.self, from: data) {
            currentChat = decodedChat
        } else {
            createNewChat()
        }
    }
    
    private func saveChats() {
        // 保存聊天记录
        if let encodedHistory = try? JSONEncoder().encode(chatHistory) {
            UserDefaults.standard.set(encodedHistory, forKey: chatHistoryKey)
        }
        
        // 保存当前聊天
        if let currentChat = currentChat,
           let encodedChat = try? JSONEncoder().encode(currentChat) {
            UserDefaults.standard.set(encodedChat, forKey: currentChatKey)
        }
    }
    
    func createNewChat() {
        print("创建新聊天")
        
        if let current = currentChat {
            if activeChat == current.id {
                return
            }
            
            // 只有包含用户消息且不在历史记录中的对话才加入历史记录
            if current.messages.contains(where: { $0.isUser }) && 
               !chatHistory.contains(where: { $0.id == current.id }) {
                chatHistory.insert(current, at: 0)
            }
        }
        
        let welcomeMessage = UserDefaults.standard.string(forKey: "welcomeMessage") ?? "你好！我是DeepSeek AI助手，请问有什么我可以帮你的吗？"
        
        currentChat = Chat(title: "新对话", messages: [
            ChatMessage(content: welcomeMessage, isUser: false, isSystemPrompt: true)
        ])
        
        saveChats()
    }
    
    func updateChatTitle(_ newTitle: String) {
        currentChat?.title = newTitle
        saveChats()
    }
    
    @MainActor
    func sendMessage(_ content: String) async throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        guard let chat = currentChat else { return }
        activeChat = chat.id
        shouldCancelGeneration = false // 重置取消状态
        
        print("发送消息: \(content)")
        let userMessage = ChatMessage(content: content, isUser: true)
        currentChat?.messages.append(userMessage)
        saveChats()
        
        // 创建一个初始的AI消息，设置isComplete为false
        let aiMessage = ChatMessage(content: "", isUser: false, isComplete: false)
        currentChat?.messages.append(aiMessage)
        saveChats()
        print("创建初始AI消息")
        
        do {
            var aiMessageContent = ""
            
            try await ChatService.shared.sendMessage(currentChat?.messages ?? []) { [weak self] partialContent in
                guard let self = self,
                      self.activeChat == chat.id
                else { return }
                
                // 检查是否应该取消生成
                if self.shouldCancelGeneration {
                    // 这里需要修改为非抛出错误的方式
                    print("取消生成")
                    return
                }
                
                print("收到部分内容[\(partialContent.count)字符]: '\(partialContent)'")
                aiMessageContent += partialContent
                
                // 更新消息内容（保持原始格式）
                if var messages = self.currentChat?.messages {
                    messages[messages.count - 1].content = aiMessageContent
                    // 确保在主线程上更新UI状态
                    DispatchQueue.main.async {
                        self.currentChat?.messages = messages
                        self.saveChats()
                    }
                }
            }
            
            print("\n=== 接收完成 ===")
            
            // 直接使用最终内容，不进行任何格式处理
            if var messages = self.currentChat?.messages {
                messages[messages.count - 1].isComplete = true
                // 确保在主线程上更新UI状态
                DispatchQueue.main.async {
                    self.currentChat?.messages = messages
                    self.saveChats()
                }
                
                // 输出最终内容
                print("\n=== 完整响应内容 ===")
                print(aiMessageContent)
            }
            
            print("消息发送完成")
            try await generateTitle()
            
            activeChat = nil
        } catch {
            print("发生错误: \(error)")
            if activeChat == chat.id {
                // 如果因为取消而中断，将最后一条消息设为完成状态
                if shouldCancelGeneration, var messages = currentChat?.messages {
                    messages[messages.count - 1].isComplete = true
                    messages[messages.count - 1].content += "\n\n[已停止生成]"
                    self.currentChat?.messages = messages
                    saveChats()
                } else {
                    // 其他错误情况，移除最后一条消息
                    currentChat?.messages.removeLast()
                    saveChats()
                }
            }
            activeChat = nil
            shouldCancelGeneration = false
            
            // 如果是取消生成，不抛出异常
            if let cancelError = error as? CancellationError {
                return
            }
            
            throw ChatError.apiError(error.localizedDescription)
        }
    }
    
    func loadChat(_ chat: Chat) {
        if let current = currentChat {
            if activeChat == current.id {
                return
            }
            
            // 只有包含用户消息的对话才加入历史记录
            if current.messages.contains(where: { $0.isUser }) {
                if !chatHistory.contains(where: { $0.id == current.id }) {
                    chatHistory.insert(current, at: 0)
                }
            }
        }
        
        currentChat = chat
        saveChats()
    }
    
    private func generateTitle() async throws {
        guard let messages = currentChat?.messages,
              !messages.isEmpty else { return }
        
        // 提取最近的对话内容（最多3轮）
        let recentMessages = messages.suffix(6)  // 最多取最近3轮对话（每轮2条消息）
        guard !recentMessages.isEmpty else { return }
        
        let formattedMessages = recentMessages.map { message in
            "\(message.isUser ? "用户" : "AI"): \(message.content)"
        }
        
        let prompt = """
        请为以下对话生成一个简短的标题，要求：
        1. 长度限制在2-8个汉字之间
        2. 准确概括对话的主要内容
        3. 使用简洁明了的语言
        4. 不要使用标点符号
        5. 不要出现"对话"、"讨论"等词

        对话内容：
        \(formattedMessages.joined(separator: "\n"))
        """
        
        do {
            if let titleResponse = try await ChatService.shared.generateTitle(prompt: prompt) {
                let newTitle = titleResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                // 清理标题中可能的标点符号
                let cleanTitle = newTitle.components(separatedBy: CharacterSet.punctuationCharacters).joined()
                
                if !cleanTitle.isEmpty {
                    await MainActor.run {
                        currentChat?.title = cleanTitle
                        saveChats()
                    }
                }
            }
        } catch {
            print("生成标题失败: \(error.localizedDescription)")
            // 如果生成标题失败，使用默认标题
            await MainActor.run {
                if currentChat?.title == "新对话" {
                    let defaultTitle = "对话\(Int.random(in: 1000...9999))"
                    currentChat?.title = defaultTitle
                    saveChats()
                }
            }
        }
    }
    
    // 删除特定对话
    func deleteChat(_ chat: Chat) {
        // 从历史记录中删除对话
        chatHistory.removeAll(where: { $0.id == chat.id })
        
        // 如果当前打开的对话被删除，则创建一个新对话
        if currentChat?.id == chat.id {
            currentChat = nil
            createNewChat()
        }
        
        saveChats()
    }
    
    func clearAllChats() {
        chatHistory.removeAll()
        currentChat = nil
        saveChats()
        createNewChat()  // 创建一个新的空聊天
    }
    
    // 重新生成AI回复
    @MainActor
    func regenerateAIResponse(for messageId: UUID) {
        guard let chat = currentChat else { return }
        activeChat = chat.id
        
        // 找到要重新生成的消息索引
        guard let index = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // 确保是AI消息
        guard !chat.messages[index].isUser else { return }
        
        // 寻找前一条用户消息
        var userMessageIndex = index - 1
        while userMessageIndex >= 0 {
            if chat.messages[userMessageIndex].isUser {
                break
            }
            userMessageIndex -= 1
        }
        
        guard userMessageIndex >= 0 else { return }
        
        // 提取用户消息内容
        let userMessage = chat.messages[userMessageIndex].content
        
        // 删除当前AI回复和对应的用户消息
        currentChat?.messages.remove(at: index)
        currentChat?.messages.remove(at: userMessageIndex)
        saveChats()
        
        // 重新发送同样的用户消息以触发新的AI回复
        Task {
            do {
                try await sendMessage(userMessage)
            } catch {
                print("重新生成失败: \(error)")
            }
        }
    }
    
    // 重新发送用户消息
    @MainActor
    func resendUserMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 简单地重新发送消息内容
        Task {
            do {
                try await sendMessage(content)
            } catch {
                print("重新发送失败: \(error)")
            }
        }
    }
    
    // 取消消息生成
    @MainActor
    func cancelMessageGeneration() async {
        guard activeChat != nil else { return }
        shouldCancelGeneration = true
        
        // 直接将当前消息标记为已完成
        if var messages = currentChat?.messages, !messages.isEmpty {
            let lastIndex = messages.count - 1
            
            // 确保最后一条是AI消息且未完成
            if !messages[lastIndex].isUser && !messages[lastIndex].isComplete {
                messages[lastIndex].isComplete = true
                messages[lastIndex].content += "\n\n[已停止生成]"
                currentChat?.messages = messages
                saveChats()
            }
        }
        
        // 清除活跃状态
        activeChat = nil
    }
}

enum ChatError: LocalizedError {
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
} 