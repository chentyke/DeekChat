import SwiftUI

struct ReasoningView: View {
    let reasoningContent: String
    @State private var isExpanded: Bool = true
    @Binding var isReasoningComplete: Bool
    @Binding var hasMainContent: Bool

    // 添加思考动画状态
    @State private var typingAnimation = false
    // 添加可见性状态，确保内容一开始就显示
    @State private var isVisible: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { // 添加微小间距
            // 标题栏（可点击展开/折叠）
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    // 标题和箭头放在一起，靠左排列
                    HStack(spacing: 2) {
                        Text("思考过程")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // 添加思考动画点，在推理未完成时显示
                    if !isReasoningComplete {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.gray.opacity(0.7))
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(typingAnimation ? 1.2 : 0.8)
                                    .animation(
                                        Animation.easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(Double(i) * 0.2),
                                        value: typingAnimation
                                    )
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
            }

            // 推理内容（可折叠）
            if isExpanded {
                Text(reasoningContent)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: reasoningContent) // 添加内容变化动画
            }
        }
        .opacity(isVisible ? 1 : 0) // 确保整个视图可见
        .onChange(of: reasoningContent) { newContent in
            // 当推理内容更新时，确保列表展开并且视图可见
            if !newContent.isEmpty {
                // 立即确保视图可见
                if !isVisible {
                    withAnimation(.easeIn(duration: 0.1)) {
                        isVisible = true
                    }
                }

                // 确保列表展开
                if !isExpanded {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = true
                    }
                }

                // 确保动画激活
                if !typingAnimation && !isReasoningComplete {
                    typingAnimation = true
                }
            }
        }
        .onAppear {
            // 启动思考动画并强制展开视图
            if !isReasoningComplete {
                typingAnimation = true
                isVisible = true
                if !isExpanded {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = true
                    }
                }
            }
        }
        .onChange(of: isReasoningComplete) { complete in
            // 如果推理完成，停止动画但保持展开状态
            if complete {
                // 立即停止动画
                withAnimation(.easeOut(duration: 0.2)) {
                    typingAnimation = false
                }
            } else {
                // 如果从完成变为非完成（继续流式输出），重新启动动画
                withAnimation(.easeIn(duration: 0.2)) {
                    typingAnimation = true
                    isVisible = true
                }
                if !isExpanded {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = true
                    }
                }
            }
        }
        .onChange(of: hasMainContent) { hasContent in
            // 当主内容开始出现时，自动折叠推理过程并停止动画
            if hasContent {
                // 停止动画
                withAnimation(.easeOut(duration: 0.2)) {
                    typingAnimation = false
                }

                // 折叠推理过程
                if isExpanded {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded = false
                    }
                }
            }
        }
    }
}

// 预览
struct ReasoningView_Previews: PreviewProvider {
    static var previews: some View {
        ReasoningView(
            reasoningContent: "这是一段推理内容，展示模型的思考过程...",
            isReasoningComplete: .constant(false),
            hasMainContent: .constant(false)
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
