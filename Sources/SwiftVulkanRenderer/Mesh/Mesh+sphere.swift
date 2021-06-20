import GfxMath

extension Mesh {
	/// creates a sphere by subdividing an icosahedron
	/// - Parameter subdivisionCount: how many iterations of dividing each face into 4 separate faces (determines smoothness)
	/// - Returns: sphere with diameter of 1
	public static func sphere(subdivisionCount: Int, material: Material) -> Mesh {
		let icosahedron = Mesh.icosahedron(material: material)
		
		var vertices = icosahedron.vertices
		var nFaces = 20
		
		for subdivisionIndex in 0..<subdivisionCount {
			var updatedVertices = [Vertex]()
			for faceIndex in 0..<nFaces {
				let subdivisionVertices = subdivideFace(vertices[faceIndex * 3 + 0], vertices[faceIndex * 3 + 1], vertices[faceIndex * 3 + 2], radius: 0.5)
				updatedVertices.append(contentsOf: subdivisionVertices)
			}
			vertices = updatedVertices 
			nFaces = nFaces * 4
		}

		return Mesh(vertices: vertices, indices: Array(0..<UInt32(vertices.count)), material: material)
	}
}

/// input vertices must be in counter-clockwise order, output will be in counter-clockwise order
private func subdivideFace(_ v1: Vertex, _ v2: Vertex, _ v3: Vertex, radius: Float) -> [Vertex] {
	let mid1 = v1.position + (v2.position - v1.position) / 2
	let mid2 = v2.position + (v3.position - v2.position) / 2
	let mid3 = v3.position + (v1.position - v3.position) / 2

	let positions = [
		mid1, mid2, mid3,
		v1.position, mid1, mid3,
		mid1, v2.position, mid2,
		mid2, v3.position, mid3
	]

	let vertices = positions.map { Vertex(position: $0.normalized() * radius, normal: $0.normalized()) }
	return vertices
}