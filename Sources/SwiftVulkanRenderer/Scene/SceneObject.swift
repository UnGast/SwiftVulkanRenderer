import GfxMath

public class SceneObject {
    public var mesh: Mesh {
        didSet {
            rendererSyncState.mesh = false
        }
    }
    public var material: Material {
        didSet {
            rendererSyncState.material = false
        }
    }
    public var transformationMatrix: FMat4
    var rendererSyncState = RendererSynchronizationState()

    public init(mesh: Mesh, material: Material, transformationMatrix: FMat4) {
        self.mesh = mesh
        self.material = material
        self.transformationMatrix = transformationMatrix
    }
}

extension SceneObject {
    public struct RendererSynchronizationState {
        /// true means synced, false means out of sync
        var material: Bool = false
        var mesh: Bool = false
    }
}