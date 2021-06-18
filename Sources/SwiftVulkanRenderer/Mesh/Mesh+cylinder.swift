import GfxMath

extension Mesh {
	/// - Parameter divisionCount: how many divisions to use to approximate a circle
	public static func cylinder(divisionCount: Int, material: Material) -> Mesh {
		let radius = Float(1)
		let height = Float(1)

		// centered at (0, 0, 0), will be displaced to top and bottom later
		var basePositions =  [FVec3]()
		for i in 0..<divisionCount {
			let angle = Float.pi * 2 * (Float(i) / Float(divisionCount))
			let x = cos(angle)
			let z = sin(angle)
			basePositions.append(FVec3(x, 0, z))
		}

		var vertices = [Vertex]()
		var indices = [UInt32]()
		
		// top
		// assuming the center vertex is ordered after all border vertices
		let centerIndex = UInt32(divisionCount)
		var topIndices = [UInt32]()
		for i in 0..<UInt32(divisionCount) {
			if (i == divisionCount - 1) {
				topIndices.append(contentsOf: [0, i, centerIndex])
			} else {
				topIndices.append(contentsOf: [i + 1, i, centerIndex])
			}
		}
		indices = mergeIndices(indices: indices, additionalIndices: topIndices, offset: UInt32(vertices.count))
		vertices.append(contentsOf: basePositions.map {
			Vertex(position: $0 + FVec3(0, height / 2, 0), normal: FVec3(0, 1, 0))
		})
		vertices.append(Vertex(position: FVec3(0, height / 2, 0), normal: FVec3(0, 1, 0)))

		// bottom	
		// assuming the center vertex is ordered after all border vertices
		var bottomIndices = [UInt32]()
		for i in 0..<UInt32(divisionCount) {
			if (i == divisionCount - 1) {
				bottomIndices.append(contentsOf: [i, 0, centerIndex])
			} else {
				bottomIndices.append(contentsOf: [i, i + 1, centerIndex])
			}
		}
		indices = mergeIndices(indices: indices, additionalIndices: bottomIndices, offset: UInt32(vertices.count))
		vertices.append(contentsOf: basePositions.map {
			Vertex(position: $0 + FVec3(0, -height / 2, 0), normal: FVec3(0, -1, 0))
		})
		vertices.append(Vertex(position: FVec3(0, -height / 2, 0), normal: FVec3(0, -1, 0)))

		var sideIndices = [UInt32]()
		var sideVertices = [Vertex]()
		for faceIndex in 0..<divisionCount {
			let basePos1 = basePositions[faceIndex]
			let basePos2 = basePositions[(faceIndex + 1) % divisionCount]
			
			let p1 = basePos1 + FVec3(0, height / 2, 0)
			let p2 = basePos2 + FVec3(0, height / 2, 0)
			let p3 = basePos2 + FVec3(0, -height / 2, 0)
			let p4 = basePos1 + FVec3(0, -height / 2, 0)

			let normal = (p2 - p1).cross(p4 - p1)

			let faceStartIndex = UInt32(sideVertices.count)

			sideIndices.append(contentsOf: [
				faceStartIndex + 0,
				faceStartIndex + 1,
				faceStartIndex + 2,
				faceStartIndex + 0,
				faceStartIndex + 2,
				faceStartIndex + 3,
			])

			sideVertices.append(contentsOf: [
				Vertex(position: p1, normal: normal),
				Vertex(position: p2, normal: normal),
				Vertex(position: p3, normal: normal),
				Vertex(position: p4, normal: normal)
			])
		}
		indices = mergeIndices(indices: indices, additionalIndices: sideIndices, offset: UInt32(vertices.count))
		vertices.append(contentsOf: sideVertices)

		return Mesh(vertices: vertices, indices: indices, material: material)
	}
}

/// - Returns: merged indices, additional indices offset by given value
fileprivate func mergeIndices(indices: [UInt32], additionalIndices: [UInt32], offset: UInt32) -> [UInt32] {
	var indices = indices
	indices.append(contentsOf: additionalIndices.map { $0 + offset })
	return indices
}