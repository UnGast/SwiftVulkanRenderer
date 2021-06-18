import Foundation
import GfxMath

extension Mesh {
	/// - Returns: icosahedron with enclosing diameter of 0.5
	public static func icosahedron(material: Material) -> Mesh {
		let phi: Float = (1 + sqrt(5)) / 2 
		let a = Float(0.5)
		let b = 1 / (2 * phi)

		var vertices = [
			Vertex(position: FVec3(b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),
			Vertex(position: FVec3(-b, a, 0), normal: .zero),

			Vertex(position: FVec3(-b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),
			Vertex(position: FVec3(b, a, 0), normal: .zero),

			Vertex(position: FVec3(0, -b, a), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),
			Vertex(position: FVec3(-a, 0, b), normal: .zero),

			Vertex(position: FVec3(a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),

			Vertex(position: FVec3(0, -b, -a), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),
			Vertex(position: FVec3(a, 0, -b), normal: .zero),

			Vertex(position: FVec3(-a, 0, -b), normal: .zero), 
			Vertex(position: FVec3(0, b, -a), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),

			Vertex(position: FVec3(b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),
			Vertex(position: FVec3(-b, -a, 0), normal: .zero),

			Vertex(position: FVec3(-b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),
			Vertex(position: FVec3(b, -a, 0), normal: .zero),

			Vertex(position: FVec3(-a, 0, b), normal: .zero),
			Vertex(position: FVec3(-b, a, 0), normal: .zero),
			Vertex(position: FVec3(-a, 0, -b), normal: .zero),

			Vertex(position: FVec3(-a, 0, -b), normal: .zero),
			Vertex(position: FVec3(-b, -a, 0), normal: .zero),
			Vertex(position: FVec3(-a, 0, b), normal: .zero),

			Vertex(position: FVec3(a, 0, -b), normal: .zero),
			Vertex(position: FVec3(b, a, 0), normal: .zero),
			Vertex(position: FVec3(a, 0, b), normal: .zero),

			Vertex(position: FVec3(a, 0, b), normal: .zero),
			Vertex(position: FVec3(b, -a, 0), normal: .zero),
			Vertex(position: FVec3(a, 0, -b), normal: .zero),

			Vertex(position: FVec3(-a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),
			Vertex(position: FVec3(-b, a, 0), normal: .zero),

			Vertex(position: FVec3(b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, a), normal: .zero),
			Vertex(position: FVec3(a, 0, b), normal: .zero),

			Vertex(position: FVec3(-b, a, 0), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),
			Vertex(position: FVec3(-a, 0, -b), normal: .zero),

			Vertex(position: FVec3(a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, b, -a), normal: .zero),
			Vertex(position: FVec3(b, a, 0), normal: .zero),

			Vertex(position: FVec3(-a, 0, -b), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),
			Vertex(position: FVec3(-b, -a, 0), normal: .zero),

			Vertex(position: FVec3(b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, -a), normal: .zero),
			Vertex(position: FVec3(a, 0, -b), normal: .zero),

			Vertex(position: FVec3(-b, -a, 0), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),
			Vertex(position: FVec3(-a, 0, b), normal: .zero),

			Vertex(position: FVec3(a, 0, b), normal: .zero),
			Vertex(position: FVec3(0, -b, a), normal: .zero),
			Vertex(position: FVec3(b, -a, 0), normal: .zero)
		]

		let indices = Array(UInt32(0)..<60)

		let nFaces = 20

		for faceIndex in 0..<nFaces {
			var vertex1 = vertices[faceIndex * 3 + 0]
			var vertex2 = vertices[faceIndex * 3 + 1]
			var vertex3 = vertices[faceIndex * 3 + 2]
			let a = vertex2.position - vertex1.position
			let b = vertex3.position - vertex1.position
			let normal = a.cross(b)
			vertex1.normal = normal
			vertex2.normal = normal
			vertex3.normal = normal
			vertices[faceIndex * 3 + 0] = vertex1
			vertices[faceIndex * 3 + 1] = vertex2
			vertices[faceIndex * 3 + 2] = vertex3
		}

		return Mesh(vertices: vertices, indices: indices, material: material)
	}
}