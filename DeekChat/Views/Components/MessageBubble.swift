import SwiftUI

struct MessageBubble: View {
    let message: String
    let isUser: Bool
    let isComplete: Bool
    let isSystemPrompt: Bool
    let reasoningContent: String?

    @State private var parsedContent: AttributedString = AttributedString("")
    @State private var showMessage = false
    @State private var typingProgress = 0.0
    @State private var dotAnimations: [Bool] = [false, false, false]
    @State private var showButtons = false
    @State private var showCopyToast = false
    @State private var showRegenerateConfirm = false
    @State private var isReasoningComplete = false
    @State private var hasMainContent = false

    // 重新生成的回调
    var onRegenerate: (() -> Void)?

    // 初始化器增加默认参数
    init(message: String, isUser: Bool, isComplete: Bool, isSystemPrompt: Bool = false, reasoningContent: String? = nil, onRegenerate: (() -> Void)? = nil) {
        self.message = message
        self.isUser = isUser
        self.isComplete = isComplete
        self.isSystemPrompt = isSystemPrompt
        self.reasoningContent = reasoningContent
        self.onRegenerate = onRegenerate
    }

    // 固定背景亮度值
    private let backgroundBrightness: Double = 1.0

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
                        // 修改逻辑：先检查是否有推理内容，如果有则始终显示推理内容
                        VStack(alignment: .leading, spacing: 0) { // 完全移除元素间的间距
                            // 显示推理内容（如果有）- 修改：即使消息还未完成也显示推理过程
                            if let reasoning = reasoningContent, !reasoning.isEmpty {
                                ReasoningView(
                                    reasoningContent: reasoning,
                                    isReasoningComplete: $isReasoningComplete,
                                    hasMainContent: $hasMainContent
                                )
                                    .padding(.top, 2) // 保持较小的顶部内边距
                                    .padding(.bottom, -10) // 显著增加负值，大幅减小间距
                                    .padding(.horizontal, 6) // 稍微缩进，增强层次感
                            }

                            // 如果消息为空且未完成，显示动画点
                            if message.isEmpty && !isComplete && (reasoningContent == nil || reasoningContent!.isEmpty) {
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
                            }

                            // AI消息内容 - 使用专门的渲染组件
                            if !message.isEmpty {
                                MarkdownContentView(
                                    content: message,
                                    parsedContent: parsedContent
                                )
                                .padding(.horizontal, 16)
                                // 使用负值顶部间距进一步减小间距
                                .padding(.top, reasoningContent != nil && !reasoningContent!.isEmpty ? -15 : 8) // 有思考过程时使用负值减小间距，没有时保留较大间距
                                .padding(.bottom, 8)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                        .onLongPressGesture {
                            // 长按AI消息触发重新生成
                            if !isSystemPrompt && isComplete && onRegenerate != nil {
                                showRegenerateConfirm = true
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
        .padding(.vertical, reasoningContent != nil && !reasoningContent!.isEmpty ? 8 : 4) // 有思考过程时增加垂直间距
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

            // 设置推理状态
            isReasoningComplete = isComplete

            // 初始化主内容状态
            hasMainContent = !message.isEmpty

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

                // 当消息内容不为空时，更新hasMainContent状态
                if !newMessage.isEmpty {
                    hasMainContent = true

                    // 当主内容开始出现时，将推理过程标记为完成，停止动画
                    isReasoningComplete = true
                }
            }
        }
        .onChange(of: isComplete) { newValue in
            if newValue {
                // 停止动画
                stopTypingAnimation()

                // 更新推理完成状态
                isReasoningComplete = true

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

                // 推理未完成
                isReasoningComplete = false
            }
        }
        .onChange(of: reasoningContent) { newReasoning in
            // 当推理内容更新时，确保推理区域可见
            if newReasoning != nil && !newReasoning!.isEmpty {
                // 确保在有内容时UI立即响应
                DispatchQueue.main.async {
                    withAnimation(.easeIn(duration: 0.1)) {
                        // 推理内容存在但未完成
                        // 如果有主内容或消息已完成，则推理也应该标记为完成
                        isReasoningComplete = isComplete || hasMainContent || !message.isEmpty

                        // 确保消息显示（即使主内容为空）
                        if !showMessage {
                            showMessage = true
                        }
                    }
                }
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

