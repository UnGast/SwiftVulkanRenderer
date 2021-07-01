import GfxMath

public class Mesh: Hashable {
  public var vertices: [Vertex]
  public var indices: [UInt32]

  public init(vertices: [Vertex], indices: [UInt32]) {
    self.vertices = vertices
    self.indices = indices
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  public static func == (lhs: Mesh, rhs: Mesh) -> Bool {
    lhs === rhs
  }

  public var flatVertices: [Vertex] {
    indices.map { vertices[Int($0)] }
  }
}