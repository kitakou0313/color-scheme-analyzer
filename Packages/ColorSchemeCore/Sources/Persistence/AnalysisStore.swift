import ColorAnalysis
import Foundation
import GRDB

/// 永続化の失敗理由
public enum AnalysisStoreError: Error, Equatable, Sendable {
    /// 空（空白のみ）の名前
    case emptyName
    /// 指定 ID のレコードがない
    case notFound
}

/// 解析レコードの保存先（PER-01〜PER-07）。SQLite の行と Documents/images/ のファイルを一緒に扱う。
public final class AnalysisStore: Sendable {
    private let queue: DatabaseQueue
    /// 画像コピーを置くディレクトリ（Documents/images）
    public let imagesDirectory: URL

    /// ファイル上の DB を開く（なければ作る）。imagesDirectory も作る
    public convenience init(databaseURL: URL, imagesDirectory: URL) throws {
        try self.init(queue: try DatabaseQueue(path: databaseURL.path), imagesDirectory: imagesDirectory)
    }

    /// テスト用にインメモリ DB で開く
    public static func inMemory(imagesDirectory: URL) throws -> AnalysisStore {
        try AnalysisStore(queue: try DatabaseQueue(), imagesDirectory: imagesDirectory)
    }

    /// キューを受け取り、ディレクトリ作成とマイグレーションを行う
    private init(queue: DatabaseQueue, imagesDirectory: URL) throws {
        self.queue = queue
        self.imagesDirectory = imagesDirectory
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try AnalysisStore.migrator.migrate(queue)
    }

    /// スキーマのマイグレーション。v1 でテーブル analyses を作る
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_analyses") { db in
            try db.create(table: "analyses") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("created_at", .text).notNull()
                t.column("image_path", .text).notNull()
                t.column("image_width", .integer).notNull()
                t.column("image_height", .integer).notNull()
                t.column("grid_width", .integer).notNull()
                t.column("grid_height", .integer).notNull()
                t.column("long_side_cells", .integer).notNull()
                t.column("cell_color", .blob).notNull()
                t.column("cell_saturation", .blob).notNull()
                t.column("cell_brightness", .blob).notNull()
                t.column("thumbnail", .blob).notNull()
                t.column("analysis_version", .text).notNull()
            }
        }
        return migrator
    }

    /// 画像をコピーしてから行を挿入する。挿入に失敗したらコピーを消す（PER-02, IMP-07）
    public func save(_ new: NewAnalysis) throws -> AnalysisRecord {
        let record = makeRecord(from: new, id: UUID())
        let fileURL = imageURL(for: record)
        try new.imageData.write(to: fileURL, options: .atomic)
        do {
            try queue.write { db in try record.insert(db) }
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw error
        }
        return record
    }

    /// 入力から行の値を組み立てる
    private func makeRecord(from new: NewAnalysis, id: UUID) -> AnalysisRecord {
        AnalysisRecord(
            id: id, name: new.name, createdAt: new.createdAt,
            imagePath: "images/\(id.uuidString).\(new.fileExtension)",
            imageWidth: new.imageWidth, imageHeight: new.imageHeight,
            gridWidth: new.result.grid.columns, gridHeight: new.result.grid.rows, longSideCells: new.longSideCellsOfResult,
            cellColor: CellBlobs.encodeColors(new.result.colors),
            cellSaturation: CellBlobs.encodeFloats(new.result.saturations),
            cellBrightness: CellBlobs.encodeFloats(new.result.brightnesses),
            thumbnail: new.thumbnail, analysisVersion: new.analysisVersion
        )
    }

    /// 作成日時の降順で全件を返す（LIB-01）
    public func list() throws -> [AnalysisRecord] {
        try queue.read { db in try AnalysisRecord.order(Column("created_at").desc).fetchAll(db) }
    }

    /// ID で 1 件取り出す。なければ nil
    public func fetch(id: UUID) throws -> AnalysisRecord? {
        try queue.read { db in try AnalysisStore.byID(id).fetchOne(db) }
    }

    /// 名前を変更する。空白のみの名前は emptyName（LIB-04）
    public func rename(id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AnalysisStoreError.emptyName }
        try queue.write { db in
            _ = try AnalysisStore.byID(id).updateAll(db, [Column("name").set(to: trimmed)])
        }
    }

    /// 行と画像ファイルを削除する。ファイルが既にない場合は無視する（PER-06）
    public func delete(id: UUID) throws {
        if let record = try fetch(id: id) {
            try? FileManager.default.removeItem(at: imageURL(for: record))
        }
        try queue.write { db in _ = try AnalysisStore.byID(id).deleteAll(db) }
    }

    /// 再解析の結果でグリッド・セル値・バージョンを上書きする（PER-05）
    public func updateResult(id: UUID, result: AnalysisResult, analysisVersion: String) throws {
        try queue.write { db in
            _ = try AnalysisStore.byID(id).updateAll(db, [
                Column("grid_width").set(to: result.grid.columns),
                Column("grid_height").set(to: result.grid.rows),
                Column("long_side_cells").set(to: result.longSideCells),
                Column("cell_color").set(to: CellBlobs.encodeColors(result.colors)),
                Column("cell_saturation").set(to: CellBlobs.encodeFloats(result.saturations)),
                Column("cell_brightness").set(to: CellBlobs.encodeFloats(result.brightnesses)),
                Column("analysis_version").set(to: analysisVersion),
            ])
        }
    }

    /// 画像コピーの絶対 URL
    public func imageURL(for record: AnalysisRecord) -> URL {
        imagesDirectory.appendingPathComponent((record.imagePath as NSString).lastPathComponent)
    }

    /// ID で絞り込むリクエスト（ID は大文字の UUID 文字列で保存している）
    private static func byID(_ id: UUID) -> QueryInterfaceRequest<AnalysisRecord> {
        AnalysisRecord.filter(Column("id") == id.uuidString)
    }
}

extension NewAnalysis {
    /// 結果に含まれる長辺セル数
    var longSideCellsOfResult: Int { result.longSideCells }
}
