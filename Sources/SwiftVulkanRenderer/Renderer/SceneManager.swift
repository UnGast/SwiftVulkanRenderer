import Vulkan

public class SceneManager {
  let renderer: VulkanRenderer

  @Deferred var stagingBuffer: ManagedGPUBuffer
  @Deferred var vertexBuffer: ManagedGPUBuffer 
  var vertexCount: Int = 0

  public init(renderer: VulkanRenderer) throws {
    self.renderer = renderer

    stagingBuffer = try renderer.geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    vertexBuffer = try renderer.geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))
  }

  public func update(scene: Scene) throws {
    vertexCount = scene.objects.reduce(0) { $0 + $1.mesh.vertices.count }
    try stagingBuffer.store(scene.objects.flatMap { $0.mesh.vertices.flatMap { $0.position.elements } })

    var commandBuffer = try renderer.beginSingleTimeCommands()
    vertexBuffer.copy(from: stagingBuffer, srcRange: 0..<stagingBuffer.size, dstOffset: 0, commandBuffer: commandBuffer)
    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
  }
}