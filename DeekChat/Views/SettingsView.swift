import SwiftUI

struct SettingsView: View {
    @AppStorage("apiUrl") private var apiUrl = "https://api.siliconflow.cn/v1"
    @AppStorage("apiKey") private var apiKey = "sk-tmmowgpqiwegntfdneyuvxtwkixhvviqxmplineozsoaoixm"
    @AppStorage("modelName") private var modelName = "deepseek-ai/DeepSeek-V3"
    @AppStorage("customModelName") private var customModelName = ""
    @AppStorage("welcomeMessage") private var welcomeMessage = "你好！我是 AI助手，请问有什么我可以帮你的吗？"
    @AppStorage("defaultFontSize") private var defaultFontSize: Double = 17
    @AppStorage("headingLevel1FontSize") private var headingLevel1FontSize: Double = 24
    @AppStorage("headingLevel2FontSize") private var headingLevel2FontSize: Double = 22
    @AppStorage("headingLevel3FontSize") private var headingLevel3FontSize: Double = 20
    @AppStorage("dividerFontSize") private var dividerFontSize: Double = 8
    @AppStorage("backgroundBrightness") private var backgroundBrightness: Double = 1.0
    @State private var showingSaved = false
    @State private var balance: BalanceResponse?
    @State private var isLoadingBalance = false
    @State private var balanceError: String?
    @State private var selectedModelOption = "deepseek-ai/DeepSeek-V3"
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel

    private let modelOptions = [
        ("DeepSeek V3", "deepseek-ai/DeepSeek-V3"),
        ("DeepSeek R1", "deepseek-ai/DeepSeek-R1"),
        ("自定义模型", "custom")
    ]

    var body: some View {
        Form {
            Section(header: Text("API设置")) {
                TextField("API地址", text: $apiUrl)
                    .textContentType(.URL)
                    .autocapitalization(.none)

                SecureField("API密钥", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)

                Picker("模型", selection: $selectedModelOption) {
                    ForEach(modelOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .pickerStyle(.menu)
                .onAppear {
                    // 初始化选择状态
                    if modelName == customModelName {
                        selectedModelOption = "custom"
                    } else {
                        selectedModelOption = modelName
                    }
                }
                .onChange(of: selectedModelOption) { newValue in
                    if newValue == "custom" {
                        if customModelName.isEmpty {
                            customModelName = "custom-model"
                        }
                        modelName = customModelName
                    } else {
                        modelName = newValue
                    }
                }

                if selectedModelOption == "custom" {
                    TextField("自定义模型名称", text: $customModelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .onChange(of: customModelName) { newValue in
                            if !newValue.isEmpty && selectedModelOption == "custom" {
                                modelName = newValue
                            }
                        }
                }
            }

            Section(header: Text("账户余额")) {
                if isLoadingBalance {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                } else if let error = balanceError {
                    Text(error)
                        .foregroundColor(.red)
                } else if let balance = balance {
                    ForEach(balance.balanceInfos, id: \.currency) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("总余额: \(info.totalBalance) \(info.currency)")
                            Text("赠送余额: \(info.grantedBalance) \(info.currency)")
                            Text("充值余额: \(info.toppedUpBalance) \(info.currency)")
                        }
                    }
                }

                Button(action: {
                    Task {
                        await fetchBalance()
                    }
                }) {
                    Text("刷新余额")
                }
            }

            Section(header: Text("亮度设置")) {
                VStack(alignment: .leading) {
                    Text("背景亮度: \(Int(backgroundBrightness * 100))%")
                    Slider(value: $backgroundBrightness, in: 0.8...1.0, step: 0.01)
                        .onChange(of: backgroundBrightness) { _ in
                            UserDefaults.standard.set(backgroundBrightness, forKey: "backgroundBrightness")
                            showingSaved = true
                            saveSettings()
                        }
                }
            }

            Section(header: Text("欢迎消息")) {
                TextField("自定义欢迎消息", text: $welcomeMessage)
                    .autocapitalization(.sentences)
            }

            Section {
                Button(action: saveSettings) {
                    HStack {
                        Text("保存设置")
                        if showingSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Section {
                Button(action: {
                    viewModel.clearAllChats()
                }) {
                    Text("清除所有聊天记录")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("设置")
        .task {
            await fetchBalance()
        }
        .onChange(of: defaultFontSize) { _ in updateMarkdownSettings() }
        .onChange(of: headingLevel1FontSize) { _ in updateMarkdownSettings() }
        .onChange(of: headingLevel2FontSize) { _ in updateMarkdownSettings() }
        .onChange(of: headingLevel3FontSize) { _ in updateMarkdownSettings() }
        .onChange(of: dividerFontSize) { _ in updateMarkdownSettings() }
    }

    private func fetchBalance() async {
        isLoadingBalance = true
        balanceError = nil

        do {
            balance = try await ChatService.shared.fetchBalance()
        } catch {
            balanceError = error.localizedDescription
        }

        isLoadingBalance = false
    }

    private func saveSettings() {
        withAnimation {
            showingSaved = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaved = false
            }
        }
    }

    private func updateMarkdownSettings() {
        MarkdownParser.Settings.defaultFontSize = CGFloat(defaultFontSize)
        MarkdownParser.Settings.headingLevel1FontSize = CGFloat(headingLevel1FontSize)
        MarkdownParser.Settings.headingLevel2FontSize = CGFloat(headingLevel2FontSize)
        MarkdownParser.Settings.headingLevel3FontSize = CGFloat(headingLevel3FontSize)
        MarkdownParser.Settings.dividerFontSize = CGFloat(dividerFontSize)
    }
} 