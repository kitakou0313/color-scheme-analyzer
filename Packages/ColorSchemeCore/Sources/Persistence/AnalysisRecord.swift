import ColorAnalysis
import Foundation
import GRDB

/// テーブル `analyses` の 1 行（blueprint 5 章のスキーマ）。列名は snake_case。
public struct AnalysisRecord: Codable, Hashable, Sendable, Identifiable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "analyses"
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    /// 日時は ISO8601 テキストで保存する
    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy { .iso8601 }

    /// ISO8601 テキストから日時を読む
    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy { .iso8601 }

    /// UUID は大文字の文字列（TEXT）で保存する
    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy { .uppercaseString }

    public var id: UUID
    public var name: String
    public var createdAt: Date
    /// Documents からの相対パス（例 images/<UUID>.png）
    public var imagePath: String
    public var imageWidth: Int
    public var imageHeight: Int
    public var gridWidth: Int
    public var gridHeight: Int
    public var longSideCells: Int
    /// RGB8 × セル数
    public var cellColor: Data
    /// Float32 LE × セル数
    public var cellSaturation: Data
    /// Float32 LE × セル数
    public var cellBrightness: Data
    public var thumbnail: Data
    public var analysisVersion: String

    /// セル数（grid_width × grid_height）
    public var cellCount: Int { gridWidth * gridHeight }

    /// 各セルの代表色（BLOB をデコード）
    public var colors: [RGB8] { CellBlobs.decodeColors(cellColor) }

    /// 各セルの平均彩度（BLOB をデコード）
    public var saturations: [Float] { CellBlobs.decodeFloats(cellSaturation) }

    /// 各セルの平均明度（BLOB をデコード）
    public var brightnesses: [Float] { CellBlobs.decodeFloats(cellBrightness) }

    /// 棒グラフ用に解析結果へ戻す（hue は保存していないので nil）
    public var grid: GridLayout {
        GridLayout(imageWidth: imageWidth, imageHeight: imageHeight, longSideCells: longSideCells)
    }
}

/// 保存する新規解析の入力
public struct NewAnalysis: Sendable {
    public var name: String
    public var createdAt: Date
    public var imageData: Data
    public var fileExtension: String
    public var imageWidth: Int
    public var imageHeight: Int
    public var result: AnalysisResult
    public var thumbnail: Data
    public var analysisVersion: String

    /// 各値を指定して生成する
    public init(
        name: String, createdAt: Date, imageData: Data, fileExtension: String, imageWidth: Int, imageHeight: Int,
        result: AnalysisResult, thumbnail: Data, analysisVersion: String
    ) {
        self.name = name
        self.createdAt = createdAt
        self.imageData = imageData
        self.fileExtension = fileExtension
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.result = result
        self.thumbnail = thumbnail
        self.analysisVersion = analysisVersion
    }
}
