import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// HUE-02: 1 本指のタッチ開始から追従する。2 本目の指が触れたら失敗させ、ズーム/パンに譲る
struct SingleTouchSelectGesture: UIGestureRecognizerRepresentable {
    let onChange: (CGPoint) -> Void

    /// 単一タッチだけを追う認識器を作る
    func makeUIGestureRecognizer(context: Context) -> SingleTouchRecognizer {
        SingleTouchRecognizer()
    }

    /// 開始・移動のたびに局所座標を通知する
    func handleUIGestureRecognizerAction(_ recognizer: SingleTouchRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(context.converter.localLocation)
        default: break
        }
    }
}

/// 1 本指専用の認識器。指が増えたらキャンセルする
final class SingleTouchRecognizer: UIGestureRecognizer {
    /// 1 本目の指で開始し、2 本目以降なら取り消す
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let total = event.touches(for: self)?.count ?? touches.count
        if state == .possible, total == 1 { state = .began } else { state = state == .possible ? .failed : .cancelled }
    }

    /// 動いたら変更を通知する
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .changed }
    }

    /// 離したら終了
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = (state == .began || state == .changed) ? .ended : .failed
    }

    /// システムによる取り消し
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

/// HUE-09: 2 本指ドラッグでパン
struct TwoFingerPanGesture: UIGestureRecognizerRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGSize) -> Void

    /// 2 本指限定のパン認識器。ピンチと同時に動かせるようにする
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.minimumNumberOfTouches = 2
        recognizer.maximumNumberOfTouches = 2
        recognizer.delegate = context.coordinator
        return recognizer
    }

    /// 開始で基準を記録し、移動量を通知する
    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let t = recognizer.translation(in: recognizer.view)
        switch recognizer.state {
        case .began: onBegan(); onChanged(CGSize(width: t.x, height: t.y))
        case .changed: onChanged(CGSize(width: t.x, height: t.y))
        default: break
        }
    }

    /// 同時認識を許可するデリゲート
    func makeCoordinator(converter: CoordinateSpaceConverter) -> SimultaneousGestureCoordinator {
        SimultaneousGestureCoordinator()
    }
}

/// HUE-09: ピンチでズーム
struct PinchZoomGesture: UIGestureRecognizerRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    /// ピンチ認識器。パンと同時に動かせるようにする
    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let recognizer = UIPinchGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    /// 開始で基準を記録し、倍率を通知する
    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began: onBegan(); onChanged(recognizer.scale)
        case .changed: onChanged(recognizer.scale)
        case .ended, .cancelled: onEnded()
        default: break
        }
    }

    /// 同時認識を許可するデリゲート
    func makeCoordinator(converter: CoordinateSpaceConverter) -> SimultaneousGestureCoordinator {
        SimultaneousGestureCoordinator()
    }
}

/// 2 本指パンとピンチを同時に認識させる
final class SimultaneousGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    /// 常に同時認識を許す
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
