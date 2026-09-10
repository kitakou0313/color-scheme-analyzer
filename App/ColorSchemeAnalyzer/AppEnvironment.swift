import Foundation
import Persistence

/// アプリ全体で共有する依存（ストアと起動設定）
struct AppEnvironment {
    let store: AnalysisStore
    let launch: LaunchConfiguration

    /// Documents 配下に DB と画像ディレクトリを用意する（PER-01）。リセット指定があれば消してから開く
    static func make(launch: LaunchConfiguration) -> AppEnvironment {
        let documents = URL.documentsDirectory
        let databaseURL = documents.appendingPathComponent("color-scheme-analyzer.sqlite")
        let imagesDirectory = documents.appendingPathComponent("images", isDirectory: true)
        if launch.resetStore { reset(databaseURL: databaseURL, imagesDirectory: imagesDirectory) }
        do {
            let store = try AnalysisStore(databaseURL: databaseURL, imagesDirectory: imagesDirectory)
            return AppEnvironment(store: store, launch: launch)
        } catch {
            fatalError("ストアを開けません: \(error)")
        }
    }

    /// DB ファイル（WAL/SHM 含む）と画像ディレクトリを削除する
    private static func reset(databaseURL: URL, imagesDirectory: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + suffix))
        }
        try? FileManager.default.removeItem(at: imagesDirectory)
    }
}
