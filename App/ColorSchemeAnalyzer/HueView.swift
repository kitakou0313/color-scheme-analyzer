import ColorAnalysis
import CoreGraphics
import SwiftUI

/// 色相画面（HUE-01〜HUE-09）。画像上の 1 ピクセルを選び、色相環と数値で示す
struct HueView: View {
    let image: PixelImage
    let cgImage: CGImage
    @State private var selection: ImageFit.Pixel?
    @State private var transform = ViewTransform.identity
    @State private var panStart: ViewTransform?
    @State private var pinchStart: ViewTransform?

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(spacing: 0) { imageArea; panel.frame(width: 300) }
            } else {
                VStack(spacing: 0) { imageArea; panel.frame(height: 280) }
            }
        }
    }

    /// 選択ピクセルの表示値
    private var readout: HueReadout? {
        selection.map { HueReadout(image[x: $0.x, y: $0.y]) }
    }

    /// 画像と十字マーカー。ジェスチャは外側の（拡大していない）コンテナで受ける
    private var imageArea: some View {
        GeometryReader { geo in
            let fit = ImageFit.aspectFit(imageWidth: image.width, imageHeight: image.height, viewWidth: geo.size.width, viewHeight: geo.size.height)
            ZStack {
                Color(white: 0.92)
                scaledImage(fit)
                if let selection { Crosshair().position(markerPoint(selection, fit: fit, size: geo.size)) }
                if selection == nil { hint }
            }
            .contentShape(Rectangle())
            .clipped()
            .gesture(SingleTouchSelectGesture { select($0, fit: fit, size: geo.size) })
            .gesture(TwoFingerPanGesture(onBegan: { panStart = transform }, onChanged: pan))
            .gesture(PinchZoomGesture(onBegan: { pinchStart = transform }, onChanged: pinch, onEnded: endPinch))
        }
    }

    /// HUE-01/HUE-09: 収めて表示した画像に拡大・移動を適用する
    private func scaledImage(_ fit: ImageFit) -> some View {
        Image(cgImage, scale: 1, label: Text("解析画像"))
            .resizable()
            .interpolation(.none)
            .frame(width: fit.frame.width, height: fit.frame.height)
            .position(x: fit.frame.x + fit.frame.width / 2, y: fit.frame.y + fit.frame.height / 2)
            .scaleEffect(transform.scale)
            .offset(x: transform.offsetX, y: transform.offsetY)
            .accessibilityIdentifier("hue.image")
    }

    /// HUE-04: 初期状態のヒント
    private var hint: some View {
        Text("画像をタップまたはなぞって色を選択")
            .padding(10).background(.thinMaterial, in: Capsule())
            .accessibilityIdentifier("hue.hint")
    }

    /// HUE-02: 画面上の点を拡大前の座標に戻し、ピクセルを選ぶ。画像の外なら選択を変えない
    private func select(_ point: CGPoint, fit: ImageFit, size: CGSize) {
        let p = transform.unapply(x: point.x, y: point.y, anchorX: size.width / 2, anchorY: size.height / 2)
        if let pixel = fit.pixel(atViewX: p.x, viewY: p.y) { selection = pixel }
    }

    /// HUE-03: 選択ピクセル中心の画面座標（拡大・移動を適用）
    private func markerPoint(_ pixel: ImageFit.Pixel, fit: ImageFit, size: CGSize) -> CGPoint {
        let center = fit.viewPoint(ofPixel: pixel)
        let p = transform.apply(x: center.x, y: center.y, anchorX: size.width / 2, anchorY: size.height / 2)
        return CGPoint(x: p.x, y: p.y)
    }

    /// HUE-09: 2 本指ドラッグで移動
    private func pan(_ translation: CGSize) {
        var next = panStart ?? transform
        next.pan(dx: translation.width, dy: translation.height)
        transform = next
    }

    /// HUE-09: ピンチで拡大
    private func pinch(_ scale: CGFloat) {
        var next = pinchStart ?? transform
        next.magnify(by: scale)
        transform = next
    }

    /// 等倍に戻ったら移動も消す
    private func endPinch() {
        if transform.scale <= 1 { transform.reset() }
    }

    /// 色相環・数値・スウォッチ
    private var panel: some View {
        VStack(spacing: 20) {
            HueWheelView(hue: selection.map { HSB(image[x: $0.x, y: $0.y]).hue } ?? nil, isAchromatic: readout?.isAchromatic ?? true)
                .frame(width: 200, height: 200)
                .accessibilityIdentifier("hue.wheel")
            HueReadoutView(readout: readout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

/// HUE-07, HUE-08: H/S/B の数値とスウォッチ
struct HueReadoutView: View {
    let readout: HueReadout?

    var body: some View {
        VStack(spacing: 8) {
            swatch
            Text(label).font(.title3.monospacedDigit()).accessibilityIdentifier("hue.readout")
        }
    }

    /// 表示文言。未選択 / 無彩色 / H S B
    private var label: String {
        guard let readout else { return "未選択" }
        let sb = "S \(readout.saturationPercent)% B \(readout.brightnessPercent)%"
        guard let hue = readout.hueDegrees else { return "無彩色 \(sb)" }
        return "H \(hue)° \(sb)"
    }

    /// 選択色
    private var swatch: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(readout.map { Color($0.color) } ?? Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4)))
            .frame(width: 96, height: 48)
            .accessibilityIdentifier("hue.swatch")
    }
}

/// HUE-03: 白黒二重線の十字マーカー
struct Crosshair: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.white).frame(width: 3, height: 30)
            Rectangle().fill(.white).frame(width: 30, height: 3)
            Rectangle().fill(.black).frame(width: 1, height: 28)
            Rectangle().fill(.black).frame(width: 28, height: 1)
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("hue.marker")
    }
}

extension Color {
    /// sRGB 8bit の色から SwiftUI の色を作る
    init(_ rgb: RGB8) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }
}
