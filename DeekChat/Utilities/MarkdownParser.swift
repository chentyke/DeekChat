import Foundation
import SwiftUI
import UIKit

struct MarkdownParser {
    // 添加可配置选项
    struct Settings {
        static var defaultFontSize: CGFloat = 17
        static var headingLevel1FontSize: CGFloat = 24
        static var headingLevel2FontSize: CGFloat = 22
        static var headingLevel3FontSize: CGFloat = 20
        static var headingLevel4FontSize: CGFloat = 18 // 新增：四级标题字体大小
        static var headingLevel5FontSize: CGFloat = 17 // 新增：五级标题字体大小
        static var headingLevel6FontSize: CGFloat = 16 // 新增：六级标题字体大小
        static var dividerFontSize: CGFloat = 8
        static var codeFontSize: CGFloat = 15 // 代码字体大小
        static var tableFontSize: CGFloat = 15 // 表格字体大小
        
        // 从UserDefaults加载设置
        static func loadSettings() {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "defaultFontSize") != nil {
                defaultFontSize = CGFloat(defaults.double(forKey: "defaultFontSize"))
            }
            if defaults.object(forKey: "headingLevel1FontSize") != nil {
                headingLevel1FontSize = CGFloat(defaults.double(forKey: "headingLevel1FontSize"))
            }
            if defaults.object(forKey: "headingLevel2FontSize") != nil {
                headingLevel2FontSize = CGFloat(defaults.double(forKey: "headingLevel2FontSize"))
            }
            if defaults.object(forKey: "headingLevel3FontSize") != nil {
                headingLevel3FontSize = CGFloat(defaults.double(forKey: "headingLevel3FontSize"))
            }
            // 新增：加载四级、五级、六级标题的字体大小设置
            if defaults.object(forKey: "headingLevel4FontSize") != nil {
                headingLevel4FontSize = CGFloat(defaults.double(forKey: "headingLevel4FontSize"))
            }
            if defaults.object(forKey: "headingLevel5FontSize") != nil {
                headingLevel5FontSize = CGFloat(defaults.double(forKey: "headingLevel5FontSize"))
            }
            if defaults.object(forKey: "headingLevel6FontSize") != nil {
                headingLevel6FontSize = CGFloat(defaults.double(forKey: "headingLevel6FontSize"))
            }
            if defaults.object(forKey: "dividerFontSize") != nil {
                dividerFontSize = CGFloat(defaults.double(forKey: "dividerFontSize"))
            }
        }
    }
    
    // 静态初始化代码，确保设置被加载
    static let initialize: Void = {
        Settings.loadSettings()
    }()
    
    static func parseMarkdown(_ text: String, isUserMessage: Bool) -> AttributedString {
        // 确保设置已加载
        _ = initialize
        
        do {
            // 1. 预处理文本，确保换行符的一致性
            var processedText = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            
            // 处理水平分隔线
            processedText = processedText.replacingOccurrences(
                of: "(?m)^-{3,}$|^\\*{3,}$|^_{3,}$",
                with: "\n<hr>\n",  // 使用HTML标记，更容易识别
                options: .regularExpression
            )
            
            // 处理无序列表项
            processedText = processedText.replacingOccurrences(
                of: "(?m)^\\s*[-*]\\s+(.+)$",
                with: "• $1",
                options: .regularExpression
            )
            
            // 处理有序列表项
            processedText = processedText.replacingOccurrences(
                of: "(?m)^\\s*(\\d+)\\.\\s+(.+)$",
                with: "$1. $2",
                options: .regularExpression
            )
            
            // 创建并配置基本的AttributedString
            var attributedString = AttributedString(processedText)
            attributedString.foregroundColor = isUserMessage ? .white : .primary
            attributedString.font = .system(size: Settings.defaultFontSize)
            
            // 检查是否有表格或代码块
            var finalString = AttributedString()
            
            // 首先检查表格 - 放宽识别条件
            if processedText.contains("|") {
                // 可能包含表格，进行分段处理
                // 将处理委托给单独的函数，处理表格和其他内容
                finalString = processTextWithTables(processedText, isUserMessage: isUserMessage)
            }
            // 然后检查代码块
            else if processedText.contains("```") {
                // 处理代码块
                let codeBlockPattern = "```([a-z]*)\\s*([\\s\\S]*?)```"
                
                // 检查文本中是否包含代码块
                if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
                    let nsString = processedText as NSString
                    let matches = regex.matches(in: processedText, options: [], range: NSRange(location: 0, length: nsString.length))
                    
                    if !matches.isEmpty {
                        // 文本包含代码块，需要分段处理
                        var lastEndIndex = 0
                        
                        for match in matches {
                            // 添加代码块前的普通文本
                            if match.range.location > lastEndIndex {
                                let normalTextRange = NSRange(location: lastEndIndex, length: match.range.location - lastEndIndex)
                                let normalText = nsString.substring(with: normalTextRange)
                                finalString.append(parseNormalText(normalText, isUserMessage: isUserMessage))
                            }
                            
                            // 处理代码块
                            let languageRange = match.range(at: 1)
                            let codeRange = match.range(at: 2)
                            
                            let language = languageRange.location != NSNotFound 
                                ? nsString.substring(with: languageRange) 
                                : ""
                            let code = codeRange.location != NSNotFound 
                                ? nsString.substring(with: codeRange).trimmingCharacters(in: .whitespacesAndNewlines) 
                                : ""
                            
                            finalString.append(formatCodeBlock(code, language: language, isUserMessage: isUserMessage))
                            
                            lastEndIndex = match.range.location + match.range.length
                        }
                        
                        // 添加最后一个代码块后的普通文本
                        if lastEndIndex < nsString.length {
                            let normalTextRange = NSRange(location: lastEndIndex, length: nsString.length - lastEndIndex)
                            let normalText = nsString.substring(with: normalTextRange)
                            finalString.append(parseNormalText(normalText, isUserMessage: isUserMessage))
                        }
                    } else {
                        // 没有代码块，直接处理普通文本
                        finalString = parseNormalText(processedText, isUserMessage: isUserMessage)
                    }
                } else {
                    // 正则表达式创建失败，直接处理普通文本
                    finalString = parseNormalText(processedText, isUserMessage: isUserMessage)
                }
            } else {
                // 没有表格或代码块，直接处理普通文本
                finalString = parseNormalText(processedText, isUserMessage: isUserMessage)
            }
            
            return finalString
            
        } catch {
            print("Markdown parsing error: \(error)")
            var fallbackString = AttributedString(text)
            fallbackString.foregroundColor = isUserMessage ? .white : .primary
            fallbackString.font = .system(size: Settings.defaultFontSize)
            return fallbackString
        }
    }
    
    // 处理包含表格的文本
    private static func processTextWithTables(_ text: String, isUserMessage: Bool) -> AttributedString {
        var finalString = AttributedString()
        let lines = text.components(separatedBy: "\n")
        
        var i = 0
        while i < lines.count {
            var tableLines: [String] = []
            var isTable = false
            
            // 判断当前行是否是表格的开始 - 放宽条件，只要包含|就可能是表格
            if lines[i].contains("|") {
                isTable = true
                
                // 收集表格的所有行
                while i < lines.count && lines[i].contains("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                
                if tableLines.count >= 2 {
                    // 至少有表头和分隔行，可以确认是表格
                    let tableAttrString = parseTable(tableLines, isUserMessage: isUserMessage)
                    finalString.append(tableAttrString)
                    
                    // 添加表格后的换行
                    finalString.append(AttributedString("\n"))
                } else {
                    // 不是有效的表格，作为普通文本处理
                    for line in tableLines {
                        finalString.append(parseNormalText(line, isUserMessage: isUserMessage))
                        finalString.append(AttributedString("\n"))
                    }
                }
            } else {
                // 处理普通行
                finalString.append(parseNormalText(lines[i], isUserMessage: isUserMessage))
                finalString.append(AttributedString("\n"))
                i += 1
            }
        }
        
        return finalString
    }
    
    // 解析表格
    private static func parseTable(_ tableLines: [String], isUserMessage: Bool) -> AttributedString {
        var result = AttributedString()
        
        // 分析表格结构
        var tableData: [[String]] = []
        var columnCount = 0
        
        // 处理表头行
        if !tableLines.isEmpty {
            let headerCells = parseTableRow(tableLines[0])
            tableData.append(headerCells)
            columnCount = max(columnCount, headerCells.count)
        }
        
        // 检查分隔行 - 增强对各种分隔行的识别
        var dataStartIndex = 1 // 默认从第二行开始是数据行
        var hasHeaderRow = false
        
        if tableLines.count > 1 {
            let secondLine = tableLines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            // 检查是否是分隔行（包含-或=）
            if secondLine.contains("-") || secondLine.contains("=") || secondLine.contains("|") && secondLine.contains("-") {
                dataStartIndex = 2
                hasHeaderRow = true
            }
        }
        
        // 处理数据行
        for i in dataStartIndex..<tableLines.count {
            let rowCells = parseTableRow(tableLines[i])
            tableData.append(rowCells)
            columnCount = max(columnCount, rowCells.count)
        }
        
        // 格式化表格
        for (rowIndex, row) in tableData.enumerated() {
            var rowString = AttributedString()
            
            for (colIndex, cell) in row.enumerated() {
                // 添加分隔符
                if colIndex > 0 {
                    rowString.append(AttributedString(" | "))
                }
                
                // 处理单元格文本，支持单元格内的粗体
                let cellText = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                var cellAttr: AttributedString
                
                if cellText.contains("**") {
                    // 处理单元格内的粗体文本
                    cellAttr = processBoldTextInCell(cellText, isUserMessage: isUserMessage)
                } else {
                    // 普通文本单元格
                    cellAttr = AttributedString(cellText)
                    cellAttr.foregroundColor = isUserMessage ? .white : .primary
                    cellAttr.font = (rowIndex == 0 && hasHeaderRow) 
                        ? .system(size: Settings.tableFontSize, weight: .bold) // 表头加粗
                        : .system(size: Settings.tableFontSize)
                }
                
                rowString.append(cellAttr)
            }
            
            result.append(rowString)
            
            // 如果是表头且有分隔行，添加一条分隔线
            if rowIndex == 0 && hasHeaderRow {
                var separatorLine = AttributedString("\n")
                separatorLine.append(AttributedString("─".repeated(columnCount * 6))) // 分隔线
                separatorLine.foregroundColor = isUserMessage ? .white.opacity(0.7) : .gray
                separatorLine.font = .system(size: Settings.dividerFontSize)
                result.append(separatorLine)
            }
            
            // 添加行间换行符（除了最后一行）
            if rowIndex < tableData.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    // 处理单元格内的粗体文本
    private static func processBoldTextInCell(_ cellText: String, isUserMessage: Bool) -> AttributedString {
        var result = AttributedString()
        let parts = cellText.components(separatedBy: "**")
        
        for (index, part) in parts.enumerated() {
            var partAttr = AttributedString(part)
            partAttr.foregroundColor = isUserMessage ? .white : .primary
            
            // 奇数索引的部分是粗体 (索引为1、3、5...)
            if index % 2 == 1 {
                partAttr.font = .system(size: Settings.tableFontSize, weight: .bold)
            } else {
                partAttr.font = .system(size: Settings.tableFontSize)
            }
            
            result.append(partAttr)
        }
        
        return result
    }

    // 解析表格行，提取单元格内容
    private static func parseTableRow(_ row: String) -> [String] {
        // 处理各种可能的表格行格式
        var processedRow = row.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除首尾的|
        if processedRow.hasPrefix("|") {
            processedRow = String(processedRow.dropFirst())
        }
        if processedRow.hasSuffix("|") {
            processedRow = String(processedRow.dropLast())
        }
        
        // 分割单元格，保留前后空格
        let cells = processedRow.components(separatedBy: "|")
        
        // 规范化每个单元格的内容
        return cells.map { $0.trimmingCharacters(in: .newlines) }
    }
    
    // 格式化代码块
    private static func formatCodeBlock(_ code: String, language: String, isUserMessage: Bool) -> AttributedString {
        var codeBlockString = AttributedString()
        
        // 添加语言标签（如果存在）
        if !language.isEmpty {
            var languageAttr = AttributedString(language)
            languageAttr.font = .system(size: Settings.codeFontSize - 2, weight: .medium)
            languageAttr.foregroundColor = isUserMessage ? .white.opacity(0.8) : .gray
            codeBlockString.append(languageAttr)
            codeBlockString.append(AttributedString("\n"))
        }
        
        // 添加代码内容
        var codeAttr = AttributedString(code)
        codeAttr.font = .system(size: Settings.codeFontSize, design: .monospaced)
        codeAttr.foregroundColor = isUserMessage ? .white : .primary
        
        // 应用代码块的背景色和边框
        // 注意：AttributedString不直接支持背景色，这里需要在SwiftUI视图层处理
        
        codeBlockString.append(codeAttr)
        
        // 添加代码块的分隔
        codeBlockString.append(AttributedString("\n"))
        
        return codeBlockString
    }

    // 处理普通文本（非代码块部分）
    private static func parseNormalText(_ text: String, isUserMessage: Bool) -> AttributedString {
        // 简单处理标题和特殊标记，不使用复杂的范围操作
        // 将文本拆分成行
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var finalString = AttributedString()
            
            for line in lines {
                let lineStr = String(line)
                var lineAttrStr: AttributedString
                
                // 处理水平分隔线
                if lineStr.trimmingCharacters(in: .whitespacesAndNewlines) == "<hr>" {
                    // 创建单行分割线
                    var dividerStr = AttributedString("───────────────────────────────────")
                    dividerStr.foregroundColor = .gray
                    dividerStr.font = .system(size: Settings.dividerFontSize)
                    
                    // 设置段落样式，减少上下间距
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = .center
                    paragraphStyle.paragraphSpacingBefore = 0  // 减少上间距
                    paragraphStyle.paragraphSpacing = 1
                    paragraphStyle.lineSpacing = 0
                    dividerStr.paragraphStyle = paragraphStyle
                    
                    finalString.append(dividerStr)
                    // 不额外添加换行符
                    continue
                }
                
                // 处理标题，并移除标题中的加粗标记
                if lineStr.hasPrefix("# ") {
                    var titleText = String(lineStr.dropFirst(2))
                    // 移除标题中的加粗标记
                    titleText = processBoldMarkers(in: titleText)
                    var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel1FontSize, weight: .bold)
                    titleAttr.foregroundColor = isUserMessage ? .white : .primary
                    finalString.append(titleAttr)
                }
                else if lineStr.hasPrefix("## ") {
                    var titleText = String(lineStr.dropFirst(3))
                    // 移除标题中的加粗标记
                    titleText = processBoldMarkers(in: titleText)
                    var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel2FontSize, weight: .bold)
                    titleAttr.foregroundColor = isUserMessage ? .white : .primary
                    finalString.append(titleAttr)
                }
                else if lineStr.hasPrefix("### ") {
                    var titleText = String(lineStr.dropFirst(4))
                    // 移除标题中的加粗标记
                    titleText = processBoldMarkers(in: titleText)
                    var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel3FontSize, weight: .bold)
                titleAttr.foregroundColor = isUserMessage ? .white : .primary
                finalString.append(titleAttr)
            }
            // 新增：处理四级标题
            else if lineStr.hasPrefix("#### ") {
                var titleText = String(lineStr.dropFirst(5))
                // 移除标题中的加粗标记
                titleText = processBoldMarkers(in: titleText)
                var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel4FontSize, weight: .semibold)
                titleAttr.foregroundColor = isUserMessage ? .white : .primary
                finalString.append(titleAttr)
            }
            // 新增：处理五级标题
            else if lineStr.hasPrefix("##### ") {
                var titleText = String(lineStr.dropFirst(6))
                // 移除标题中的加粗标记
                titleText = processBoldMarkers(in: titleText)
                var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel5FontSize, weight: .semibold)
                titleAttr.foregroundColor = isUserMessage ? .white : .primary
                finalString.append(titleAttr)
            }
            // 新增：处理六级标题
            else if lineStr.hasPrefix("###### ") {
                var titleText = String(lineStr.dropFirst(7))
                // 移除标题中的加粗标记
                titleText = processBoldMarkers(in: titleText)
                var titleAttr = AttributedString(titleText)
                titleAttr.font = .system(size: Settings.headingLevel6FontSize, weight: .semibold)
                    titleAttr.foregroundColor = isUserMessage ? .white : .primary
                    finalString.append(titleAttr)
                }
                // 处理其他普通文本
                else {
                    let attrLine = AttributedString(lineStr)
                    var mutableLine = attrLine
                    mutableLine.foregroundColor = isUserMessage ? .white : .primary
                    mutableLine.font = .system(size: Settings.defaultFontSize)
                    
                    // 简单处理粗体
                    if lineStr.contains("**") {
                        let boldParts = lineStr.components(separatedBy: "**")
                        if boldParts.count > 1 {
                            var newLine = AttributedString()
                            for (index, part) in boldParts.enumerated() {
                                var partAttr = AttributedString(part)
                                partAttr.foregroundColor = isUserMessage ? .white : .primary
                                
                                // 奇数索引的部分是粗体 (索引为1、3、5...)
                                if index % 2 == 1 {
                                partAttr.font = .system(size: Settings.defaultFontSize, weight: .bold)
                                } else {
                                    partAttr.font = .system(size: Settings.defaultFontSize)
                                }
                                newLine.append(partAttr)
                            }
                            mutableLine = newLine
                        }
                    }
                    
                    finalString.append(mutableLine)
                }
                
                // 添加换行符
                finalString.append(AttributedString("\n"))
            }
            
            return finalString
    }

    // 辅助方法：处理文本中的加粗标记
    private static func processBoldMarkers(in text: String) -> String {
        if !text.contains("**") {
            return text
        }
        
        let parts = text.components(separatedBy: "**")
        var result = ""
        
        for (index, part) in parts.enumerated() {
            result += part
            // 我们不需要在最后一部分后添加任何内容
            if index < parts.count - 1 {
                // 不添加任何分隔符
            }
        }
        
        return result
    }
}

// String扩展
extension String {
    // 重复字符串指定次数
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
} 