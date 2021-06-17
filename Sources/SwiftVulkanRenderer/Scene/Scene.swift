import GfxMath

public class Scene {
    public var objects: [SceneObject] = []
    public var camera = Camera()
    public var ambientLight = AmbientLight(color: .white, intensity: 0.1)
    public var directionalLight = DirectionalLight(direction: FVec3(0, -1, 0), color: .white, intensity: 0.5)
}