import GfxMath

public class SceneObject {
    public var mesh: Mesh
    public var transformationMatrix: FMat4

    public init(mesh: Mesh, transformationMatrix: FMat4) {
        self.mesh = mesh
        self.transformationMatrix = transformationMatrix
    }
}