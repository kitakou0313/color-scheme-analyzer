import AnalysisWorkflow
import Persistence
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// サイドバー: 保存済み解析の一覧と取り込みの入口（LIB-01〜LIB-07, IMP-01）
struct LibrarySidebar: View {
    @Bindable var model: AppModel
    @Bindable var importer: ImportController
    @State private var showsPhotoPicker = false
    @State private var showsFileImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingDelete: AnalysisRecord?
    @State private var renaming: AnalysisRecord?
    @State private var newName = ""

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(model.records) { record in
                LibraryRow(record: record)
                    .tag(record.id)
                    .swipeActions { Button("削除", role: .destructive) { pendingDelete = record } }
                    .contextMenu { Button("名前を変更") { beginRename(record) } }
            }
        }
        .accessibilityIdentifier("library.list")
        .overlay { if model.records.isEmpty { emptyState } }
        .navigationTitle("ライブラリ")
        .toolbar { ToolbarItem(placement: .primaryAction) { AddMenu(importer: importer) } }
        .modifier(pickers)
        .modifier(dialogs)
    }

    /// LIB-05: 0 件のときの案内
    private var emptyState: some View {
        ContentUnavailableView {
            Label("まだ解析がありません", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("＋から画像を取り込んでください")
        }
        .accessibilityIdentifier("library.emptyState")
    }

    /// 写真ピッカーとファイルピッカー。pickerRequest の変化で開く
    private var pickers: some ViewModifier {
        PickerModifiers(
            showsPhotoPicker: $showsPhotoPicker, showsFileImporter: $showsFileImporter, photoItem: $photoItem,
            pickerRequest: $importer.pickerRequest, onPhoto: loadPhoto, onFile: handleFile
        )
    }

    /// 削除の確認と改名の入力
    private var dialogs: some ViewModifier {
        LibraryDialogs(
            pendingDelete: $pendingDelete, renaming: $renaming, newName: $newName,
            onDelete: { model.delete($0.id) }, onRename: { model.rename($0.id, to: newName) }
        )
    }

    /// 改名アラートを現在の名前で開く
    private func beginRename(_ record: AnalysisRecord) {
        newName = record.name
        renaming = record
    }

    /// 写真ライブラリの選択結果を読み、取り込みへ渡す
    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                importer.errorMessage = ImportFailure.unreadableImage
                return
            }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            importer.receive(imageData: data, fileExtension: ext, source: .photoLibrary, fileName: nil)
        }
    }

    /// ファイルピッカーの結果を読み、取り込みへ渡す
    private func handleFile(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importer.errorMessage = ImportFailure.unreadableImage
            return
        }
        importer.receive(imageData: data, fileExtension: url.pathExtension.lowercased(), source: .files, fileName: url.lastPathComponent)
    }
}

/// 一覧の 1 行: サムネイル・名前・作成日時・グリッドサイズ（LIB-01）
struct LibraryRow: View {
    let record: AnalysisRecord

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name).font(.body).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library.row")
    }

    /// 作成日時とグリッドサイズ
    private var subtitle: String {
        "\(record.createdAt.formatted(date: .abbreviated, time: .shortened))・\(record.gridWidth)×\(record.gridHeight)"
    }

    /// 保存済みサムネイル
    private var thumbnail: some View {
        Group {
            if let image = UIImage(data: record.thumbnail) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// ツールバーの「＋」メニュー（LIB-06）
struct AddMenu: View {
    let importer: ImportController

    var body: some View {
        Menu {
            Button("写真から", systemImage: "photo") { importer.pickerRequest = .photoLibrary }
                .accessibilityIdentifier("import.fromPhotos")
            Button("ファイルから", systemImage: "folder") { importer.pickerRequest = .files }
                .accessibilityIdentifier("import.fromFiles")
        } label: {
            Label("取り込み", systemImage: "plus")
        }
        .accessibilityIdentifier("library.addButton")
    }
}

/// 写真・ファイルのピッカーをまとめた修飾子
private struct PickerModifiers: ViewModifier {
    @Binding var showsPhotoPicker: Bool
    @Binding var showsFileImporter: Bool
    @Binding var photoItem: PhotosPickerItem?
    @Binding var pickerRequest: ImportSource?
    let onPhoto: (PhotosPickerItem?) -> Void
    let onFile: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItem, matching: .images)
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.image], onCompletion: onFile)
            .onChange(of: photoItem) { _, item in onPhoto(item) }
            .onChange(of: pickerRequest) { _, request in open(request) }
    }

    /// 要求されたピッカーを開き、要求を消す
    private func open(_ request: ImportSource?) {
        switch request {
        case .photoLibrary: showsPhotoPicker = true
        case .files: showsFileImporter = true
        case nil: return
        }
        pickerRequest = nil
    }
}

/// 削除確認と改名アラートをまとめた修飾子（LIB-03, LIB-04）
private struct LibraryDialogs: ViewModifier {
    @Binding var pendingDelete: AnalysisRecord?
    @Binding var renaming: AnalysisRecord?
    @Binding var newName: String
    let onDelete: (AnalysisRecord) -> Void
    let onRename: (AnalysisRecord) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("この解析を削除しますか？", isPresented: isPresented($pendingDelete), titleVisibility: .visible) {
                Button("削除", role: .destructive) { pendingDelete.map(onDelete) }
                    .accessibilityIdentifier("library.confirmDelete")
            }
            .alert("名前を変更", isPresented: isPresented($renaming)) {
                TextField("名前", text: $newName).accessibilityIdentifier("library.renameField")
                Button("保存") { renaming.map(onRename) }.accessibilityIdentifier("library.renameSave")
                Button("キャンセル", role: .cancel) {}
            }
    }

    /// Optional の有無を表示バインディングにする
    private func isPresented(_ value: Binding<AnalysisRecord?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
