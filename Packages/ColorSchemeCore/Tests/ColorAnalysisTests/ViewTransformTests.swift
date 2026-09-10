import Testing
import ColorAnalysis

/// HUE-09: 2 本指ズーム/パンの変換と、画面上の点を変換前の座標へ戻す計算。
struct ViewTransformTests {
    /// 初期状態は等倍・移動なしで、点はそのまま返る
    @Test func identityLeavesPointsUnchanged() {
        let t = ViewTransform.identity
        let p = t.unapply(x: 123, y: 45, anchorX: 200, anchorY: 200)
        #expect(p.x == 123 && p.y == 45)
    }

    /// 2 倍・(10, 0) 移動のとき、画面 (210, 200) は変換前の中心 (200, 200)、(410, 400) は (300, 300)
    @Test func unappliesScaleAndOffsetAroundAnchor() {
        var t = ViewTransform.identity
        t.magnify(by: 2)
        t.pan(dx: 10, dy: 0)
        let center = t.unapply(x: 210, y: 200, anchorX: 200, anchorY: 200)
        #expect(center.x == 200 && center.y == 200)
        let corner = t.unapply(x: 410, y: 400, anchorX: 200, anchorY: 200)
        #expect(corner.x == 300 && corner.y == 300)
    }

    /// apply は unapply の逆（変換前 (300, 300) は 2 倍・(10, 0) 移動で画面 (410, 400)）
    @Test func applyIsInverseOfUnapply() {
        var t = ViewTransform.identity
        t.magnify(by: 2)
        t.pan(dx: 10, dy: 0)
        let p = t.apply(x: 300, y: 300, anchorX: 200, anchorY: 200)
        #expect(p.x == 410 && p.y == 400)
    }

    /// 倍率は 1〜8 倍に収める（縮小はできない）
    @Test func scaleIsClamped() {
        var t = ViewTransform.identity
        t.magnify(by: 100)
        #expect(t.scale == 8)
        t.magnify(by: 0.001)
        #expect(t.scale == 1)
    }

    /// 等倍に戻すとパンも消える
    @Test func resetClearsPan() {
        var t = ViewTransform.identity
        t.magnify(by: 3)
        t.pan(dx: 50, dy: -20)
        t.reset()
        #expect(t == .identity)
    }
}
