import GfxMath

public class Scene {
    public var objects: [SceneObject] = []
    public var camera = Camera(frameCount: 0, position: FVec3(0, 0, 0), direction: FVec3(0, 0, 0))
}