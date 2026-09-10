import Foundation

/// E2E テスト用の起動引数（blueprint 8 章）。Debug ビルドでのみ解釈する
struct LaunchConfiguration: Equatable {
    /// `-uiTestFixture <name>`: バンドル内の画像 <name>.png で取り込みフローを開始する
    var fixtureName: String?
    /// `-uiTestResetStore`: DB と画像ディレクトリを空にしてから起動する
    var resetStore = false

    /// このプロセスの起動引数から得た設定
    static let current = parse(CommandLine.arguments)

    /// 引数配列を解釈する。Release では常に既定値
    static func parse(_ arguments: [String]) -> LaunchConfiguration {
        #if DEBUG
        var config = LaunchConfiguration()
        if let index = arguments.firstIndex(of: "-uiTestFixture"), index + 1 < arguments.count {
            config.fixtureName = arguments[index + 1]
        }
        config.resetStore = arguments.contains("-uiTestResetStore")
        return config
        #else
        return LaunchConfiguration()
        #endif
    }
}
