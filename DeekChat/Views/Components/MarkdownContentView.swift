import SwiftUI

/// 专门负责显示Markdown内容的视图组件
struct MarkdownContentView: View {
    let content: String // 原始Markdown文本
    let parsedContent: AttributedString // 已解析的AttributedString
    let backgroundBrightness: Double // 背景亮度
    
    var body: some View {
        MarkdownRenderer(
            content: content,
            parsedContent: parsedContent,
            backgroundBrightness: backgroundBrightness
        )
    }
}

// MARK: - 主渲染器
/// Markdown内容渲染器
struct MarkdownRenderer: View {
    let content: String
    let parsedContent: AttributedString
    let backgroundBrightness: Double
    
    // 私有状态
    @State private var contentSections: [ContentSection] = []
    @State private var hasTable = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(backgroundBrightness))
            
            // 内容
            VStack(alignment: .leading, spacing: 6) {
                if hasTable {
                    // 有表格时使用自定义渲染
                    ForEach(contentSections) { section in
                        sectionView(for: section)
                    }
                } else {
                    // 无表格时使用系统渲染
                    standardTextView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .onAppear {
            // 分析内容并预处理
            self.hasTable = MarkdownAnalyzer.hasTableContent(in: content)
            if hasTable {
                self.contentSections = MarkdownAnalyzer.parseContentSections(content)
            }
        }
    }
    
    // 标准文本视图
    private var standardTextView: some View {
        Text(parsedContent)
            .font(.system(size: 17))
            .lineSpacing(1.2)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
    
    // 根据内容类型选择对应的视图
    @ViewBuilder
    private func sectionView(for section: ContentSection) -> some View {
        Group {
            if section.isTable {
                TableBlockView(tableContent: section.content)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
            } else if section.isCodeBlock {
                CodeBlockView(codeContent: section.content)
                    .padding(.vertical, 2)
            } else {
                TextBlockView(textContent: section.content)
            }
        }
    }
}

// MARK: - 专用组件
/// 表格视图组件
struct TableBlockView: View {
    let tableContent: String
    
    var body: some View {
        // 处理表格数据
        let tableData = TableProcessor.processTableLines(tableContent)
        let rows = tableData.rows
        let hasHeader = tableData.hasHeader
        let columnWidths = TableProcessor.calculateColumnWidths(rows: rows)
        
        // 构建表格视图
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                // 构建行
                rowView(row: row, rowIndex: rowIndex, hasHeader: hasHeader, columnWidths: columnWidths)
                
                // 行间分隔线
                Divider()
                    .background(Color.gray.opacity(0.3))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // 构建表格行视图
    private func rowView(row: [String], rowIndex: Int, hasHeader: Bool, columnWidths: [CGFloat]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cellText in
                if colIndex < columnWidths.count {
                    // 构建单元格
                    cellView(
                        text: cellText,
                        isHeader: rowIndex == 0 && hasHeader,
                        width: columnWidths[colIndex],
                        isLastColumn: colIndex == row.count - 1
                    )
                }
            }
        }
        .frame(height: 40)
    }
    
    // 构建单元格视图
    private func cellView(text: String, isHeader: Bool, width: CGFloat, isLastColumn: Bool) -> some View {
        HStack(spacing: 0) {
            // 单元格内容
            TableCellView(
                text: text,
                width: width, isHeader: isHeader
            )
            .frame(width: width)
            
            // 列间分隔线
            if !isLastColumn {
                Divider()
                    .background(Color.gray.opacity(0.3))
            }
        }
    }
}

/// 表格单元格视图
struct TableCellView: View {
    let text: String
    let width: CGFloat
    let isHeader: Bool
    
    var body: some View {
        Text(text)
            .font(isHeader ? .headline : .body)
            .fontWeight(isHeader ? .semibold : .regular)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: width, alignment: .leading)
            .background(cellBackground)
    }
    
    private var cellBackground: Color {
        if isHeader {
            return Color(UIColor.systemGray5).opacity(0.8)
        } else {
            return Color.white.opacity(0.9)
        }
    }
}

/// 代码块视图组件
struct CodeBlockView: View {
    let codeContent: String
    
    var body: some View {
        let language = CodeAnalyzer.detectLanguage(codeContent)
        
        return VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                Text(language)
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(4)
                    .padding(.top, 8)
                    .padding(.leading, 10)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeContent)
                    .font(.system(size: 15, design: .monospaced))
                    .lineSpacing(4)
                    .padding(.vertical, language.isEmpty ? 12 : 8)
                    .padding(.horizontal, 12)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
        )
    }
}

/// 文本块视图组件
struct TextBlockView: View {
    let textContent: String
    
    var body: some View {
        Text(formattedText)
            .font(.system(size: 17))
            .lineSpacing(1.2)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
    
    // 格式化文本
    private var formattedText: AttributedString {
        do {
            return try AttributedString(markdown: textContent)
        } catch {
            return AttributedString(textContent)
        }
    }
}

// MARK: - 数据模型
/// 内容区块模型
struct ContentSection: Identifiable {
    let id = UUID()
    let isTable: Bool
    let isCodeBlock: Bool
    let content: String
}

// MARK: - 工具类
/// Markdown分析工具
struct MarkdownAnalyzer {
    /// 检查内容中是否包含表格
    static func hasTableContent(in text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }
        
        var tableLineCount = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("|") && (
                trimmed.contains("| ") || 
                trimmed.contains(" |") || 
                (trimmed.hasPrefix("|") && trimmed.hasSuffix("|"))
            ) {
                tableLineCount += 1
                if tableLineCount >= 2 {
                    return true
                }
            }
        }
        return false
    }
    
    /// 解析内容区块，包括普通文本、代码块和表格
    static func parseContentSections(_ content: String) -> [ContentSection] {
        var sections: [ContentSection] = []
        var currentText = ""
        
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        var inTable = false
        var inCodeBlock = false
        var tableLines: [String] = []
        
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查是否是代码块分隔符
            if trimmedLine.hasPrefix("```") {
                // 结束当前文本块
                if !currentText.isEmpty {
                    sections.append(ContentSection(
                        isTable: false,
                        isCodeBlock: inCodeBlock,
                        content: currentText
                    ))
                    currentText = ""
                }
                
                // 切换代码块状态
                inCodeBlock = !inCodeBlock
                i += 1
                continue
            }
            
            // 如果在代码块内，直接添加内容
            if inCodeBlock {
                if currentText.isEmpty {
                    currentText = line
                } else {
                    currentText += "\n" + line
                }
                i += 1
                continue
            }
            
            // 检查是否是表格行
            let isTableLine = line.contains("|") && (
                trimmedLine.contains("| ") || 
                trimmedLine.contains(" |") || 
                (trimmedLine.hasPrefix("|") && trimmedLine.hasSuffix("|"))
            )
            
            if isTableLine {
                // 如果之前有普通文本，保存它
                if !currentText.isEmpty {
                    sections.append(ContentSection(
                        isTable: false,
                        isCodeBlock: false,
                        content: currentText
                    ))
                    currentText = ""
                }
                
                // 开始收集表格行
                if !inTable {
                    inTable = true
                    tableLines = [line]
                } else {
                    tableLines.append(line)
                }
            } else {
                // 非表格行
                if inTable {
                    // 表格结束，添加到sections
                    sections.append(ContentSection(
                        isTable: true,
                        isCodeBlock: false,
                        content: tableLines.joined(separator: "\n")
                    ))
                    
                    // 重置表格状态
                    tableLines = []
                    inTable = false
                    
                    // 开始新的文本内容
                    currentText = line
                } else {
                    // 普通文本内容
                    if currentText.isEmpty {
                        currentText = line
                    } else {
                        currentText += "\n" + line
                    }
                }
            }
            
            i += 1
        }
        
        // 处理文档末尾内容
        if inTable && !tableLines.isEmpty {
            // 表格结束
            sections.append(ContentSection(
                isTable: true,
                isCodeBlock: false,
                content: tableLines.joined(separator: "\n")
            ))
        } else if inCodeBlock && !currentText.isEmpty {
            // 代码块结束
            sections.append(ContentSection(
                isTable: false,
                isCodeBlock: true,
                content: currentText
            ))
        } else if !currentText.isEmpty {
            // 普通文本
            sections.append(ContentSection(
                isTable: false,
                isCodeBlock: false,
                content: currentText
            ))
        }
        
        return sections
    }
}

/// 表格处理工具
struct TableProcessor {
    /// 处理表格行
    static func processTableLines(_ content: String) -> (rows: [[String]], hasHeader: Bool) {
        let lines = content.components(separatedBy: .newlines)
        var rows: [[String]] = []
        var hasHeader = false
        
        // 检查分隔行
        if lines.count > 1 {
            let secondLine = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if secondLine.contains("-") || secondLine.contains("=") || 
               (secondLine.contains("|") && secondLine.contains("-")) {
                hasHeader = true
            }
        }
        
        for i in 0..<lines.count {
            if i == 1 && hasHeader { continue } // 跳过分隔行
            
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.contains("|") { continue }
            
            // 解析行中的单元格
            var processedRow = line
            if processedRow.hasPrefix("|") {
                processedRow = String(processedRow.dropFirst())
            }
            if processedRow.hasSuffix("|") {
                processedRow = String(processedRow.dropLast())
            }
            
            // 处理单元格内容
            let cells = processedRow.components(separatedBy: "|")
                .map { 
                    let cell = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    return cell.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
                }
            
            rows.append(cells)
        }
        
        return (rows, hasHeader)
    }
    
    /// 计算列宽
    static func calculateColumnWidths(rows: [[String]]) -> [CGFloat] {
        let columnCount = rows.map { $0.count }.max() ?? 0
        guard columnCount > 0 else { return [] }
        
        var widths = Array(repeating: CGFloat(40), count: columnCount)
        
        for row in rows {
            for (colIndex, cell) in row.enumerated() {
                if colIndex < columnCount {
                    let cellWidth = estimateTextWidth(cell) + 20
                    widths[colIndex] = max(widths[colIndex], cellWidth)
                }
            }
        }
        
        return widths
    }
    
    /// 估算文本宽度
    private static func estimateTextWidth(_ text: String) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 15)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
    }
}

/// 代码分析工具
struct CodeAnalyzer {
    /// 检测代码语言
    static func detectLanguage(_ content: String) -> String {
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        if firstLine.lowercased().contains("swift") { return "Swift" }
        if firstLine.lowercased().contains("python") { return "Python" }
        if firstLine.lowercased().contains("javascript") { return "JavaScript" }
        if firstLine.lowercased().contains("typescript") { return "TypeScript" }
        if firstLine.lowercased().contains("java") { return "Java" }
        if firstLine.lowercased().contains("cpp") || firstLine.lowercased().contains("c++") { return "C++" }
        if firstLine.lowercased().contains("csharp") || firstLine.lowercased().contains("c#") { return "C#" }
        return ""
    }
} 
