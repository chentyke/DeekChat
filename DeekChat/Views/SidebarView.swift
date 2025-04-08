import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var hoveredChatId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            HStack {
                Text("DeChat")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 新建对话按钮
            Button(action: {
                if let current = viewModel.currentChat, current.messages.contains(where: { $0.isUser }) {
                    withAnimation(.spring(response: 0.4)) {
                        viewModel.createNewChat()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("新对话")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(0.7))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Divider()
                .padding(.horizontal, 16)
            
            // 聊天列表
            ScrollView {
                VStack(spacing: 1) {
                    // 当前对话
                    if let currentChat = viewModel.currentChat, !currentChat.messages.isEmpty {
                        chatItemView(chat: currentChat, isActive: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 历史记录
                    if !viewModel.chatHistory.isEmpty {
                        Text("历史记录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                        
                        ForEach(viewModel.chatHistory) { chat in
                            chatItemView(chat: chat, isActive: viewModel.currentChat?.id == chat.id)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            Divider()
                .padding(.horizontal, 16)
            
            // 设置按钮
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("设置")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(ScaleButtonStyle())
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    SettingsView()
                        .navigationBarItems(trailing: Button("完成") {
                            showingSettings = false
                        })
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // 聊天项目视图
    private func chatItemView(chat: Chat, isActive: Bool) -> some View {
        Button(action: {
            if !isActive {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.loadChat(chat)
                }
                if UIDevice.current.userInterfaceIdiom == .phone {
                    dismiss()
                }
            }
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isActive ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.title)
                        .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                    
                    if let firstUserMessage = chat.messages.first(where: { $0.isUser }) {
                        Text(firstUserMessage.content)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isActive || hoveredChatId == chat.id {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                        .opacity(0.6)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.blue.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 8)
            )
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hoveredChatId = isHovered ? chat.id : nil
                }
            }
        }
        .buttonStyle(SidebarButtonStyle(isActive: isActive))

        // 添加上下文菜单:
        .contextMenu {
            Button(action: {
                withAnimation {
                    viewModel.deleteChat(chat)
                }
            }) {
                Label("删除对话", systemImage: "trash")
            }
        }
    }
}

// 侧边栏按钮样式
struct SidebarButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.15) : Color.clear)
                    .padding(.horizontal, 8)
            )
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
} 
