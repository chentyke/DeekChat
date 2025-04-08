import Foundation

class ChatService {
    static let shared = ChatService()
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "apiUrl") ?? "https://api.siliconflow.cn/v1"
    }
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? "sk-ada65b7ca11a4a75a3cde759101d07ba"
    }
    
    private var model: String {
        let modelName = UserDefaults.standard.string(forKey: "modelName") ?? "deepseek-ai/DeepSeek-V3"
        if modelName == "custom" {
            return UserDefaults.standard.string(forKey: "customModelName") ?? "deepseek-ai/DeepSeek-V3"
        }
        return modelName
    }
    
    func sendMessage(_ messages: [ChatMessage], onUpdate: @escaping (String) -> Void) async throws {
        print("\n=== 开始发送消息 ===")
        print("使用模型: \(model)")
        print("API地址: \(baseURL)")
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let mappedMessages = messages.map { [
            "role": $0.isUser ? "user" : "assistant",
            "content": $0.content
        ]}
        
        let body: [String: Any] = [
            "model": model,
            "messages": mappedMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 用于检查是否请求被取消
        var isCancelled = false
        
        // 创建Task来监听取消信号
        let processingTask = Task {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("\n=== HTTP响应 ===")
                print("状态码: \(httpResponse.statusCode)")
                
                if !(200...299).contains(httpResponse.statusCode) {
                    if let data = try? await URLSession.shared.data(for: request).0,
                       let errorString = String(data: data, encoding: .utf8) {
                        print("\n错误响应内容: \(errorString)")
                        throw ChatError.apiError("API错误: \(errorString)")
                    }
                    throw ChatError.apiError("HTTP错误: \(httpResponse.statusCode)")
                }
            }
            
            print("\n=== 响应内容 ===")
            var fullContent = ""
            
            for try await line in bytes.lines {
                // 检查是否已被取消
                if Task.isCancelled || isCancelled {
                    print("流式传输已取消")
                    throw CancellationError()
                }
                
                guard line.hasPrefix("data: ") else { continue }
                let data = line.dropFirst(6)
                
                if data == "[DONE]" { break }
                
                if let jsonData = data.data(using: .utf8) {
                    do {
                        let response = try JSONDecoder().decode(StreamResponse.self, from: jsonData)
                        if let content = response.choices.first?.delta.content {
                            fullContent += content
                            onUpdate(content)
                        }
                    } catch {
                        print("JSON解析错误: \(error)")
                    }
                }
            }
            
            print("\n=== 完整响应内容 ===")
            print(fullContent)
            print("\n=== 消息发送完成 ===\n")
            return fullContent
        }
        
        do {
            let _ = try await processingTask.value
        } catch is CancellationError {
            isCancelled = true
            processingTask.cancel()
            print("请求已取消")
            throw CancellationError()
        } catch {
            processingTask.cancel()
            throw error
        }
    }
    
    func generateTitle(prompt: String) async throws -> String? {
        print("\n=== 开始生成标题 ===")
        print("使用模型: \(model)")
        print("API地址: \(baseURL)")
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "你是一个帮助生成标题的助手"],
                ["role": "user", "content": prompt]
            ],
            "stream": false,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\n=== HTTP响应 ===")
            print("状态码: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("\n错误响应内容: \(errorString)")
                    throw ChatError.apiError("HTTP错误: \(httpResponse.statusCode), 错误信息: \(errorString)")
                }
                throw ChatError.apiError("HTTP错误: \(httpResponse.statusCode)")
            }
        }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("\n=== 完整响应内容 ===")
            print(jsonString)
        }
        
        do {
            let response = try JSONDecoder().decode(ChatResponse.self, from: data)
            let title = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("\n=== 生成的标题 ===")
            print(title ?? "nil")
            print("\n=== 标题生成完成 ===\n")
            return title
        } catch {
            print("\n解析错误: \(error)")
            print("错误详情: \(error.localizedDescription)")
            throw ChatError.apiError("解析响应失败: \(error.localizedDescription)")
        }
    }
    
    func fetchBalance() async throws -> BalanceResponse {
        let url = URL(string: "\(baseURL)/user/balance")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ChatError.apiError("HTTP错误: \(httpResponse.statusCode)")
        }
        
        do {
            let balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
            return balanceResponse
        } catch {
            print("解析错误: \(error)")
            throw ChatError.apiError("解析响应失败: \(error.localizedDescription)")
        }
    }
}

struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct StreamResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamChoice]
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}

struct BalanceInfo: Codable {
    let currency: String
    let totalBalance: String
    let grantedBalance: String
    let toppedUpBalance: String
    
    enum CodingKeys: String, CodingKey {
        case currency
        case totalBalance = "total_balance"
        case grantedBalance = "granted_balance"
        case toppedUpBalance = "topped_up_balance"
    }
}

struct BalanceResponse: Codable {
    let isAvailable: Bool
    let balanceInfos: [BalanceInfo]
    
    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }
} 
