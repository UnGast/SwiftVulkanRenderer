import Vulkan

class ManagedGPUMemory {
  unowned let manager: MemoryManager
  let memory: VkDeviceMemory
  let size: Int
  var usedRanges: [Range<VkDeviceSize>] = []
	var dataPointer: UnsafeMutableRawPointer? = nil

  public init(manager: MemoryManager, memory: VkDeviceMemory, size: Int) {
    self.manager = manager
    self.memory = memory
    self.size = size
  }

  func map() {
    if dataPointer == nil {
      vkMapMemory(manager.renderer.device, memory, 0, VkDeviceSize(size), 0, &dataPointer)
    }
  }

  func unmap() {

  }

  deinit {
    unmap()
  }
}