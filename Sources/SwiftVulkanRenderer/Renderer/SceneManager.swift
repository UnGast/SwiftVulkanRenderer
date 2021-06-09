import Vulkan

public class SceneManager {
  let renderer: VulkanRenderer

  @Deferred var vertexBuffer: ManagedGPUBuffer 

  public init(renderer: VulkanRenderer) throws {
    self.renderer = renderer
  }

  public func update(scene: Scene) throws {
    vertexBuffer = try renderer.geometryMemoryManager.getBuffer(size: 1024 * 512, usage: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT)
  }
}