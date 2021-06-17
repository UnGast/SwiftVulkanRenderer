import Foundation
import GfxMath

extension Mesh {
	public static func icosahedron(material: Material) -> Mesh {
		let phi: Float = (1 + sqrt(5)) / 2 
		let a = Float(0.5)
		let b = 1 / (2 * phi)
		return Mesh(vertices: [
			Vertex(position: FVec3(0, b, -a), normal: .zero),    Vertex(position: FVec3(b, a, 0), normal: .zero),   Vertex(position: FVec3(-b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),   Vertex(position: FVec3(-b, a, 0), normal: .zero),    Vertex(position: FVec3(b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),    Vertex(position: FVec3(0, -b, a), normal: .zero),   Vertex(position: FVec3(-a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),    Vertex(position: FVec3(a, 0, b), normal: .zero),    Vertex(position: FVec3(0, -b, a), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),    Vertex(position: FVec3(0, -b, -a), normal: .zero),    Vertex(position: FVec3(a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),   Vertex(position: FVec3(-a, 0, -b), normal: .zero),    Vertex(position: FVec3(0, -b, -a), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),    Vertex(position: FVec3(b, -a, 0), normal: .zero),   Vertex(position: FVec3(-b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),   Vertex(position: FVec3(-b, -a, 0), normal: .zero),    Vertex(position: FVec3(b, -a, 0), normal: .zero),
			Vertex(position: FVec3(-b, a, 0), normal: .zero),   Vertex(position: FVec3(-a, 0, b), normal: .zero),   Vertex(position: FVec3(-a, 0, -b), normal: .zero),
			Vertex(position: FVec3(-b, -a, 0), normal: .zero),   Vertex(position: FVec3(-a, 0, -b), normal: .zero),   Vertex(position: FVec3(-a, 0, b), normal: .zero),
			Vertex(position: FVec3(b, a, 0), normal: .zero),    Vertex(position: FVec3(a, 0, -b), normal: .zero),    Vertex(position: FVec3(a, 0, b), normal: .zero),
			Vertex(position: FVec3(b, -a, 0), normal: .zero),    Vertex(position: FVec3(a, 0, b), normal: .zero),    Vertex(position: FVec3(a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),   Vertex(position: FVec3(-a, 0, b), normal: .zero),   Vertex(position: FVec3(-b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),    Vertex(position: FVec3(b, a, 0), normal: .zero),    Vertex(position: FVec3(a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),   Vertex(position: FVec3(-b, a, 0), normal: .zero),   Vertex(position: FVec3(-a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),    Vertex(position: FVec3(a, 0, -b), normal: .zero),    Vertex(position: FVec3(b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),   Vertex(position: FVec3(-a, 0, -b), normal: .zero),   Vertex(position: FVec3(-b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),    Vertex(position: FVec3(b, -a, 0), normal: .zero),    Vertex(position: FVec3(a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),   Vertex(position: FVec3(-b, -a, 0), normal: .zero),   Vertex(position: FVec3(-a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),    Vertex(position: FVec3(a, 0, b), normal: .zero),    Vertex(position: FVec3(b, -a, 0), normal: .zero)
		], indices: Array(0..<60), material: material)
	}
}