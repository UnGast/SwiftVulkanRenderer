import GfxMath

public class SceneObject {
    public var mesh: Mesh
    public var transformation: [[Float]] 

    public init(mesh: Mesh, transformation: [[Float]]) {
        self.mesh = mesh
        self.transformation = transformation
    }
}