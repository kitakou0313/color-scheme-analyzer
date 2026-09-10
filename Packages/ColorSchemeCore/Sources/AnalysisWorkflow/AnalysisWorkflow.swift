import ColorAnalysis
import Foundation
import ImageDecoding
import Persistence

/// 取り込みの入力（IMP-01〜IMP-05）
public struct ImportRequest: Sendable {
    public var imageData: Data
    public var fileExtension: String
    public var name: String
    public var longSideCells: Int
    public var createdAt: Date

    /// 各値を指定して生成する
    public init(imageData: Data, fileExtension: String, name: String, longSideCells: Int, createdAt: Date = Date()) {
        self.imageData = imageData
        self.fileExtension = fileExtension
        self.name = name
        self.longSideCells = longSideCells
        self.createdAt = createdAt
    }
}

/// デコード → 解析 → サムネイル → 保存を束ねる（IMP-03〜IMP-07, DET-03）。
public enum ImportService {
    public static let thumbnailMaxPixelSize = 256
    public static let thumbnailQuality = 0.8

    /// 取り込み一式。progress は 0〜1 を単調に報告する。キャンセル時は何も保存しない
    @concurrent
    public static func run(
        _ request: ImportRequest, store: AnalysisStore, progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> AnalysisRecord {
        progress(0)
        try Task.checkCancellation()
        let image = try ImageDecoder.decode(request.imageData)
        progress(0.2)
        let result = try await ImageAnalyzer.analyze(image, longSideCells: request.longSideCells)
        progress(0.8)
        let record = try store.save(try makeNewAnalysis(request, image: image, result: result))
        progress(1)
        return record
    }

    /// サムネイルを作り、保存用の入力にまとめる。直前にキャンセルを確認する
    private static func makeNewAnalysis(_ request: ImportRequest, image: PixelImage, result: AnalysisResult) throws -> NewAnalysis {
        let thumbnail = try ImageDecoder.thumbnailJPEG(from: request.imageData, maxPixelSize: thumbnailMaxPixelSize, quality: thumbnailQuality)
        try Task.checkCancellation()
        return NewAnalysis(
            name: request.name, createdAt: request.createdAt, imageData: request.imageData, fileExtension: request.fileExtension,
            imageWidth: image.width, imageHeight: image.height, result: result, thumbnail: thumbnail,
            analysisVersion: ImageAnalyzer.version
        )
    }

    /// 保存済みの画像から別解像度で解析し直し、同じレコードを上書きする（PER-05）
    @concurrent
    public static func reanalyze(_ record: AnalysisRecord, longSideCells: Int, store: AnalysisStore) async throws -> AnalysisRecord {
        let image = try loadImage(for: record, store: store)
        let result = try await ImageAnalyzer.analyze(image, longSideCells: longSideCells)
        try store.updateResult(id: record.id, result: result, analysisVersion: ImageAnalyzer.version)
        guard let updated = try store.fetch(id: record.id) else { throw AnalysisStoreError.notFound }
        return updated
    }

    /// 保存済みの画像コピーを解析画像として読む（色相画面の表示・選択に使う）
    public static func loadImage(for record: AnalysisRecord, store: AnalysisStore) throws -> PixelImage {
        try ImageDecoder.decode(contentsOf: store.imageURL(for: record))
    }
}
