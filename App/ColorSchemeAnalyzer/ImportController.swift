import AnalysisWorkflow
import Foundation
import Observation
import Persistence

/// 取り込みと再解析の進行状態（IMP-02〜IMP-07, DET-03）
@Observable
final class ImportController {
    /// 解像度シートで開始待ちの仕事
    enum Job: Equatable {
        case newImport(imageData: Data, fileExtension: String, name: String)
        case reanalysis(AnalysisRecord)
    }

    enum Stage: Equatable {
        case idle
        case choosingResolution
        case analyzing
    }

    private(set) var stage: Stage = .idle
    private(set) var job: Job?
    private(set) var progress: Double = 0
    /// 解像度シートの選択値（前回値を UserDefaults に記憶）
    var longSideCells: Int
    var errorMessage: String?
    /// 空状態などから要求されたピッカー。サイドバーが監視して表示する
    var pickerRequest: ImportSource?
    private var task: Task<Void, Never>?
    private let defaults: UserDefaults
    /// IMP-03, NFR-03 の E2E 検証用: 解析開始直後に入れる人工的な待ち（-uiTestSlowAnalysis）
    private let testingAnalysisDelay: Duration?

    /// 前回の解像度を読み込む
    init(defaults: UserDefaults = .standard, testingAnalysisDelay: Duration? = nil) {
        self.defaults = defaults
        self.testingAnalysisDelay = testingAnalysisDelay
        longSideCells = ResolutionPreference.resolve(stored: defaults.object(forKey: ResolutionPreference.userDefaultsKey) as? Int)
    }

    /// 解像度シートを出すかどうか。閉じられたら仕事を捨てる
    var showsResolutionSheet: Bool {
        get { stage == .choosingResolution }
        set { if !newValue, stage == .choosingResolution { cancelChoice() } }
    }

    /// 再解析の仕事か
    var isReanalysis: Bool {
        if case .reanalysis = job { return true }
        return false
    }

    /// 画像を受け取り、既定名を付けて解像度シートへ進む（IMP-05）
    func receive(imageData: Data, fileExtension: String, source: ImportSource, fileName: String?) {
        let name = ImportNaming.defaultName(source: source, fileName: fileName, date: Date(), timeZone: .current)
        job = .newImport(imageData: imageData, fileExtension: fileExtension, name: name)
        stage = .choosingResolution
    }

    /// 既存レコードの再解析を要求し、解像度シートへ進む（DET-03）
    func requestReanalysis(of record: AnalysisRecord) {
        job = .reanalysis(record)
        stage = .choosingResolution
    }

    /// 解像度シートを閉じて仕事を捨てる
    func cancelChoice() {
        job = nil
        stage = .idle
    }

    /// 選んだ解像度で解析を始める。完了したら onSaved を呼ぶ
    func start(store: AnalysisStore, onSaved: @escaping (AnalysisRecord) -> Void) {
        guard let job else { return }
        defaults.set(longSideCells, forKey: ResolutionPreference.userDefaultsKey)
        stage = .analyzing
        progress = 0
        let cells = longSideCells
        task = Task { await run(job, cells: cells, store: store, onSaved: onSaved) }
    }

    /// 実行中の解析をキャンセルする（IMP-03）
    func cancel() {
        task?.cancel()
    }

    /// 仕事を実行し、結果か失敗文言を反映してアイドルに戻る
    private func run(_ job: Job, cells: Int, store: AnalysisStore, onSaved: (AnalysisRecord) -> Void) async {
        do {
            if let testingAnalysisDelay { try await Task.sleep(for: testingAnalysisDelay) }
            onSaved(try await perform(job, cells: cells, store: store))
        } catch {
            errorMessage = ImportFailure.message(for: error)
        }
        stage = .idle
        self.job = nil
        task = nil
    }

    /// 新規取り込みか再解析かに応じて Core のサービスを呼ぶ
    private func perform(_ job: Job, cells: Int, store: AnalysisStore) async throws -> AnalysisRecord {
        switch job {
        case let .newImport(imageData, fileExtension, name):
            let request = ImportRequest(imageData: imageData, fileExtension: fileExtension, name: name, longSideCells: cells)
            return try await ImportService.run(request, store: store) { [weak self] value in
                Task { @MainActor in self?.progress = value }
            }
        case let .reanalysis(record):
            return try await ImportService.reanalyze(record, longSideCells: cells, store: store)
        }
    }
}
