import Vulkan

extension RaytracingVulkanRenderer {
  class SceneManager {
    unowned let renderer: RaytracingVulkanRenderer

    let mainMemoryManager: MemoryManager
    @Deferred var mainStagingBuffer: ManagedGPUBuffer
    @Deferred var objectGeometryBuffer: ManagedGPUBuffer

    var scene: Scene {
      renderer.scene
    }

    init(renderer: RaytracingVulkanRenderer) throws {
      self.renderer = renderer

      self.mainMemoryManager = try MemoryManager(
        renderer: renderer,
        memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))

      mainStagingBuffer = try mainMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
      
      objectGeometryBuffer = try mainMemoryManager.getBuffer(
        size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))
      
      //let commandBuffer = renderer.beginSingleTimeCommands()
    }
  }
}