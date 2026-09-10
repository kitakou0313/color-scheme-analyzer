import Foundation
import Testing
import AnalysisWorkflow
import ImageDecoding

/// IMP-02, IMP-05, IMP-06: 取り込みフローの純粋ロジック（既定名・解像度の既定値・失敗メッセージ）。
struct ImportFlowTests {
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let date = Date(timeIntervalSince1970: 1_788_865_200) // 2026-09-08T11:00:00Z = 2026-09-08 20:00 JST

    /// IMP-05: ファイル経由は拡張子を除いた元ファイル名
    @Test func fileNameWithoutExtension() {
        let name = ImportNaming.defaultName(source: .files, fileName: "IMG_0001.HEIC", date: Self.date, timeZone: Self.tokyo)
        #expect(name == "IMG_0001")
    }

    /// IMP-05: 写真ライブラリ経由は取り込み日時「yyyy-MM-dd HH:mm」（ローカル時刻）
    @Test func photoLibraryUsesDateTime() {
        let name = ImportNaming.defaultName(source: .photoLibrary, fileName: nil, date: Self.date, timeZone: Self.tokyo)
        #expect(name == "2026-09-08 20:00")
    }

    /// IMP-05: ファイル名が空ならファイル経由でも日時にする
    @Test func emptyFileNameFallsBackToDate() {
        let name = ImportNaming.defaultName(source: .files, fileName: "", date: Self.date, timeZone: Self.tokyo)
        #expect(name == "2026-09-08 20:00")
    }

    /// IMP-02: 解像度の選択肢は 32/64/128、保存値がなければ 64、選択肢にない値も 64
    @Test func resolutionPreference() {
        #expect(ResolutionPreference.options == [32, 64, 128])
        #expect(ResolutionPreference.resolve(stored: nil) == 64)
        #expect(ResolutionPreference.resolve(stored: 128) == 128)
        #expect(ResolutionPreference.resolve(stored: 99) == 64)
    }

    /// IMP-06: 読み込めない画像は「この画像は読み込めません」
    @Test func unsupportedImageMessage() {
        #expect(ImportFailure.message(for: ImageDecodingError.unsupportedData) == "この画像は読み込めません")
        #expect(ImportFailure.message(for: ImageDecodingError.decodingFailed) == "この画像は読み込めません")
    }

    /// IMP-03: キャンセルはエラー表示しない（nil）
    @Test func cancellationHasNoMessage() {
        #expect(ImportFailure.message(for: CancellationError()) == nil)
    }

    /// IMP-07: それ以外の失敗は保存できなかった旨を表示する
    @Test func otherErrorsReportSaveFailure() {
        struct Boom: Error {}
        #expect(ImportFailure.message(for: Boom()) == "解析結果を保存できませんでした")
    }
}
