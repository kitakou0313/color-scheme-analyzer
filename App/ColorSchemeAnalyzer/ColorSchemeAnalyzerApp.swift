import SwiftUI

/// アプリのエントリーポイント。起動設定からストアを開き、ルート画面を表示する
@main
struct ColorSchemeAnalyzerApp: App {
    private let environment = AppEnvironment.make(launch: LaunchConfiguration.current)

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
