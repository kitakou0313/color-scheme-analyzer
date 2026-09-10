import AnalysisWorkflow
import ColorAnalysis
import CoreGraphics
import ImageDecoding
import Persistence
import SwiftUI

/// 詳細ペイン。選択があれば解析詳細、なければ空状態（DET-04）
struct DetailContainer: View {
    let model: AppModel
    let importer: ImportController

    var body: some View {
        if let record = model.selectedRecord {
            AnalysisDetailView(record: record, store: model.store, importer: importer).id(record.id)
        } else {
            EmptyDetailView(importer: importer)
        }
    }
}

/// DET-04: 未選択時の案内と取り込みボタン
struct EmptyDetailView: View {
    let importer: ImportController

    var body: some View {
        ContentUnavailableView {
            Label("解析を選択", systemImage: "square.grid.3x3")
        } description: {
            Text("左の一覧から解析を選ぶか、＋で画像を取り込んでください")
        } actions: {
            AddMenu(importer: importer).buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("detail.emptyState")
    }
}

/// 解析詳細の 3 画面
enum DetailTab: String, CaseIterable, Identifiable {
    case saturation = "彩度"
    case brightness = "明度"
    case hue = "色相"

    var id: String { rawValue }
}

/// 解析詳細。セグメントで彩度・明度・色相を切り替える（DET-01〜DET-03, PER-07）
struct AnalysisDetailView: View {
    let record: AnalysisRecord
    let store: AnalysisStore
    let importer: ImportController
    @State private var tab: DetailTab = .saturation
    @State private var showsFloor = true
    @State private var image: PixelImage?
    @State private var cgImage: CGImage?

    var body: some View {
        VStack(spacing: 0) {
            picker.padding()
            versionBanner
            content
        }
        .navigationTitle(record.name)
        .toolbar { toolbar }
        .task(id: record.imagePath) { await loadImage() }
    }

    /// DET-01: セグメントコントロール
    private var picker: some View {
        Picker("表示", selection: $tab) {
            ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("detail.segment")
    }

    /// PER-07: 解析方式が古いときの案内
    @ViewBuilder private var versionBanner: some View {
        if record.analysisVersion != ImageAnalyzer.version {
            Text("解析方式が更新されています。再解析できます")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 8)
                .accessibilityIdentifier("detail.versionBanner")
        }
    }

    /// 選択中の画面
    @ViewBuilder private var content: some View {
        switch tab {
        case .saturation:
            BarChartView(record: record, metric: .saturation, floorImage: cgImage, showsFloor: showsFloor)
        case .brightness:
            BarChartView(record: record, metric: .brightness, floorImage: cgImage, showsFloor: showsFloor)
        case .hue:
            if let image, let cgImage { HueView(image: image, cgImage: cgImage) } else { ProgressView() }
        }
    }

    /// DET-03 の再解析と BAR-06 の床トグル（3D の画面でのみ表示。ボタン型トグルで常に見える）
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if tab != .hue {
                Toggle("床に画像", systemImage: "photo", isOn: $showsFloor)
                    .toggleStyle(.button)
                    .accessibilityIdentifier("bar.floorToggle")
            }
            Button("再解析", systemImage: "arrow.clockwise") { importer.requestReanalysis(of: record) }
                .accessibilityIdentifier("detail.reanalyze")
        }
    }

    /// 保存済み画像を解析画像として背景で読み、表示用の CGImage も作る
    private func loadImage() async {
        let record = record, store = store
        let loaded = try? await Task.detached(priority: .userInitiated) {
            try ImportService.loadImage(for: record, store: store)
        }.value
        image = loaded
        cgImage = loaded.flatMap { ImageDecoder.makeCGImage($0) }
    }
}

/// 解像度シート（IMP-02）。取り込みと再解析の両方で使う
struct ResolutionSheet: View {
    @Bindable var importer: ImportController
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("長辺のセル数") {
                    Picker("解像度", selection: $importer.longSideCells) {
                        ForEach(ResolutionPreference.options, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("import.resolution.picker")
                }
                Section { Text("画像の長辺をこの数のセルに分け、セルごとに棒を立てます。大きいほど細かく、解析に時間がかかります。") }
            }
            .navigationTitle(importer.isReanalysis ? "再解析" : "取り込み")
            .toolbar { sheetToolbar }
        }
        .presentationDetents([.medium])
    }

    /// キャンセルと開始
    @ToolbarContentBuilder private var sheetToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") { importer.cancelChoice() }.accessibilityIdentifier("import.resolution.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("開始", action: onStart).accessibilityIdentifier("import.resolution.start")
        }
    }
}

/// 解析中の進捗とキャンセル（IMP-03, NFR-03）
struct ProgressOverlay: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: progress).frame(width: 240).accessibilityIdentifier("import.progress")
                Text("解析中…").font(.headline)
                Button("キャンセル", action: onCancel).accessibilityIdentifier("import.progress.cancel")
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
