import ColorAnalysis
import CoreGraphics
import Persistence
import RealityKit
import SwiftUI

/// 彩度・明度の 3D 棒グラフ（BAR-01〜BAR-09）
struct BarChartView: View {
    let record: AnalysisRecord
    let metric: BarMetric
    let floorImage: CGImage?
    let showsFloor: Bool
    @State private var camera = OrbitCamera.initial
    @State private var dragStart: OrbitCamera?
    @State private var zoomStart: OrbitCamera?

    /// 保存済みレコードから棒の形状を作る。色は BAR-04 に従い彩度画面は代表色、明度画面はグレースケール
    private var geometry: BarGeometry {
        let values = metric == .saturation ? record.saturations : record.brightnesses
        let colors = BarGeometry.barColors(metric: metric, cellColors: record.colors, brightnesses: record.brightnesses)
        return BarGeometry.make(grid: record.grid, values: values, colors: colors, metric: metric)
    }

    var body: some View {
        realityView
            .id("\(record.longSideCells)-\(record.analysisVersion)-\(metric)-\(floorImage != nil)")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("3D 棒グラフ")
            .accessibilityIdentifier("bar.view")
            .gesture(drag.simultaneously(with: magnify))
            .background(Color(white: 0.15))
            .overlay(alignment: .bottomLeading) { legend }
            .overlay(alignment: .topTrailing) { controls }
    }

    /// シーンを組み、状態変化（カメラ・床・表示領域の縦横比）で更新する
    private var realityView: some View {
        let geometry = geometry
        return GeometryReader { geo in
            RealityView { content in
                content.add(await BarChartScene.makeRoot(geometry, floorImage: floorImage))
                content.add(BarChartScene.makeCamera())
                for light in BarChartScene.makeLights() { content.add(light) }
            } update: { content in
                BarChartScene.apply(camera: camera, geometry: geometry, aspectRatio: aspectRatio(geo.size), in: content)
                BarChartScene.setFloorTextured(showsFloor, in: content)
            }
        }
    }

    /// 表示領域の幅 / 高さ（高さ 0 のときは 1）
    private func aspectRatio(_ size: CGSize) -> Double {
        size.height > 0 ? Double(size.width / size.height) : 1
    }

    /// BAR-07: 1 本指ドラッグで回転
    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = dragStart ?? camera
                dragStart = start
                var next = start
                next.rotate(dragX: value.translation.width, dragY: value.translation.height)
                camera = next
            }
            .onEnded { _ in dragStart = nil }
    }

    /// BAR-07: ピンチでズーム
    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? camera
                zoomStart = start
                var next = start
                next.zoom(by: value.magnification)
                camera = next
            }
            .onEnded { _ in zoomStart = nil }
    }

    /// BAR-09, BAR-11: 凡例（高さの意味 + 破線枠の基準棒の説明）
    private var legend: some View {
        Text(legendText)
            .font(.footnote).foregroundStyle(.white)
            .padding(8).background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6)).padding()
            .accessibilityIdentifier("bar.legend")
    }

    /// BAR-11: 画面ごとの凡例文言（彩度/明度で名詞を差し替える）
    private var legendText: String {
        let name = metric == .saturation ? "彩度" : "明度"
        return "高さ = \(name) 0–100%\n破線枠の棒 = \(name)100%の例"
    }

    /// BAR-07: リセットと俯瞰
    private var controls: some View {
        HStack {
            Button("リセット") { camera.reset() }.accessibilityIdentifier("bar.reset")
            Button("俯瞰") { camera.topDown() }.accessibilityIdentifier("bar.topDown")
        }
        .buttonStyle(.bordered).tint(.white).padding()
    }
}
