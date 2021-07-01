import GfxMath

public class SceneObject {
    public var mesh: Mesh
    public var material: Material
    public var transformationMatrix: FMat4

    public init(mesh: Mesh, material: Material, transformationMatrix: FMat4) {
        self.mesh = mesh
        self.material = material
        self.transformationMatrix = transformationMatrix
    }
}