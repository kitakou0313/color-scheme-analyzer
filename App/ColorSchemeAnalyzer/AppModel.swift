import Foundation
import Observation
import Persistence

/// ライブラリの状態（一覧・選択・削除・改名）。LIB-01〜LIB-04
@Observable
final class AppModel {
    let store: AnalysisStore
    private(set) var records: [AnalysisRecord] = []
    var selectedID: UUID?
    var errorMessage: String?

    /// ストアを受け取り、一覧を読み込む
    init(store: AnalysisStore) {
        self.store = store
        reload()
    }

    /// 選択中のレコード
    var selectedRecord: AnalysisRecord? {
        records.first { $0.id == selectedID }
    }

    /// 一覧を作成日時の降順で読み直す
    func reload() {
        do { records = try store.list() } catch { errorMessage = "保存済みの解析を読み込めませんでした" }
    }

    /// 解析を削除する。選択中なら選択を外す（LIB-03）
    func delete(_ id: UUID) {
        do {
            try store.delete(id: id)
            if selectedID == id { selectedID = nil }
            reload()
        } catch {
            errorMessage = "削除できませんでした"
        }
    }

    /// 名前を変更する。空文字は拒否する（LIB-04）
    func rename(_ id: UUID, to name: String) {
        do {
            try store.rename(id: id, to: name)
            reload()
        } catch AnalysisStoreError.emptyName {
            errorMessage = "名前を入力してください"
        } catch {
            errorMessage = "名前を変更できませんでした"
        }
    }

    /// 取り込み・再解析の結果を一覧に反映し、そのレコードを選択する（IMP-04）
    func didSave(_ record: AnalysisRecord) {
        reload()
        selectedID = record.id
    }
}
