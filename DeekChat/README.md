# DeekChat

DeekChat 是一个基于 SwiftUI 开发的现代化 AI 聊天应用，提供流畅的对话体验和优雅的用户界面。该应用集成了 DeepSeek AI API，支持实时对话、智能标题生成等功能。

## 功能特点

- 🤖 实时 AI 对话：集成 DeepSeek AI，支持流式响应
- 📝 智能标题生成：自动为每个对话生成相关标题
- 📚 聊天历史管理：保存和管理所有对话记录
- 🎨 现代化 UI 设计：优雅的动画和过渡效果
- 📱 响应式布局：完美适配不同设备尺寸
- 🔄 实时消息同步：流式显示 AI 响应
- 📋 Markdown 支持：支持富文本格式显示
- 🎯 自定义设置：支持自定义 API 密钥和模型选择

## 技术栈

- SwiftUI
- MVVM 架构
- Async/Await
- UserDefaults 数据持久化
- RESTful API
- Markdown 渲染

## 系统要求

- iOS 15.0 或更高版本
- Xcode 13.0 或更高版本
- Swift 5.5 或更高版本

## 安装说明

1. 克隆项目到本地：
```bash
git clone https://github.com/yourusername/DeekChat.git
```

2. 打开项目：
```bash
cd DeekChat
open DeekChat.xcodeproj
```

3. 配置 API 密钥：
   - 在项目中找到 `DeekChatApp.swift`
   - 替换 `apiKey` 为你的 DeepSeek API 密钥

4. 运行项目：
   - 选择目标设备或模拟器
   - 点击运行按钮或按下 `Cmd + R`

## 项目结构

```
DeekChat/
├── Models/
│   └── ChatMessage.swift      # 聊天消息数据模型
├── ViewModels/
│   └── ChatViewModel.swift    # 聊天视图模型
├── Services/
│   └── ChatService.swift      # API 服务层
├── Views/
│   ├── ContentView.swift      # 主视图
│   └── Components/            # UI 组件
├── Assets.xcassets/           # 资源文件
└── DeekChatApp.swift          # 应用入口
```

## 使用说明

1. **开始新对话**
   - 点击右上角的新建按钮
   - 或在侧边栏中选择"新对话"

2. **发送消息**
   - 在底部输入框输入消息
   - 点击发送按钮或按回车键发送

3. **管理对话**
   - 点击对话标题可以编辑
   - 在侧边栏查看历史对话
   - 左滑删除历史对话

4. **自定义设置**
   - 支持自定义 API 端点
   - 可选择不同的 AI 模型
   - 可自定义欢迎消息

## 贡献指南

欢迎提交 Pull Request 或创建 Issue！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 联系方式

如有任何问题或建议，欢迎联系我们：

- 项目主页：[GitHub](https://github.com/yourusername/DeekChat)
- 邮箱：your.email@example.com

## 致谢

- [DeepSeek AI](https://deepseek.com) - AI 对话引擎
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI 框架
- 所有项目贡献者 