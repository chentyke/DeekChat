import SwiftUI

struct MessageBubble: View {
    let message: String
    let isUser: Bool
    let isComplete: Bool
    let isSystemPrompt: Bool
    @State private var parsedContent: AttributedString = AttributedString("")
    @State private var showMessage = false
    @State private var typingProgress = 0.0
    @State private var dotAnimations: [Bool] = [false, false, false]
    @State private var showButtons = false
    @State private var showCopyToast = false
    @State private var showRegenerateConfirm = false
    
    // 重新生成的回调
    var onRegenerate: (() -> Void)?
    
    // 初始化器增加默认参数
    init(message: String, isUser: Bool, isComplete: Bool, isSystemPrompt: Bool = false, onRegenerate: (() -> Void)? = nil) {
        self.message = message
        self.isUser = isUser
        self.isComplete = isComplete
        self.isSystemPrompt = isSystemPrompt
        self.onRegenerate = onRegenerate
    }
    
    // 获取背景亮度设置
    private var backgroundBrightness: Double {
        return UserDefaults.standard.double(forKey: "backgroundBrightness") 
    }
    
    var body: some View {
        VStack {
            if isUser {
                // 用户消息
                HStack(alignment: .bottom) {
                    Spacer()
                    Text(parsedContent)
                        .textSelection(.enabled)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 0)
                        .padding(.top, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        )
                        .clipShape(
                            RoundedCornerShape(
                                radius: 20,
                                corners: [.topLeft, .topRight, .bottomLeft]
                            )
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                        .padding(.trailing, 16)
                        .padding(.leading, 60)
                        .opacity(showMessage ? 1 : 0)
                        .offset(y: showMessage ? 0 : 20)
                        .onLongPressGesture {
                            // 显示重新发送确认
                            if !isSystemPrompt && onRegenerate != nil {
                                showRegenerateConfirm = true
                            }
                        }
                }
            } else {
                // AI消息
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        if message.isEmpty && !isComplete {
                            // 在没有文本时显示动画在第一行位置
                            HStack(spacing: 5) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(Color.gray.opacity(0.7))
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(dotAnimations[i] ? 1.3 : 0.7)
                                        .offset(y: dotAnimations[i] ? -4 : 2)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.systemGray6).opacity(backgroundBrightness))
                            )
                            .clipShape(
                                RoundedCornerShape(
                                    radius: 20,
                                    corners: [.topLeft, .topRight, .bottomRight]
                                )
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        } else {
                            // AI消息内容 - 使用专门的渲染组件
                            MarkdownContentView(
                                content: message,
                                parsedContent: parsedContent,
                                backgroundBrightness: backgroundBrightness
                            )
                            .clipShape(
                                RoundedCornerShape(
                                    radius: 20,
                                    corners: [.topLeft, .topRight, .bottomRight]
                                )
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                            .onLongPressGesture {
                                // 长按AI消息触发重新生成
                                if !isSystemPrompt && isComplete && onRegenerate != nil {
                                    showRegenerateConfirm = true
                                }
                            }
                        }
                        
                        if !isComplete && !message.isEmpty {
                            // 只有在有文本且未完成时才在底部显示动画
                            HStack(spacing: 5) {
                                ForEach(0..<3) { i in
                                    Circle()
                                        .fill(Color.gray.opacity(0.7))
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(dotAnimations[i] ? 1.3 : 0.7)
                                        .offset(y: dotAnimations[i] ? -4 : 2)
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.top, 4)
                            .transition(.opacity)
                        }
                        
                        // AI消息完成后显示操作按钮（非系统提示词）
                        if !isUser && isComplete && !message.isEmpty && !isSystemPrompt {
                            HStack(spacing: 16) {
                                Button(action: {
                                    UIPasteboard.general.string = message
                                    // 显示复制成功提示
                                    withAnimation {
                                        showCopyToast = true
                                    }
                                    // 2秒后自动隐藏提示
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            showCopyToast = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 12))
                                        Text("复制")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.gray)
                                }
                                
                                Button(action: {
                                    let activityVC = UIActivityViewController(
                                        activityItems: [message],
                                        applicationActivities: nil
                                    )
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootVC = window.rootViewController {
                                        rootVC.present(activityVC, animated: true)
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 12))
                                        Text("分享")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.gray)
                                }
                                
                                Button(action: {
                                    // 重新生成：回退到用户发送消息之前的上下文并重新发送
                                    withAnimation {
                                        showButtons = false // 隐藏按钮
                                    }
                                    // 延迟调用以便动画完成
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onRegenerate?()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                        Text("重新生成")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.top, -20)
                            .padding(.bottom, 4)
                            .opacity(showButtons ? 1 : 0)
                            .offset(y: showButtons ? 0 : 10)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .opacity(showMessage ? 1 : 0)
                    .offset(y: showMessage ? 0 : 10)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(
            // 复制成功提示
            Group {
                if showCopyToast {
                    VStack {
                        Text("已复制到剪贴板")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.7))
                            )
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showCopyToast)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        )
        // 重新生成确认弹窗
        .alert("重新生成", isPresented: $showRegenerateConfirm) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                onRegenerate?()
            }
        } message: {
            Text(isUser ? "确定要重新发送此消息吗？" : "确定要重新生成回复吗？")
        }
        .onAppear {
            parsedContent = MarkdownParser.parseMarkdown(message, isUserMessage: isUser)
            // 消息出现动画
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)) {
                showMessage = true
            }
            
            // 启动打字指示器动画
            if !isUser && !isComplete {
                startTypingAnimation()
            }
            
            // 如果是AI消息且已完成且非系统提示词，显示按钮
            if !isUser && isComplete && !message.isEmpty && !isSystemPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showButtons = true
                    }
                }
            }
        }
        .onChange(of: message) { newMessage in
            withAnimation(.easeInOut(duration: 0.2)) {
                parsedContent = MarkdownParser.parseMarkdown(newMessage, isUserMessage: isUser)
            }
        }
        .onChange(of: isComplete) { newValue in
            if newValue {
                // 停止动画
                stopTypingAnimation()
                
                // 如果是AI消息且有内容且非系统提示词，显示按钮
                if !isUser && !message.isEmpty && !isSystemPrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showButtons = true
                        }
                    }
                }
            } else if !isUser {
                // 如果是非完成且是AI消息，启动动画
                startTypingAnimation()
                showButtons = false
            }
        }
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = message
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }

            Button(action: {
                let activityVC = UIActivityViewController(
                    activityItems: [message],
                    applicationActivities: nil
                )

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    // 启动打字动画
    private func startTypingAnimation() {
        // 确保先重置所有点的状态
        for i in 0..<dotAnimations.count {
            dotAnimations[i] = false
        }
        
        // 分别为三个点设置动画定时器
        for i in 0..<dotAnimations.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                animateDot(at: i)
            }
        }
    }
    
    // 停止打字动画
    private func stopTypingAnimation() {
        // 重置所有点的状态
        for i in 0..<dotAnimations.count {
            dotAnimations[i] = false
        }
    }
    
    // 为单个点执行动画
    private func animateDot(at index: Int) {
        guard !isComplete else { return }
        
        // 执行上弹动画
        withAnimation(.easeOut(duration: 0.3)) {
            dotAnimations[index] = true
        }
        
        // 执行下落动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !isComplete else { return }
            
            withAnimation(.easeIn(duration: 0.3)) {
                dotAnimations[index] = false
            }
            
            // 循环动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard !isComplete else { return }
                animateDot(at: index)
            }
        }
    }
}

// 自定义形状以创建不同的圆角
struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// 预览
struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MessageBubble(message: "Hello, how are you?", isUser: true, isComplete: true)
            
            // 系统提示词（无按钮）
            MessageBubble(message: "你好！我是DeepSeek AI助手，请问有什么我可以帮你的吗？", 
                         isUser: false, 
                         isComplete: true, 
                         isSystemPrompt: true)
            
            // 普通AI消息（有按钮）
            MessageBubble(message: "Here's some information you requested.", 
                         isUser: false, 
                         isComplete: true, 
                         onRegenerate: {
                             print("Regenerate message")
                         })
        }
        .padding()
    }
} 

