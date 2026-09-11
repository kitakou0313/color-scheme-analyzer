import ColorAnalysis
import CoreGraphics
import ImageDecoding
import RealityKit
import SwiftUI

/// RealityKit のシーン構築（BAR-01〜BAR-08）。棒は 1 メッシュ、色はセル数と同じ大きさのテクスチャで与える
enum BarChartScene {
    static let cameraName = "bars.camera"
    static let texturedFloorName = "bars.floor.textured"
    static let plainFloorName = "bars.floor.plain"
    static let referenceBarName = "bars.referenceBar"
    static let fieldOfView: Float = 60
    /// BAR-11: 基準棒をカメラのフィット計算に含めるための追加の半幅・半奥行き
    static let referenceBarMargin: Double = 1

    /// 棒と床をまとめたルートエンティティ
    static func makeRoot(_ geometry: BarGeometry, floorImage: CGImage?) async -> Entity {
        let root = Entity()
        root.addChild(await makeBars(geometry))
        root.addChild(await makeTexturedFloor(geometry, image: floorImage))
        root.addChild(makePlainFloor(geometry))
        root.addChild(makeReferenceBar(geometry))
        return root
    }

    /// BAR-11: 最大値(100%)のサンプルとなる基準棒。塗り＋破線枠の2エンティティで構成する
    private static func makeReferenceBar(_ geometry: BarGeometry) -> Entity {
        let container = Entity()
        container.name = referenceBarName
        let halfWidth = geometry.barWidth / 2
        container.addChild(makeReferenceBarFill(geometry.referenceBar, halfWidth: halfWidth))
        container.addChild(ReferenceBarOutline.makeEntity(geometry.referenceBar, halfWidth: halfWidth))
        return container
    }

    /// 基準棒の塗り部分。実データの棒と違いテクスチャは使わずフラットカラー
    private static func makeReferenceBarFill(_ bar: BarGeometry.Bar, halfWidth: Float) -> ModelEntity {
        let descriptor = BarChartMesh.singleBarDescriptor(bar, halfWidth: halfWidth)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return ModelEntity() }
        let material = SimpleMaterial(color: uiColor(bar.color), roughness: 1, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    /// RGB8 を RealityKit の材質色に変換する
    private static func uiColor(_ rgb: RGB8) -> RealityKit.Material.Color {
        .init(red: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
    }

    /// BAR-05: 全棒を 1 メッシュにした ModelEntity。色はセルごとのテクセルから取る
    private static func makeBars(_ geometry: BarGeometry) async -> ModelEntity {
        let descriptor = BarChartMesh.descriptor(for: geometry)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return ModelEntity() }
        return ModelEntity(mesh: mesh, materials: [await makeBarMaterial(geometry)])
    }

    /// 代表色を並べた小さな画像をテクスチャにした材質（BAR-04）
    private static func makeBarMaterial(_ geometry: BarGeometry) async -> RealityKit.Material {
        let colors = PixelImage(width: geometry.columns, height: geometry.rows, pixels: geometry.bars.map(\.color))
        guard let texture = await makeTexture(ImageDecoder.makeCGImage(colors)) else {
            return SimpleMaterial(color: .gray, roughness: 1, isMetallic: false)
        }
        var material = SimpleMaterial(color: .white, roughness: 1, isMetallic: false)
        material.color = .init(tint: .white, texture: .init(texture))
        return material
    }

    /// BAR-06: 解析画像を貼った床。画像が未読込なら灰色
    private static func makeTexturedFloor(_ geometry: BarGeometry, image: CGImage?) async -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: Float(geometry.columns), depth: Float(geometry.rows))
        var material = UnlitMaterial(color: .darkGray)
        if let texture = await makeTexture(image) { material.color = .init(tint: .white, texture: .init(texture)) }
        let floor = ModelEntity(mesh: mesh, materials: [material])
        floor.name = texturedFloorName
        floor.position = [0, -0.002, 0]
        return floor
    }

    /// 床テクスチャ OFF のときの無地の床
    private static func makePlainFloor(_ geometry: BarGeometry) -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: Float(geometry.columns), depth: Float(geometry.rows))
        let floor = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .darkGray, roughness: 1, isMetallic: false)])
        floor.name = plainFloorName
        floor.position = [0, -0.002, 0]
        floor.isEnabled = false
        return floor
    }

    /// CGImage からミップマップなしのテクスチャを作る（テクセル中心をサンプルするので補間の影響を受けない）
    private static func makeTexture(_ image: CGImage?) async -> TextureResource? {
        guard let image else { return nil }
        return try? await TextureResource(image: image, options: .init(semantic: .color, mipmapsMode: .none))
    }

    /// BAR-07: 透視カメラ
    static func makeCamera() -> Entity {
        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = fieldOfView
        return camera
    }

    /// BAR-08: 斜め上からのキーライトと反対側の弱いフィルライト
    static func makeLights() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 2500
        key.look(at: .zero, from: [1, 2, 1.5], relativeTo: nil)
        let fill = DirectionalLight()
        fill.light.intensity = 900
        fill.look(at: .zero, from: [-1.5, 1, -1], relativeTo: nil)
        return [key, fill]
    }

    /// カメラ状態をエンティティの位置・向きに反映する。注視点は床面中心。aspectRatio は表示領域の幅 / 高さ
    static func apply(camera: OrbitCamera, geometry: BarGeometry, aspectRatio: Double, in content: RealityViewCameraContent) {
        guard let entity = content.entities.first(where: { $0.name == cameraName }) else { return }
        let distance = OrbitCamera.fitDistance(
            columns: geometry.columns, rows: geometry.rows, maxHeight: geometry.maxHeight,
            fovDegrees: Double(fieldOfView), aspectRatio: aspectRatio, extraMargin: referenceBarMargin
        )
        let p = camera.position(fitDistance: distance)
        entity.look(at: .zero, from: [p.x, p.y, p.z], relativeTo: nil)
    }

    /// 床テクスチャの ON/OFF を 2 枚の床の有効化で切り替える
    static func setFloorTextured(_ textured: Bool, in content: RealityViewCameraContent) {
        for root in content.entities {
            root.findEntity(named: texturedFloorName)?.isEnabled = textured
            root.findEntity(named: plainFloorName)?.isEnabled = !textured
        }
    }
}
