import GfxMath

public class Mesh: Hashable {
  public var vertices: [Vertex]
  public var indices: [UInt32]
  public var material: Material

  public init(vertices: [Vertex], indices: [UInt32], material: Material) {
    self.vertices = vertices
    self.indices = indices
    self.material = material
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }

  public static func == (lhs: Mesh, rhs: Mesh) -> Bool {
    lhs === rhs
  }
}