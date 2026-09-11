import ColorAnalysis
import RealityKit

/// BAR-11: 基準棒を実データの棒と区別するための黒白破線枠。辺はすべて軸に平行なので回転計算は不要
enum ReferenceBarOutline {
    private static let segmentsPerEdge = 6
    private static let dashThickness: Float = 0.03
    private static let dashFraction: Float = 0.6

    /// 基準棒の12辺ぶんの破線をまとめたエンティティ
    static func makeEntity(_ bar: BarGeometry.Bar, halfWidth: Float) -> Entity {
        let container = Entity()
        for edge in edges(bar: bar, halfWidth: halfWidth) {
            for dash in dashes(along: edge) { container.addChild(dash) }
        }
        return container
    }

    /// 箱の12辺を (始点, 終点) で返す（下面4辺・上面4辺・垂直4辺）
    private static func edges(bar: BarGeometry.Bar, halfWidth: Float) -> [(SIMD3<Float>, SIMD3<Float>)] {
        let x0 = bar.x - halfWidth, x1 = bar.x + halfWidth
        let z0 = bar.z - halfWidth, z1 = bar.z + halfWidth
        let corners: [(SIMD3<Float>, SIMD3<Float>)] = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)].map {
            (SIMD3($0.0, 0, $0.1), SIMD3($0.0, bar.height, $0.1))
        }
        return ring(corners.map(\.0)) + ring(corners.map(\.1)) + corners
    }

    /// 4点を順に結ぶ4辺（最後は先頭へ戻る）
    private static func ring(_ points: [SIMD3<Float>]) -> [(SIMD3<Float>, SIMD3<Float>)] {
        (0..<4).map { (points[$0], points[($0 + 1) % 4]) }
    }

    /// 1辺を等間隔に分割し、交互に黒白の破線エンティティを作る
    private static func dashes(along edge: (SIMD3<Float>, SIMD3<Float>)) -> [ModelEntity] {
        (0..<segmentsPerEdge).map { dash(edge: edge, index: $0) }
    }

    /// 破線1本分のエンティティ。辺の方向にだけ長い細い箱を、区間の中心に置く
    private static func dash(edge: (SIMD3<Float>, SIMD3<Float>), index: Int) -> ModelEntity {
        let delta = edge.1 - edge.0
        let t = (Float(index) + 0.5) / Float(segmentsPerEdge)
        let center = edge.0 + delta * t
        let size = dashSize(axis: delta, length: length(delta) / Float(segmentsPerEdge) * dashFraction)
        let color: SimpleMaterial.Color = index.isMultiple(of: 2) ? .black : .white
        let mesh = MeshResource.generateBox(size: size)
        let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: color, roughness: 1, isMetallic: false)])
        entity.position = center
        return entity
    }

    /// 辺が伸びている軸（x/y/z のいずれか）だけ length を使った箱サイズを返す
    private static func dashSize(axis delta: SIMD3<Float>, length: Float) -> SIMD3<Float> {
        let t = dashThickness
        if abs(delta.x) > abs(delta.y), abs(delta.x) > abs(delta.z) { return [length, t, t] }
        if abs(delta.y) > abs(delta.z) { return [t, length, t] }
        return [t, t, length]
    }
}
