import GfxMath

fileprivate var cubeIndices: [UInt32] {
  [
    // front 
    0, 1, 2,
    0, 2, 3,
    // right
    1, 5, 7,
    1, 7, 2,
    // left
    4, 0, 3,
    4, 3, 6,
    // bottom
    3, 2, 7,
    3, 7, 6,
    // back
    5, 4, 6,
    5, 6, 7,
    // top
    4, 5, 1,
    4, 1, 0
  ]
}

extension Mesh {
  public static func cuboid(size: FVec3 = FVec3(1, 1, 1), material: Material) -> Mesh {
    let halfSize = size / 2
    return Mesh(vertices: [
      // 0, top front left
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: -1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      // 1, top front right
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: -1)),// color: .orange, texCoord: FVec2(x: 0, y: 0)),
      // 2, bottom front right
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: -1)),// color: .blue, texCoord: FVec2(x: 0, y: 0)),
      // 3, bottom front left
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: -1)),// color: .green, texCoord: FVec2(x: 0, y: 0)),
      // 4, top back left
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: 1)),// color: .red, texCoord: FVec2(x: 0, y: 0)),
      // 5, top back right
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: 1)),//, color: .lightBlue, texCoord: FVec2(x: 0, y: 0)),
      // 6, bottom back left
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: 1)),// color: .grey, texCoord: FVec2(x: 0, y: 0)),
      // 7, bottom back right
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: 1)),// color: .white, texCoord: FVec2(x: 0, y: 0)),
    ], indices: cubeIndices, material: material)
  }
}