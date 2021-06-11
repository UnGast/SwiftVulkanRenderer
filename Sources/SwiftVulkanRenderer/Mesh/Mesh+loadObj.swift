import CTinyObjLoader
import Foundation
import GfxMath

extension Mesh {
  public static func loadObj(fileUrl: URL, defaultMaterial: Material) throws -> Mesh {
    var vertices = [Vertex]()
    var indices = [UInt32]()

    var pAttrib = UnsafeMutablePointer<tinyobj_attrib_t>.allocate(capacity: 1)
    tinyobj_attrib_init(pAttrib)
    var pShapes: UnsafeMutablePointer<tinyobj_shape_t>?
    var numShapes: Int = 0
    var pMaterials: UnsafeMutablePointer<tinyobj_material_t>?
    var numMaterials = 0

    fileUrl.absoluteString.withCString() {
      var mutable = UnsafeMutablePointer(mutating: $0)
      tinyobj_parse_obj(
        pAttrib,
        &pShapes,
        &numShapes,
        &pMaterials,
        &numMaterials,
        "",
        { stringUrl, _, _, _, dataPointerPointer, dataSizePointer in
          let typed = stringUrl?.assumingMemoryBound(to: Int8.self)
          let data = try! Data(contentsOf: URL(string: String(cString: typed!))!)
          let dataPointer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: data.count)
          data.copyBytes(to: dataPointer)
          dataPointerPointer?.pointee = dataPointer.baseAddress
          dataSizePointer?.pointee = dataPointer.count
        }, mutable, UInt32(TINYOBJ_FLAG_TRIANGULATE))
    }

    let attrib = pAttrib.pointee;
    let shapes = Array(UnsafeBufferPointer(start: pShapes, count: numShapes))
    let materials = Array(UnsafeBufferPointer(start: pMaterials, count: numMaterials))
    pShapes?.deallocate()
    pMaterials?.deallocate()

    for shape in shapes {
      for faceIndex in shape.face_offset..<shape.face_offset + shape.length {
        var faceVertices: [Vertex] = []

        for vertexIndex in 0..<3 {
          let rawVertex = attrib.faces[Int(faceIndex) * 3 + vertexIndex]

          let vertex = Vertex(
            position: FVec3(
              x: attrib.vertices[Int(rawVertex.v_idx * 3 + 0)],
              y: attrib.vertices[Int(rawVertex.v_idx * 3 + 1)],
              z: attrib.vertices[Int(rawVertex.v_idx * 3 + 2)]
            )/*, texCoords: FVec2(
              x: rawVertex.vt_idx >= 0 ? attrib.texcoords[Int(rawVertex.vt_idx * 2 + 0)] : -1,
              y: rawVertex.vt_idx >= 0 ? attrib.texcoords[Int(rawVertex.vt_idx * 2 + 1)] : -1
            )*/ /*, 
            normal: .zero,
            color: Color(
              r: 0, g: 0, b: 0, a: 255
            ), */
          )

          faceVertices.append(vertex)
        }

        /*let edge1 = faceVertices[1].position - faceVertices[0].position
        let edge2 = faceVertices[2].position - faceVertices[0].position
        let normal = edge1.cross(edge2)*/

        for index in 0..<faceVertices.count {
         // faceVertices[index].normal = normal
          vertices.append(faceVertices[index])
          indices.append(UInt32(vertices.count - 1))
        }
      }
    }

    return Mesh(vertices: vertices, indices: indices, material: defaultMaterial)
  }
}