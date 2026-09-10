import Foundation
import ImageDecoding

/// 画像の入力元（IMP-01）
public enum ImportSource: Hashable, Sendable {
    case photoLibrary
    case files
}

/// 解析の既定名（IMP-05）
public enum ImportNaming {
    /// ファイル経由は拡張子を除いた元ファイル名、写真経由（または名前が取れない場合）は取り込み日時
    public static func defaultName(source: ImportSource, fileName: String?, date: Date, timeZone: TimeZone) -> String {
        if source == .files, let stem = fileName.map({ ($0 as NSString).deletingPathExtension }), !stem.isEmpty {
            return stem
        }
        return dateName(date, timeZone: timeZone)
    }

    /// 「yyyy-MM-dd HH:mm」形式の日時文字列
    static func dateName(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 解像度シートの選択肢と既定値（IMP-02）
public enum ResolutionPreference {
    public static let options = [32, 64, 128]
    public static let defaultValue = 64
    /// UserDefaults に前回値を保存するキー
    public static let userDefaultsKey = "lastLongSideCells"

    /// 保存値が選択肢にあればそれ、なければ既定値
    public static func resolve(stored: Int?) -> Int {
        guard let stored, options.contains(stored) else { return defaultValue }
        return stored
    }
}

/// 取り込み失敗時の表示文言（IMP-03, IMP-06, IMP-07）
public enum ImportFailure {
    public static let unreadableImage = "この画像は読み込めません"
    public static let saveFailed = "解析結果を保存できませんでした"

    /// エラーを表示文言にする。キャンセルは表示しないので nil
    public static func message(for error: Error) -> String? {
        if error is CancellationError { return nil }
        if error is ImageDecodingError { return unreadableImage }
        return saveFailed
    }
}
