import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 添加录音和语音识别相关的框架
import AVFoundation
import Speech
import PhotosUI

struct MainView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSidebar = false
    @State private var messageText = ""
    @State private var showingFileImporter = false
    @State private var editingTitle: String = "新对话"
    @State private var errorMessage: String? = nil
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var showSendButton = false
    @State private var isScrolledToBottom = true
    @FocusState private var isInputActive: Bool
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary

    // 添加录音相关状态
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var recordingFileName: URL?

    // 添加一个自定义上传选项弹窗的状态
    @State private var showingCustomUploadOptions = false

    // 添加保存按钮位置的状态
    @State private var attachmentButtonPosition: CGRect = .zero

    // 添加状态变量来跟踪当前的拖动手势
    @GestureState private var dragOffset: CGFloat = 0

    // 添加一个状态变量来跟踪侧边栏的当前位置，用于平滑动画
    @State private var sidebarOffset: CGFloat = -270

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(.systemBackground)
                    .ignoresSafeArea()

                // 主聊天界面
                VStack(spacing: 0) {
                    // 顶部导航栏
                    topNavigationBar
                        .background(.ultraThinMaterial)
                        .zIndex(1)

                    // 聊天内容区域
                    chatContentArea

                    // 底部输入框 - 更现代的设计
                    inputBar
                }
                // 添加从左向右滑动的手势识别器
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            // 只处理从左边缘开始的滑动，且仅当侧边栏关闭时
                            if !showingSidebar && value.startLocation.x < 20 && value.translation.width > 0 {
                                // 限制最大偏移量为270，防止超出侧边栏宽度
                                state = min(value.translation.width, 270)
                            }
                        }
                        .onEnded { value in
                            // 如果滑动足够远，则显示侧边栏，且仅当侧边栏关闭时
                            if !showingSidebar && value.startLocation.x < 20 && value.translation.width > 0 {
                                // 计算拖动结束时的位置
                                let currentPosition = sidebarOffset + value.translation.width

                                // 如果拖动超过一半或者超过50点，则打开侧边栏
                                let shouldOpen = currentPosition > -135 || value.translation.width > 50

                                // 更新状态并使用动画从当前位置平滑过渡
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)) {
                                    showingSidebar = shouldOpen
                                    sidebarOffset = shouldOpen ? 0 : -270
                                }
                            }
                        }
                )

                // 侧边栏覆盖层和侧边栏
                sidebarLayer

                // 错误提示覆盖层
                errorOverlay

                // 滚动到底部浮动按钮
                scrollToBottomButton

                // 左边缘滑动指示器，当侧边栏关闭时显示
                if !showingSidebar {
                    HStack(spacing: 0) {
                        // 左边缘指示器
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 5)
                            .opacity(dragOffset > 0 ? 1.0 : 0.0) // 当拖动时显示

                        Spacer()
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false) // 不拦截点击事件
                }

                // 修改自定义上传弹窗显示方式
                if showingCustomUploadOptions {
                    // 创建一个引用变量来存储FloatingMenuView
                    let menuView = FloatingMenuView(
                        isShowing: $showingCustomUploadOptions,
                        attachPoint: attachmentButtonPosition,
                        onCamera: {
                            // 在主线程上安全地检查相机
                            DispatchQueue.main.async {
                                // 检查相机是否可用
                                if ImagePicker.isCameraAvailable() {
                                    // 检查相机权限
                                    ImagePicker.checkCameraPermission { granted in
                                        DispatchQueue.main.async {
                                            if granted {
                                                sourceType = .camera
                                                showingImagePicker = true
                                            } else {
                                                showError("需要相机权限才能拍照")
                                            }
                                        }
                                    }
                                } else {
                                    showError("设备不支持相机功能")
                                }
                            }
                        },
                        onPhotoLibrary: {
                            // 安全地设置状态
                            DispatchQueue.main.async {
                                sourceType = .photoLibrary
                                showingImagePicker = true
                            }
                        },
                        onFile: {
                            // 安全地设置状态
                            DispatchQueue.main.async {
                                showingFileImporter = true
                            }
                        },
                        onClose: {
                            // 菜单关闭后的回调
                            // 这里可以添加额外的处理逻辑
                        }
                    )

                    // 显示菜单
                    menuView
                        .transition(.opacity)
                        .zIndex(100) // 确保显示在最上层
                }
            }
            .environmentObject(viewModel)
            .onChange(of: inputImage) { newImage in
                if let image = newImage {
                    handleImageSelected(image)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleFileImport(url: url)
                    }
                case .failure(let error):
                    showError("文件导入失败: \(error.localizedDescription)")
                }
            }
            .overlayPreferenceValue(ViewPositionKey.self) { preferences in
                GeometryReader { geometry in
                    if let anchor = preferences.first(where: { $0.viewId == "attachmentButton" }) {
                        Color.clear.onAppear {
                            let rect = geometry[anchor.anchor]
                            let globalRect = CGRect(
                                x: rect.minX,
                                y: rect.minY,
                                width: rect.width,
                                height: rect.height
                            )
                            attachmentButtonPosition = globalRect
                        }
                    }
                }
            }
        }
    }

    // MARK: - UI Components

    private var topNavigationBar: some View {
        HStack(spacing: 16) {
            // 侧边栏按钮
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)) {
                    showingSidebar.toggle()
                    // 同时更新侧边栏偏移量
                    sidebarOffset = showingSidebar ? 0 : -270
                }
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6).opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            // 标题编辑区域
            if viewModel.isEditingTitle {
                titleEditingMode
            } else {
                titleDisplayMode
            }

            Spacer()

            // 新建对话按钮
            Button(action: {
                if let currentChat = viewModel.currentChat, currentChat.messages.contains(where: { $0.isUser }) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        viewModel.createNewChat()
                        editingTitle = "新对话"
                    }
                } else {
                    showError("请先发送消息再创建新对话")
                }
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6).opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                .ignoresSafeArea(.all, edges: .top)
        )
    }

    private var titleEditingMode: some View {
        HStack(spacing: 8) {
            TextField("对话名称", text: $editingTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .frame(width: 150)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 1.05).combined(with: .opacity)
                ))

            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.4)) {
                        viewModel.updateChatTitle(editingTitle)
                        viewModel.isEditingTitle = false
                    }
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: {
                    withAnimation(.spring(response: 0.4)) {
                        editingTitle = viewModel.currentChat?.title ?? "新对话"
                        viewModel.isEditingTitle = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .transition(.scale.combined(with: .opacity))
        }
        .frame(height: 38)
    }

    private var titleDisplayMode: some View {
        Button(action: {
            editingTitle = viewModel.currentChat?.title ?? "新对话"
            withAnimation(.spring(response: 0.4)) {
                viewModel.isEditingTitle = true
            }
        }) {
            HStack {
                Text(viewModel.currentChat?.title ?? "新对话")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)

                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemGray6).opacity(0.8))
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .transition(.scale)
    }

    private var chatContentArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let chat = viewModel.currentChat {
                        // 时间标签
                        timeLabel

                        // 消息列表
                        ForEach(chat.messages) { message in
                            MessageBubble(
                                message: message.content,
                                isUser: message.isUser,
                                isComplete: message.isComplete,
                                isSystemPrompt: message.isSystemPrompt,
                                reasoningContent: message.reasoningContent,
                                onRegenerate: {
                                    if message.isUser {
                                        viewModel.resendUserMessage(message.content)
                                    } else {
                                        viewModel.regenerateAIResponse(for: message.id)
                                    }
                                }
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                        }

                        // 底部留白
                        Color.clear
                            .frame(height: 20)
                            .id("bottomScrollAnchor")
                    }
                }
                .padding(.horizontal, 4)
                .animation(.easeInOut(duration: 0.2), value: viewModel.currentChat?.messages.map { $0.id })
            }
            .background(Color(.systemBackground))
            .onTapGesture {
                isInputActive = false
            }
            .onAppear {
                scrollViewProxy = proxy
                // 初始滚动到底部
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        proxy.scrollTo("bottomScrollAnchor", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.currentChat?.messages) { _ in
                if isScrolledToBottom {
                    // 如果已经在底部，则自动滚动到新消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottomScrollAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    // 在拖动过程中检测是否在底部
                    DispatchQueue.main.async {
                        if let scrollView = proxy as? UIScrollView {
                            let bottomEdge = scrollView.contentSize.height - scrollView.bounds.height
                            isScrolledToBottom = scrollView.contentOffset.y >= bottomEdge - 50
                        }
                    }
                }
            )
        }
    }

    private var timeLabel: some View {
        HStack {
            Spacer()
            Text("今天")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6).opacity(0.7))
                )
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // 底部输入栏
    private var inputBar: some View {
        ChatInputBar(
            messageText: $messageText,
            isInputActive: $isInputActive,
            isRecording: $isRecording,
            showSendButton: $showSendButton,
            isGenerating: viewModel.activeChat != nil,
            onAttachmentTap: showAttachmentOptions,
            onSendTap: sendMessage,
            onRecordTap: startRecording,
            onCancelTap: cancelGeneration,
            showingImagePicker: $showingImagePicker,
            inputImage: $inputImage,
            sourceType: $sourceType
        )
    }

    // 获取安全区域内边距
    private var safeAreaInsets: UIEdgeInsets {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first

        return keyWindow?.safeAreaInsets ?? .zero
    }

    private var sidebarLayer: some View {
        ZStack {
            // 侧边栏覆盖层 - 使用透明度而不是条件渲染
            Color.black
                .opacity(showingSidebar ? 0.2 : 0)
                .ignoresSafeArea()
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1), value: showingSidebar)
                .allowsHitTesting(showingSidebar) // 只在显示时响应点击
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)) {
                        showingSidebar = false
                        sidebarOffset = -270 // 同时更新侧边栏偏移量
                    }
                }

            // 监听侧边栏状态变化，更新偏移量
            Color.clear
                .frame(width: 0, height: 0)
                .onChange(of: showingSidebar) { newValue in
                    // 当侧边栏状态变化时，更新偏移量
                    // 注意：这里不使用动画，因为动画应该在触发状态变化的地方应用
                    sidebarOffset = newValue ? 0 : -270
                }

            // 侧边栏
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 侧边栏容器
                    ZStack {
                        // 侧边栏背景
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 2, y: 0)
                            .ignoresSafeArea()

                        // 侧边栏内容 - 使用id确保不会重新创建
                        SidebarView()
                            .environmentObject(viewModel)
                            .id("sidebarContent") // 添加固定id防止重新创建
                    }
                    .frame(width: 270)
                    // 使用sidebarOffset状态变量和当前拖动偏移量来计算侧边栏位置
                    .offset(x: sidebarOffset + dragOffset)
                    // 添加从右向左滑动关闭的手势
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // 在拖动过程中不做额外处理，偏移量已经在dragOffset中跟踪
                            }
                            .onEnded { value in
                                // 计算拖动结束时的位置
                                let currentPosition = sidebarOffset + value.translation.width

                                // 根据当前位置和拖动方向决定是否应该打开或关闭侧边栏
                                let shouldOpen: Bool
                                if showingSidebar {
                                    // 如果侧边栏已经打开，只有向左拖动超过一半才关闭
                                    shouldOpen = currentPosition > -135
                                } else {
                                    // 如果侧边栏关闭，只有向右拖动超过一半才打开
                                    shouldOpen = currentPosition > -135
                                }

                                // 更新状态并使用动画从当前位置平滑过渡
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)) {
                                    showingSidebar = shouldOpen
                                    sidebarOffset = shouldOpen ? 0 : -270
                                }
                            }
                    )

                    Spacer()
                }
                // 将动画仅应用于偏移属性，而不是整个视图
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1), value: sidebarOffset)
            }
        }
    }

    private var errorOverlay: some View {
        Group {
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.8))
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        )
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
    }

    private var scrollToBottomButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if !isScrolledToBottom {
                    Button(action: {
                        withAnimation {
                            scrollViewProxy?.scrollTo("bottomScrollAnchor", anchor: .bottom)
                            isScrolledToBottom = true
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.trailing, 16)
                    .padding(.bottom, 80)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 录音与语音识别功能

    // 请求录音权限
    private func requestRecordingPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    showError("需要录音权限才能使用语音输入功能")
                }
            }
        }
    }

    // 请求语音识别权限
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    showError("需要语音识别权限才能使用语音输入功能")
                }
            }
        }
    }

    // 开始录音
    private func startRecording() {
        // 确保没有正在进行的录音
        if isRecording {
            stopRecording()
            return
        }

        // 检查麦克风权限和语音识别权限
        checkPermissionsAndStartRecording()
    }

    // 检查权限并开始录音
    private func checkPermissionsAndStartRecording() {
        // 检查麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { granted in

            if !granted {
                DispatchQueue.main.async {
                    self.showError("需要麦克风权限才能使用语音输入功能")
                }
                return
            }

            // 检查语音识别权限
            SFSpeechRecognizer.requestAuthorization { status in

                DispatchQueue.main.async {
                    if status != .authorized {
                        self.showError("需要语音识别权限才能使用语音输入功能")
                        return
                    }

                    // 权限都已授予，开始录音
                    self.startRecordingWithPermission()
                }
            }
        }
    }

    // 已获得权限后开始录音
    private func startRecordingWithPermission() {
        // 设置为录音状态
        withAnimation {
            isRecording = true
        }

        // 设置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            showError("无法设置音频会话: \(error.localizedDescription)")
            return
        }

        // 检查语音识别器是否可用
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            showError("语音识别服务当前不可用")
            isRecording = false
            return
        }

        // 设置语音识别
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            showError("无法创建语音识别请求")
            isRecording = false
            return
        }

        // 配置实时听写
        recognitionRequest.shouldReportPartialResults = true

        // 开始语音识别
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in

            if let result = result {
                // 更新语音识别结果到输入框
                DispatchQueue.main.async {
                    self.messageText = result.bestTranscription.formattedString
                }
            }

            if error != nil {
                // 停止录音
                DispatchQueue.main.async {
                    self.stopRecording()
                }
            }
        }

        // 准备音频引擎
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // 开始音频引擎
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            showError("无法开始录音: \(error.localizedDescription)")
            isRecording = false
            return
        }
    }

    // 停止录音
    private func stopRecording() {
        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // 结束语音识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // 重置录音状态
        withAnimation {
            isRecording = false
        }

        // 显示发送按钮（如果识别出了文本）
        if !messageText.isEmpty {
            withAnimation(.spring(response: 0.4)) {
                showSendButton = true
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 如果正在录音，先停止录音
        if isRecording {
            stopRecording()
        }

        let messageToSend = messageText  // 保存消息内容

        // 使用Task以避免UI更新之间的竞争条件
        Task {
            // 在主线程上更新UI
            await MainActor.run {
                messageText = ""  // 清空输入框
                withAnimation(.spring(response: 0.4)) {
                    showSendButton = false
                }
            }

            do {
                try await viewModel.sendMessage(messageToSend)
                // 发送消息后自动滚动到底部
                await MainActor.run {
                    withAnimation {
                        scrollViewProxy?.scrollTo("bottomScrollAnchor", anchor: .bottom)
                        isScrolledToBottom = true
                    }
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func handleImageSelected(_ image: UIImage) {
        // 重置图片选择状态
        inputImage = nil

        // 保存图片到临时文件
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            showError("图片处理失败")
            return
        }

        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: tempURL)
            // 处理图片文件的上传或发送
            handleFileImport(url: tempURL)
        } catch {
            showError("图片保存失败: \(error.localizedDescription)")
        }
    }

    private func handleFileImport(url: URL) {
        // 处理文件导入逻辑
        print("导入的文件路径: \(url.path)")

        // 获取文件名
        let fileName = url.lastPathComponent

        // 判断文件类型
        let isImage = ["jpg", "jpeg", "png", "gif", "heic"].contains(url.pathExtension.lowercased())
        let isPDF = url.pathExtension.lowercased() == "pdf"

        // 简单文件类型图标
        let fileIcon = isImage ? "📷" : (isPDF ? "📄" : "📎")

        // 构建文件消息
        let fileMessage = "\(fileIcon) 文件: \(fileName)\n正在处理文件，请稍候..."

        // 将文件信息作为消息发送
        messageText = fileMessage
        sendMessage()

        // 实际实现中，这里应该上传文件到服务器或进行其他处理
        // 例如：uploadFileToServer(url: url)
    }

    private func showError(_ message: String) {
        withAnimation(.spring(response: 0.4)) {
            errorMessage = message
        }
        // 3秒后自动隐藏错误消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.spring(response: 0.4)) {
                errorMessage = nil
            }
        }
    }

    // 取消生成功能
    private func cancelGeneration() {
        Task {
            await viewModel.cancelMessageGeneration()

            // 添加一个短暂延迟后更新UI状态
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

            // 更新UI状态，允许用户立即发送新消息
            await MainActor.run {
                showError("已停止生成")
            }
        }
    }

    // 显示附件选项
    private func showAttachmentOptions() {
        showingCustomUploadOptions = true
    }
}

// MARK: - 自定义按钮样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - 聊天输入栏
struct ChatInputBar: View {
    @Binding var messageText: String
    @FocusState.Binding var isInputActive: Bool
    @Binding var isRecording: Bool
    @Binding var showSendButton: Bool
    let isGenerating: Bool

    let onAttachmentTap: () -> Void
    let onSendTap: () -> Void
    let onRecordTap: () -> Void
    let onCancelTap: () -> Void

    @Binding var showingImagePicker: Bool
    @Binding var inputImage: UIImage?
    @Binding var sourceType: UIImagePickerController.SourceType

    // 读取安全区域但不响应其变化
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    // 状态变量跟踪输入区域高度
    @State private var inputAreaHeight: CGFloat = 56

    // 固定尺寸常量
    private let minInputBarHeight: CGFloat = 56
    private let maxInputBarHeight: CGFloat = 140
    private let cornerRadius: CGFloat = 25

    var body: some View {
        // 使用ZStack而不是GeometryReader避免尺寸自适应
        ZStack(alignment: .bottom) {
            // 录音指示器 (有条件显示)
            if isRecording {
                VStack(spacing: 0) {
                    recordingIndicator
                        .padding(.bottom, 8)
                    Spacer()
                }
                .frame(height: 64) // 固定录音指示器高度
                .offset(y: -inputAreaHeight - (safeAreaInsets?.bottom ?? 0))
            }

            // 主输入栏
            VStack(spacing: 0) {
                // 内容区域
                HStack(spacing: 12) {
                    // 左侧附件按钮
                    AttachmentButton(
                        onTap: onAttachmentTap,
                        isDisabled: isGenerating,
                        showingImagePicker: $showingImagePicker,
                        inputImage: $inputImage,
                        sourceType: $sourceType
                    )

                    // 中间输入框
                    InputTextField(
                        text: $messageText,
                        isInputActive: $isInputActive,
                        isGenerating: isGenerating,
                        showSendButton: $showSendButton
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.onChange(of: geo.size.height) { newHeight in
                                // 当输入框高度变化时，更新整体区域高度
                                let calculatedHeight = newHeight + 20 // 添加内边距
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    inputAreaHeight = max(minInputBarHeight, min(calculatedHeight, maxInputBarHeight))
                                }
                            }
                        }
                    )

                    // 右侧按钮区域
                    ActionButton(
                        isGenerating: isGenerating,
                        messageText: messageText,
                        showSendButton: showSendButton,
                        onSendTap: onSendTap,
                        onRecordTap: onRecordTap,
                        onCancelTap: onCancelTap
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(height: inputAreaHeight) // 根据输入内容动态调整高度

                // 底部安全区域填充
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: safeAreaInsets?.bottom ?? 0)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -3)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 20) // 稍微上移输入框位置
        }
        .frame(height: inputAreaHeight + (safeAreaInsets?.bottom ?? 0) + (isRecording ? 64 : 0))
        .background(Color.clear)
        .ignoresSafeArea(.keyboard) // 忽略键盘防止自动调整
        .animation(.easeInOut(duration: 0.2), value: inputAreaHeight)
    }

    // 录音指示器
    private var recordingIndicator: some View {
        VStack(spacing: 10) {
            // 波形动画增强
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 4, height: 15 + CGFloat.random(in: 5...25))
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: isRecording
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 0)
                }

                Text("正在录音...")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.leading, 10)

                Spacer()

                // 改进停止按钮样式
                Button(action: onRecordTap) {
                    Label("停止", systemImage: "stop.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .contentShape(Capsule())
            }

            // 添加动态计时器
            HStack {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Circle().fill(Color.blue.opacity(0.1)))

                Spacer()

                // 在实际实现中，这里可以添加一个计时器显示录音时长
                Text("点击停止结束录音")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 聊天输入栏组件
// 附件按钮
struct AttachmentButton: View {
    let onTap: () -> Void
    let isDisabled: Bool

    @Binding var showingImagePicker: Bool
    @Binding var inputImage: UIImage?
    @Binding var sourceType: UIImagePickerController.SourceType

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.blue)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .sheet(isPresented: $showingImagePicker) {
            // 在显示ImagePicker前检查相机可用性
            Group {
                if sourceType == .camera && !ImagePicker.isCameraAvailable() {
                    // 如果相机不可用，显示错误提示
                    VStack {
                        Text("设备不支持相机功能")
                            .font(.headline)
                            .padding()

                        Button("使用相册代替") {
                            DispatchQueue.main.async {
                                sourceType = .photoLibrary
                            }
                        }
                        .padding()

                        Button("取消") {
                            DispatchQueue.main.async {
                                showingImagePicker = false
                            }
                        }
                        .padding()
                    }
                    .padding()
                } else {
                    ImagePicker(image: $inputImage, sourceType: sourceType)
                        .ignoresSafeArea()
                }
            }
        }
        // 传递位置给弹窗
        .anchorPreference(key: ViewPositionKey.self, value: .bounds) { anchor in
            return [ViewPositionAnchor(viewId: "attachmentButton", anchor: anchor)]
        }
    }
}

// 操作按钮（发送/麦克风/取消）
struct ActionButton: View {
    let isGenerating: Bool
    let messageText: String
    let showSendButton: Bool
    let onSendTap: () -> Void
    let onRecordTap: () -> Void
    let onCancelTap: () -> Void

    var body: some View {
        Group {
            if isGenerating {
                // 取消生成按钮
                Button(action: onCancelTap) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .transition(.scale)
            } else {
                // 发送/麦克风按钮
                Button(action: {
                    if messageText.isEmpty {
                        onRecordTap()
                    } else {
                        onSendTap()
                    }
                }) {
                    Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .scaleEffect(showSendButton ? 1 : 0.9)
                .animation(.spring(response: 0.4), value: messageText.isEmpty)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// 添加环境键以提供安全区域内边距
struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: UIEdgeInsets? = nil
}

extension EnvironmentValues {
    var safeAreaInsets: UIEdgeInsets? {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

// 添加Introspect扩展(仅添加文本视图扩展)
extension View {
    func introspectTextView(customize: @escaping (UITextView) -> ()) -> some View {
        return inject(UIKitIntrospectionView(
            selector: { introspectionView in
                guard let viewHost = Introspection.findViewHost(from: introspectionView) else {
                    return nil
                }

                // 查找TextEditor的UITextView
                for subview in viewHost.subviews {
                    if let textView = Introspection.findTextView(from: subview) {
                        return textView
                    }
                }
                return nil
            },
            customize: customize
        ))
    }
}

// 简化的Introspection实现
struct Introspection {
    static func findViewHost(from introspectionView: UIView) -> UIView? {
        var superview = introspectionView.superview
        while let s = superview {
            // 查找符合视图宿主特征的视图
            if NSStringFromClass(type(of: s)).contains("ViewHost") {
                return s
            }
            superview = s.superview
        }
        return nil
    }

    static func findTextView(from view: UIView) -> UITextView? {
        if let textView = view as? UITextView {
            return textView
        }

        for subview in view.subviews {
            if let textView = findTextView(from: subview) {
                return textView
            }
        }

        return nil
    }
}

// UIKit视图注入器
struct UIKitIntrospectionView<ViewType: UIView>: UIViewRepresentable {
    let selector: (UIView) -> ViewType?
    let customize: (ViewType) -> Void

    init(selector: @escaping (UIView) -> ViewType?, customize: @escaping (ViewType) -> Void) {
        self.selector = selector
        self.customize = customize
    }

    func makeUIView(context: Context) -> IntrospectionUIView {
        let view = IntrospectionUIView()
        view.selector = selector
        view.customize = customize
        return view
    }

    func updateUIView(_ uiView: IntrospectionUIView, context: Context) {
        uiView.selector = selector
        uiView.customize = customize
    }

    class IntrospectionUIView: UIView {
        var selector: ((UIView) -> ViewType?)?
        var customize: ((ViewType) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let selector = selector, let customize = customize else { return }
            guard let targetView = selector(self) else { return }
            customize(targetView)
        }
    }
}

// 视图扩展方法
extension View {
    func inject<V>(_ view: V) -> some View where V: View {
        overlay(view.frame(width: 0, height: 0))
    }
}

// 添加一个自定义上传选项弹窗视图
struct FloatingMenuView: View {
    @Binding var isShowing: Bool
    let attachPoint: CGRect
    let onCamera: () -> Void
    let onPhotoLibrary: () -> Void
    let onFile: () -> Void

    // 添加一个关闭菜单的回调函数
    var onClose: (() -> Void)? = nil

    // 动画状态
    @State private var animationAmount: CGFloat = 0
    @State private var itemAnimations: [Bool] = [false, false, false]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 轻触任意位置关闭菜单的透明层
            Color.black.opacity(0.2 * animationAmount)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 调用关闭菜单方法
                    self.closeMenu()
                }

            // 悬浮菜单内容
            VStack(spacing: 0) {
                // 选项列表
                VStack(spacing: 0) {
                    // 相机选项
                    FloatingMenuButton(
                        icon: "camera.fill",
                        text: "拍照",
                        iconColor: .blue,
                        action: {
                            onCamera()
                        },
                        isActive: itemAnimations[0]
                    )
                    .offset(x: itemAnimations[0] ? 0 : -20)
                    .opacity(itemAnimations[0] ? 1 : 0)

                    Divider()
                        .padding(.horizontal, 6)

                    // 相册选项
                    FloatingMenuButton(
                        icon: "photo.fill",
                        text: "从相册选择",
                        iconColor: .green,
                        action: {
                            onPhotoLibrary()
                            closeMenu()
                        },
                        isActive: itemAnimations[1]
                    )
                    .offset(x: itemAnimations[1] ? 0 : -20)
                    .opacity(itemAnimations[1] ? 1 : 0)

                    Divider()
                        .padding(.horizontal, 6)

                    // 文件选项
                    FloatingMenuButton(
                        icon: "doc.fill",
                        text: "上传文件",
                        iconColor: .orange,
                        action: {
                            onFile()
                            closeMenu()
                        },
                        isActive: itemAnimations[2]
                    )
                    .offset(x: itemAnimations[2] ? 0 : -20)
                    .opacity(itemAnimations[2] ? 1 : 0)
                }
            }
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .opacity(animationAmount)
            .scaleEffect(0.8 + (0.2 * animationAmount), anchor: .bottomLeading)
            .offset(x: max(10, attachPoint.minX - 10), y: attachPoint.minY - 150) // 位置调整，悬浮在按钮上方
            // 添加箭头指示
            .overlay(
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.systemBackground))
                    .offset(x: 16, y: 8)
                    .rotationEffect(.degrees(180))
                    .opacity(animationAmount)
                    , alignment: .bottomLeading
            )
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // 主容器动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animationAmount = 1
            }

            // 错开时间依次显示各个选项
            for i in 0..<itemAnimations.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + Double(i) * 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        itemAnimations[i] = true
                    }
                }
            }
        }
    }

    func closeMenu() {
        // 安全地关闭菜单，确保在主线程上执行
        DispatchQueue.main.async {
            // 反向动画：先淡出选项
            for i in 0..<self.itemAnimations.count {
                withAnimation(.easeOut(duration: 0.1)) {
                    self.itemAnimations[i] = false
                }
            }

            // 然后关闭整个菜单
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.animationAmount = 0
            }

            // 延迟设置状态变量
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isShowing = false

                // 如果有关闭回调，调用它
                self.onClose?()
            }
        }
    }
}

// 增强FloatingMenuButton的动效和视觉样式
struct FloatingMenuButton: View {
    let icon: String
    let text: String
    let iconColor: Color
    let action: () -> Void
    var isActive: Bool = true

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            // 安全地处理按钮点击
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    self.isPressed = true
                }

                // 延迟执行动作
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        self.isPressed = false
                    }
                    // 在主线程上执行操作
                    self.action()
                }
            }
        }) {
            HStack(spacing: 12) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(iconColor)

                            // 添加点击时的涟漪效果
                            if isPressed {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .scaleEffect(isPressed ? 1.8 : 0)
                                    .opacity(isPressed ? 0 : 0.3)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: iconColor.opacity(0.3), radius: 3, x: 0, y: 2)

                // 文字
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Spacer()

                // 右侧箭头图标，轻微动画
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .offset(x: isPressed ? 3 : 0)
                    .animation(.spring(response: 0.3), value: isPressed)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1)
            .opacity(isActive ? 1 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 添加缺失的InputTextField结构体
// 输入文本框
struct InputTextField: View {
    @Binding var text: String
    @FocusState.Binding var isInputActive: Bool
    let isGenerating: Bool
    @Binding var showSendButton: Bool

    // 添加状态变量跟踪文本高度
    @State private var textHeight: CGFloat = 36

    // 最大高度限制
    private let minHeight: CGFloat = 36
    private let maxHeight: CGFloat = 120

    // UITextView代理包装器，用于禁用输入辅助栏和控制滚动行为
    class TextViewDelegate: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        static let shared = TextViewDelegate()

        // 当前关联的TextView
        weak var textView: UITextView?

        // 跟踪文本行数
        private var lineCount: Int = 1
        // 最大行数限制，超过这个数量才允许滚动
        private let maxLinesBeforeScroll: Int = 4
        // 记录是否已经禁用滚动
        private var scrollDisabled = false

        override init() {
            super.init()
        }

        // 设置关联的TextView并初始化
        func setup(with textView: UITextView) {
            self.textView = textView
            updateScrollState(in: textView)
        }

        // 计算文本行数
        func calculateLineCount(in textView: UITextView) -> Int {
            let text = textView.text ?? ""
            if text.isEmpty { return 1 }

            // 防止宽度为0或负数
            let width = max(10, textView.bounds.width)
            let size = CGSize(width: width, height: .infinity)

            // 使用安全的字体
            let font = textView.font ?? UIFont.systemFont(ofSize: 16)

            let textHeight = text.boundingRect(
                with: size,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height

            // 防止高度为NaN或负数
            let safeTextHeight = textHeight.isNaN ? 16 : max(1, textHeight)

            // 根据文本高度和行高度估算行数
            let lineHeight = font.lineHeight > 0 ? font.lineHeight : 16
            return Int(ceil(safeTextHeight / lineHeight))
        }

        // 更新滚动状态
        func updateScrollState(in textView: UITextView) {
            // 防止在无效状态下调用
            guard textView.window != nil else { return }

            // 计算当前行数
            lineCount = calculateLineCount(in: textView)

            // 根据行数设置是否允许滚动
            let shouldEnableScroll = lineCount > maxLinesBeforeScroll

            // 更新滚动状态
            textView.isScrollEnabled = shouldEnableScroll
            scrollDisabled = !shouldEnableScroll

            // 如果禁用滚动，确保内容位置重置
            if !shouldEnableScroll {
                // 安全设置内容偏移
                DispatchQueue.main.async {
                    textView.contentOffset = .zero
                }
            }
        }

        // MARK: - UITextViewDelegate

        // 当文本变化时调用
        func textViewDidChange(_ textView: UITextView) {
            updateScrollState(in: textView)
        }

        // 当开始编辑时调用
        func textViewDidBeginEditing(_ textView: UITextView) {
            updateScrollState(in: textView)
        }

        // MARK: - UIScrollViewDelegate

        // 当滚动时调用
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // 如果已经禁用滚动，强制重置内容位置
            if scrollDisabled {
                // 安全地设置内容偏移
                DispatchQueue.main.async {
                    scrollView.contentOffset = .zero
                }
            }
        }

        // 当将要开始拖动时调用
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            // 如果已经禁用滚动，阻止拖动
            if scrollDisabled {
                // 安全地设置内容偏移
                DispatchQueue.main.async {
                    scrollView.contentOffset = .zero
                }
            }
        }

        // 当拖动结束时调用
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // 如果已经禁用滚动，确保内容位置重置
            if scrollDisabled {
                // 安全地设置内容偏移
                DispatchQueue.main.async {
                    scrollView.contentOffset = .zero
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // 占位文本 - 仅在文本为空时显示，调整垂直位置
            if text.isEmpty {
                Text(isGenerating ? "正在生成回复..." : "输入消息...")
                    .foregroundColor(.gray)
                    .padding(.leading, 16)
                    .padding(.top, 2) // 调整垂直位置，使其与输入文本对齐
            }

            // 使用TextEditor实现多行输入，调整内边距
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 2) // 调整上下内边距，使文本垂直居中
                .frame(height: max(minHeight, min(textHeight, maxHeight)))
                .background(
                    // 使用GeometryReader监测文本高度变化
                    GeometryReader { geometry -> Color in
                        calculateHeight(geometry)
                        return Color.clear
                    }
                )
                .onChange(of: text) { newValue in
                    withAnimation(.spring(response: 0.4)) {
                        showSendButton = !newValue.isEmpty
                    }

                    // 当文本变化时，手动触发滚动状态更新
                    DispatchQueue.main.async {
                        if let textView = TextViewDelegate.shared.textView {
                            TextViewDelegate.shared.textViewDidChange(textView)
                        }
                    }
                }
                .focused($isInputActive)
                .disabled(isGenerating)
                .opacity(isGenerating ? 0.6 : 1.0)
                .font(.system(size: 16)) // 确保字体大小一致
                // 通过UIViewRepresentable禁用输入辅助栏并控制滚动行为
                .introspectTextView { textView in
                    // 防止在无效状态下调用
                    guard textView.window != nil else { return }

                    // 在主线程上安全设置属性
                    DispatchQueue.main.async {
                        // 禁用输入辅助栏
                        textView.inputAssistantItem.leadingBarButtonGroups = []
                        textView.inputAssistantItem.trailingBarButtonGroups = []

                        // 移除额外的内边距，保持TextEditor内容紧凑
                        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

                        // 设置代理以控制滚动行为
                        let delegate = TextViewDelegate.shared
                        textView.delegate = delegate

                        // 使用我们的setup方法初始化
                        delegate.setup(with: textView)

                        // 添加额外的滚动控制
                        // 禁用滚动弹性，避免滚动反弹
                        textView.bounces = false
                        textView.alwaysBounceVertical = false

                        // 禁用滑动惯性，避免滑动后继续滚动
                        textView.decelerationRate = .fast

                        // 禁用滑动指示器
                        textView.showsVerticalScrollIndicator = false
                    }
                }
        }
        .frame(height: max(minHeight, min(textHeight, maxHeight)))
        .background(Color(.systemGray6).opacity(0.7))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // 计算文本高度的函数
    private func calculateHeight(_ geometry: GeometryProxy) -> Color {
        DispatchQueue.main.async {
            // 防止宽度为0或负数
            let width = max(10, geometry.size.width)
            let size = CGSize(width: width, height: .infinity)

            // 估算文本高度
            let rawHeight: CGFloat
            if text.isEmpty {
                rawHeight = minHeight
            } else {
                rawHeight = text.boundingRect(
                    with: size,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: UIFont.systemFont(ofSize: 16)],
                    context: nil
                ).height + 16 // 减少内边距，使文本更紧凑
            }

            // 防止NaN和负值
            let estimatedHeight = rawHeight.isNaN ? minHeight : max(minHeight, rawHeight)

            // 检查高度是否变化
            let currentHeight = self.textHeight
            let heightChanged = !currentHeight.isNaN && !estimatedHeight.isNaN && abs(currentHeight - estimatedHeight) > 1

            if heightChanged {
                // 安全更新高度
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.textHeight = estimatedHeight
                }

                // 当高度变化时，手动触发滚动状态更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let textView = TextViewDelegate.shared.textView {
                        TextViewDelegate.shared.updateScrollState(in: textView)
                    }
                }
            }
        }
        return Color.clear
    }
}

// 添加位置偏好键
struct ViewPositionAnchor: Equatable {
    let viewId: String
    let anchor: Anchor<CGRect>
}

struct ViewPositionKey: PreferenceKey {
    static var defaultValue: [ViewPositionAnchor] = []

    static func reduce(value: inout [ViewPositionAnchor], nextValue: () -> [ViewPositionAnchor]) {
        value.append(contentsOf: nextValue())
    }
}