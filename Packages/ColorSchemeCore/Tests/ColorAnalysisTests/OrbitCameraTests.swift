import Testing
import ColorAnalysis

/// BAR-07: 3D ビューのカメラ状態。初期姿勢・回転・ズーム範囲・リセット・俯瞰。
struct OrbitCameraTests {
    /// 初期カメラは方位 30°・仰角 45°・ズーム 1
    @Test func initialPose() {
        let c = OrbitCamera.initial
        #expect(c.azimuth == 30 && c.elevation == 45 && c.zoom == 1)
    }

    /// 右へドラッグすると方位が増え、上へドラッグ（dy < 0）すると仰角が増える（1pt = 0.5°）
    @Test func dragRotates() {
        var c = OrbitCamera.initial
        c.rotate(dragX: 20, dragY: -10)
        #expect(c.azimuth == 40 && c.elevation == 50)
    }

    /// 仰角は 5°〜89.9° に収める
    @Test func elevationIsClamped() {
        var c = OrbitCamera.initial
        c.rotate(dragX: 0, dragY: -1000)
        #expect(c.elevation == 89.9)
        c.rotate(dragX: 0, dragY: 1000)
        #expect(c.elevation == 5)
    }

    /// 方位は 0〜360 に折り返す
    @Test func azimuthWraps() {
        var c = OrbitCamera.initial
        c.rotate(dragX: 700, dragY: 0)
        #expect(c.azimuth == 20)
    }

    /// ズームは 0.5〜4 倍に収める
    @Test func zoomIsClamped() {
        var c = OrbitCamera.initial
        c.zoom(by: 10)
        #expect(c.zoom == 4)
        c.zoom(by: 0.01)
        #expect(c.zoom == 0.5)
    }

    /// 俯瞰は真上（仰角 89.9°、方位 0）でズームは保つ
    @Test func topDownPreset() {
        var c = OrbitCamera.initial
        c.zoom(by: 2)
        c.topDown()
        #expect(c.elevation == 89.9 && c.azimuth == 0 && c.zoom == 2)
    }

    /// 方位 0・仰角 0 のカメラは +z（手前）に、仰角 90 は真上にある
    @Test func positionOnOrbit() {
        let front = OrbitCamera(azimuth: 0, elevation: 0, zoom: 1).position(fitDistance: 10)
        expectClose(front, (0, 0, 10))
        let top = OrbitCamera(azimuth: 0, elevation: 90, zoom: 1).position(fitDistance: 10)
        expectClose(top, (0, 10, 0))
        let right = OrbitCamera(azimuth: 90, elevation: 0, zoom: 2).position(fitDistance: 10)
        expectClose(right, (5, 0, 0))
    }

    /// 2×2・最大高さ 1 のグリッドを包む球（半径 √3）は視野 60° で距離 2√3 に収まる
    @Test func fitDistanceForSmallGrid() {
        let d = OrbitCamera.fitDistance(columns: 2, rows: 2, maxHeight: 1, fovDegrees: 60)
        #expect(abs(d - 2 * 3.0.squareRoot()) < 1e-6)
    }

    /// 縦長（幅/高さ = 0.75）の画面では横方向の視野角 2·atan(tan 30° × 0.75) ≈ 46.8° で決まり、距離は √3 / sin(23.4°) ≈ 4.359
    @Test func fitDistanceUsesNarrowerAxisInPortrait() {
        let portrait = OrbitCamera.fitDistance(columns: 2, rows: 2, maxHeight: 1, fovDegrees: 60, aspectRatio: 0.75)
        #expect(abs(portrait - 4.3589) < 1e-3)
        let landscape = OrbitCamera.fitDistance(columns: 2, rows: 2, maxHeight: 1, fovDegrees: 60, aspectRatio: 1.5)
        #expect(abs(landscape - 2 * 3.0.squareRoot()) < 1e-6, "横長では縦の視野角で決まる")
    }

    /// 3 成分を 1e-6 の許容で比較する
    private func expectClose(_ p: OrbitCamera.Vector, _ e: (Float, Float, Float)) {
        #expect(abs(p.x - e.0) < 1e-6 && abs(p.y - e.1) < 1e-6 && abs(p.z - e.2) < 1e-6, "\(p) ≠ \(e)")
    }
}
