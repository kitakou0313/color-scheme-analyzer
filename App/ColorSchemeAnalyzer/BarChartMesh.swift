import ColorAnalysis
import RealityKit

/// 棒ジオメトリを RealityKit のメッシュ記述に変換する（BAR-01〜BAR-03）。各棒は底面を除く 5 面の箱
enum BarChartMesh {
    /// 頂点バッファの組み立て途中の状態
    private struct Builder {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
    }

    /// 全棒を 1 つの MeshDescriptor にする
    static func descriptor(for geometry: BarGeometry) -> MeshDescriptor {
        var builder = Builder()
        for (index, bar) in geometry.bars.enumerated() {
            append(bar, uv: uv(forCell: index, geometry: geometry), halfWidth: geometry.barWidth / 2, to: &builder)
        }
        var descriptor = MeshDescriptor(name: "bars")
        descriptor.positions = MeshBuffers.Positions(builder.positions)
        descriptor.normals = MeshBuffers.Normals(builder.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(builder.uvs)
        descriptor.primitives = .triangles(builder.indices)
        return descriptor
    }

    /// BAR-11: 基準棒1本だけの MeshDescriptor。フラットカラー材質と組み合わせるので UV はダミー
    static func singleBarDescriptor(_ bar: BarGeometry.Bar, halfWidth: Float) -> MeshDescriptor {
        var builder = Builder()
        append(bar, uv: .zero, halfWidth: halfWidth, to: &builder)
        var descriptor = MeshDescriptor(name: "referenceBar")
        descriptor.positions = MeshBuffers.Positions(builder.positions)
        descriptor.normals = MeshBuffers.Normals(builder.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(builder.uvs)
        descriptor.primitives = .triangles(builder.indices)
        return descriptor
    }

    /// セル番号に対応するテクセル中心の UV（画像の上の行が v = 1 側）
    private static func uv(forCell index: Int, geometry: BarGeometry) -> SIMD2<Float> {
        let column = index % geometry.columns, row = index / geometry.columns
        let u = (Float(column) + 0.5) / Float(geometry.columns)
        let v = 1 - (Float(row) + 0.5) / Float(geometry.rows)
        return SIMD2(u, v)
    }

    /// 1 本の棒（5 面）を追加する
    private static func append(_ bar: BarGeometry.Bar, uv: SIMD2<Float>, halfWidth: Float, to builder: inout Builder) {
        let x0 = bar.x - halfWidth, x1 = bar.x + halfWidth
        let z0 = bar.z - halfWidth, z1 = bar.z + halfWidth
        let h = bar.height
        appendFace([[x0, h, z1], [x1, h, z1], [x1, h, z0], [x0, h, z0]], normal: [0, 1, 0], uv: uv, to: &builder)
        appendFace([[x0, 0, z1], [x1, 0, z1], [x1, h, z1], [x0, h, z1]], normal: [0, 0, 1], uv: uv, to: &builder)
        appendFace([[x1, 0, z0], [x0, 0, z0], [x0, h, z0], [x1, h, z0]], normal: [0, 0, -1], uv: uv, to: &builder)
        appendFace([[x1, 0, z1], [x1, 0, z0], [x1, h, z0], [x1, h, z1]], normal: [1, 0, 0], uv: uv, to: &builder)
        appendFace([[x0, 0, z0], [x0, 0, z1], [x0, h, z1], [x0, h, z0]], normal: [-1, 0, 0], uv: uv, to: &builder)
    }

    /// 外側から見て反時計回りの 4 頂点を 2 三角形として追加する
    private static func appendFace(_ corners: [SIMD3<Float>], normal: SIMD3<Float>, uv: SIMD2<Float>, to builder: inout Builder) {
        let base = UInt32(builder.positions.count)
        builder.positions.append(contentsOf: corners)
        builder.normals.append(contentsOf: [SIMD3<Float>](repeating: normal, count: 4))
        builder.uvs.append(contentsOf: [SIMD2<Float>](repeating: uv, count: 4))
        builder.indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
    }
}
