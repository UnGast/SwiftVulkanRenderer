public class SceneDrawInfo {
    public var vertices: [Vertex] = []
    public var indices: [UInt32] = []
    @Deferred public var vertexBuffer: ManagedGPUBuffer
    @Deferred public var indexBuffer: ManagedGPUBuffer
}