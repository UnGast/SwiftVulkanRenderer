import GfxMath

extension Mesh {
  public static func cuboid(size: FVec3 = FVec3(1, 1, 1), material: Material) -> Mesh {
    let halfSize = size / 2
    return Mesh(vertices: [
      // front
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: 1), normal: FVec3(0, 0, 1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: 1), normal: FVec3(0, 0, 1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: 1), normal: FVec3(0, 0, 1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: 1), normal: FVec3(0, 0, 1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      /// right
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: 1), normal: FVec3(1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: -1), normal: FVec3(1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: -1), normal: FVec3(1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: 1), normal: FVec3(1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      /// left
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: -1), normal: FVec3(-1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: 1), normal: FVec3(-1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: 1), normal: FVec3(-1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: -1), normal: FVec3(-1, 0, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      /// back
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: -1), normal: FVec3(0, 0, -1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: -1), normal: FVec3(0, 0, -1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: -1), normal: FVec3(0, 0, -1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: -1), normal: FVec3(0, 0, -1)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      /// top
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: 1), normal: FVec3(0, 1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: 1), normal: FVec3(0, 1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: 1, z: -1), normal: FVec3(0, 1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: 1, z: -1), normal: FVec3(0, 1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      /// bottom
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: -1), normal: FVec3(0, -1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: -1), normal: FVec3(0, -1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: 1, y: -1, z: 1), normal: FVec3(0, -1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
      Vertex(position: halfSize * FVec3(x: -1, y: -1, z: 1), normal: FVec3(0, -1, 0)),// color: .black, texCoord: FVec2(x: 0, y: 0)),
   ], indices: [
      0, 1, 2,
      0, 2, 3,

      4, 5, 6,
      4, 6, 7,

      8, 9, 10,
      8, 10, 11,

      12, 13, 14,
      12, 14, 15,

      16, 17, 18,
      16, 18, 19,

      20, 21, 22,
      20, 22, 23
    ], material: material)
  }
}