import Testing
import ColorAnalysis

/// HUE-02: 画面に収めて表示した画像の座標と、解析画像のピクセル座標との対応。
struct ImageFitTests {
    /// 正方形画像を正方形の表示領域に収めると余白なしで全面に広がる
    @Test func squareImageFillsSquareView() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 4, viewWidth: 400, viewHeight: 400)
        #expect(fit.frame == ImageFit.Rect(x: 0, y: 0, width: 400, height: 400))
        #expect(fit.scale == 100)
    }

    /// 横長画像は上下に余白ができ、縦方向の中央に置かれる
    @Test func landscapeImageIsLetterboxed() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 2, viewWidth: 400, viewHeight: 400)
        #expect(fit.frame == ImageFit.Rect(x: 0, y: 100, width: 400, height: 200))
    }

    /// 縦長画像は左右に余白ができ、横方向の中央に置かれる
    @Test func portraitImageIsPillarboxed() {
        let fit = ImageFit.aspectFit(imageWidth: 2, imageHeight: 4, viewWidth: 400, viewHeight: 400)
        #expect(fit.frame == ImageFit.Rect(x: 100, y: 0, width: 200, height: 400))
    }

    /// 画面座標 (150, 350) は 4×4 画像のピクセル (1, 3)
    @Test func viewPointMapsToPixel() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 4, viewWidth: 400, viewHeight: 400)
        #expect(fit.pixel(atViewX: 150, viewY: 350) == ImageFit.Pixel(x: 1, y: 3))
        #expect(fit.pixel(atViewX: 399.9, viewY: 0) == ImageFit.Pixel(x: 3, y: 0))
    }

    /// 画像の外（余白や領域外）は nil
    @Test func outsideImageIsNil() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 2, viewWidth: 400, viewHeight: 400)
        #expect(fit.pixel(atViewX: 10, viewY: 50) == nil)
        #expect(fit.pixel(atViewX: 400, viewY: 150) == nil)
        #expect(fit.pixel(atViewX: -1, viewY: 150) == nil)
    }

    /// 余白のある画像でもピクセルは正しく求まる（(10, 150) → (0, 0)）
    @Test func letterboxedPixelMapping() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 2, viewWidth: 400, viewHeight: 400)
        #expect(fit.pixel(atViewX: 10, viewY: 150) == ImageFit.Pixel(x: 0, y: 0))
    }

    /// ピクセル中心の画面座標（マーカー表示用）。(0,0) の中心は (50, 150)
    @Test func pixelCenterInView() {
        let fit = ImageFit.aspectFit(imageWidth: 4, imageHeight: 2, viewWidth: 400, viewHeight: 400)
        let p = fit.viewPoint(ofPixel: ImageFit.Pixel(x: 0, y: 0))
        #expect(p.x == 50 && p.y == 150)
    }
}
