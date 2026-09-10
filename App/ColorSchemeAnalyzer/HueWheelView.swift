import ColorAnalysis
import SwiftUI

/// 色相環（HUE-05, HUE-06, HUE-08）。赤を真上に置き時計回り。無彩色ではマーカーを出さない
struct HueWheelView: View {
    let hue: Double?
    let isAchromatic: Bool
    private static let ringWidth: CGFloat = 26

    /// 15° 刻みの色相（時計回りに増える。SwiftUI の角度は 3 時が 0° で時計回りなので −90° から始める）
    private static let hueColors: [Color] = stride(from: 0, through: 360, by: 15).map {
        Color(hue: Double($0 % 360) / 360, saturation: 1, brightness: 1)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ring
                if let hue, !isAchromatic { marker(hue: hue, radius: Double(size / 2 - Self.ringWidth / 2)) }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    /// 色相のリング
    private var ring: some View {
        Circle().strokeBorder(
            AngularGradient(colors: Self.hueColors, center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
            lineWidth: Self.ringWidth
        )
    }

    /// HUE-06: 色相角の位置に置くマーカー（白黒二重の円）
    private func marker(hue: Double, radius: Double) -> some View {
        let p = HueWheel.markerPosition(hue: hue, radius: radius)
        return Circle()
            .strokeBorder(.white, lineWidth: 3)
            .background(Circle().strokeBorder(.black, lineWidth: 1).padding(3))
            .frame(width: 22, height: 22)
            .offset(x: p.x, y: p.y)
            .accessibilityIdentifier("hue.wheel.marker")
    }
}
