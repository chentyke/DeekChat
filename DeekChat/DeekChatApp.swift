//
//  DeepSeekApp.swift
//  DeepSeek
//
//  Created by 飞烟 on 2024/12/3.
//

import SwiftUI

@main
struct DeekChatApp: App {
    init() {
        UserDefaults.standard.set("sk-tmmowgpqiwegntfdneyuvxtwkixhvviqxmplineozsoaoixm", forKey: "apiKey")
        UserDefaults.standard.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

// 添加预览
struct DeekChatApp_Previews: PreviewProvider {
    static var previews: some View {
        MainView() // 预览主视图
            .previewDevice("iPhone 14") // 可以根据需要更改设备类型
    }
}
