import AnalysisWorkflow
import SwiftUI

/// ルート画面。サイドバー（ライブラリ）と詳細を NavigationSplitView で並べる
struct RootView: View {
    @State private var model: AppModel
    @State private var importer = ImportController()
    private let environment: AppEnvironment

    /// 環境からライブラリの状態を作る
    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: AppModel(store: environment.store))
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
            importer.start(store: model.store) { model.didSave($0) }
        }
    }

    /// エラー文言の有無をアラート表示のバインディングにする
    private func alertBinding<T: AnyObject>(_ keyPath: ReferenceWritableKeyPath<T, String?>, on object: T) -> Binding<Bool> {
        Binding(get: { object[keyPath: keyPath] != nil }, set: { if !$0 { object[keyPath: keyPath] = nil } })
    }

    /// E2E テストの起動引数で指定されたフィクスチャを取り込みフローに流す
    private func loadFixtureIfRequested() {
        guard let name = environment.launch.fixtureName,
              let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return }
        importer.receive(imageData: data, fileExtension: "png", source: .files, fileName: "\(name).png")
    }
}
