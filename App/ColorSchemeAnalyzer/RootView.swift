import AnalysisWorkflow
import Persistence
import SwiftUI

/// ルート画面。サイドバー（ライブラリ）と詳細を NavigationSplitView で並べる
struct RootView: View {
    @State private var model: AppModel
    @State private var importer: ImportController
    private let environment: AppEnvironment

    /// 環境からライブラリの状態を作る
    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: AppModel(store: environment.store))
        let delay: Duration? = environment.launch.slowAnalysis ? .seconds(4) : nil
        _importer = State(initialValue: ImportController(testingAnalysisDelay: delay))
    }

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model, importer: importer)
        } detail: {
            DetailContainer(model: model, importer: importer)
        }
        .sheet(isPresented: $importer.showsResolutionSheet) { resolutionSheet }
        .overlay { if importer.stage == .analyzing { ProgressOverlay(progress: importer.progress) { importer.cancel() } } }
        .alert("エラー", isPresented: alertBinding(\.errorMessage, on: model)) { Button("OK") {} } message: { Text(model.errorMessage ?? "") }
        .alert("取り込みに失敗しました", isPresented: alertBinding(\.errorMessage, on: importer)) { Button("OK") {} } message: { Text(importer.errorMessage ?? "") }
        .task { loadFixtureIfRequested() }
    }

    /// 解像度シート。開始で解析を走らせ、保存されたら一覧に反映する
    private var resolutionSheet: some View {
        ResolutionSheet(importer: importer) {
            importer.start(store: model.store) { record in
                model.didSave(record)
                applyStaleVersionIfRequested(record)
            }
        }
    }

    /// PER-07 の E2E 検証用: -uiTestStaleVersion 指定時、新規取り込み直後だけ解析方式を古い値へ書き換える
    /// （再解析時は除く。そうしないと再解析してもバナーが消えず検証できない）
    private func applyStaleVersionIfRequested(_ record: AnalysisRecord) {
        guard environment.launch.staleVersion, !importer.isReanalysis else { return }
        try? environment.store.overrideAnalysisVersion(id: record.id, to: "hsb-dominant-v0")
        model.reload()
    }

    /// エラー文言の有無をアラート表示のバインディングにする
    private func alertBinding<T: AnyObject>(_ keyPath: ReferenceWritableKeyPath<T, String?>, on object: T) -> Binding<Bool> {
        Binding(get: { object[keyPath: keyPath] != nil }, set: { if !$0 { object[keyPath: keyPath] = nil } })
    }

    /// E2E テストの起動引数で指定されたフィクスチャを取り込みフローに流す
    private func loadFixtureIfRequested() {
        guard let name = environment.launch.fixtureName, let data = fixtureData(named: name) else { return }
        importer.receive(imageData: data, fileExtension: "png", source: .files, fileName: "\(name).png")
    }

    /// IMP-06 検証用の "corrupt-data" は非画像バイト列、それ以外はバンドル内の PNG を読む
    private func fixtureData(named name: String) -> Data? {
        if name == "corrupt-data" { return Data("not-an-image".utf8) }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
        return try? Data(contentsOf: url)
    }
}
